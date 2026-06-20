
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function txt = methodsParagraphAggregate(reports)
% METHODSPARAGRAPHAGGREGATE  Cross-file methods paragraph for a session.
%   txt = METHODSPARAGRAPHAGGREGATE(reports)
%
%   reports - cell array of PipelineReport structs. Returns a publication-style
%   methods paragraph: a software sentence, the ordered pipeline description
%   (shared across the batch, built from the parameters in report.steps by
%   pipelineProse), and the session outcome counts as mean +/- SD across files.
%   Falls back to the single-file narrative for one report, and to an
%   outcomes-only sentence when the reports carry no step parameters or ran
%   different pipelines. Used by summarizeReports and the "Copy Methods" button.
%
%   The prose is generated from the reports' own parameters and standard methods
%   vocabulary; it reproduces no external text.
%
%   See also: methodsNarrative, pipelineProse, methodsClause, summarizeReports

    if iscell(reports) && isscalar(reports)
        txt = methodsNarrative(reports{1});
        return
    end
    N = numel(reports);

    % Pipeline prose: only when every file ran the same step sequence (a mixed
    % batch falls back to counts-only). Use the report that ran the most steps.
    body = '';
    rep  = representativeReport(reports);
    if ~isempty(rep) && pipelinesConsistent(reports)
        body = pipelineProse(rep);
    end

    countsParts = aggregateCounts(reports);

    if isempty(body)
        % Legacy / mixed-pipeline fallback: the original outcomes-only sentence.
        if isempty(countsParts)
            txt = sprintf('Across %d files, TMS-EEG data were preprocessed using nestapp.', N);
        else
            txt = sprintf(['Across %d files, TMS-EEG data were preprocessed using nestapp. ' ...
                '%s. Values are mean +/- SD across files.'], N, strjoin(countsParts, '; '));
        end
        return
    end

    parts = {softwareSentence(rep), body};
    if ~isempty(countsParts)
        parts{end+1} = sprintf('Across %d files, %s (mean +/- SD across files).', ...
            N, strjoin(countsParts, ', '));
    end
    txt = strjoin(parts, ' ');
end

% ── helpers ───────────────────────────────────────────────────────────────────

function rep = representativeReport(reports)
    nSteps = cellfun(@(r) numel(stepsWithParams(r)), reports);
    [mx, ri] = max(nSteps);
    if mx == 0
        rep = [];
    else
        rep = reports{ri};
    end
end

function s = stepsWithParams(report)
    s = {};
    if isfield(report, 'steps') && ~isempty(report.steps)
        keep = cellfun(@(x) isstruct(x) && isfield(x, 'params'), report.steps);
        s = report.steps(keep);
    end
end

function tf = pipelinesConsistent(reports)
% True when every report that ran steps ran the same step-name sequence.
    seq = {};
    for i = 1:numel(reports)
        n = reportStepNames(reports{i});
        if isempty(n); continue; end
        if isempty(seq)
            seq = n;
        elseif ~isequal(seq, n)
            tf = false; return
        end
    end
    tf = true;
end

function parts = aggregateCounts(reports)
% "X +/- S of Y channels were retained (...)"-style fragments, mean +/- SD.
    parts = {};

    origCh = cellfun(@(r) r.channels.original,      reports);
    finCh  = cellfun(@(r) r.channels.final,         reports);
    rejCh  = cellfun(@(r) r.channels.nRejected,     reports);
    intpCh = cellfun(@(r) r.channels.nInterpolated, reports);
    hasCh  = origCh > 0;
    if any(hasCh)
        chSent = sprintf('%s of %s channels were retained', ...
            meanSd(finCh(hasCh)), meanSd(origCh(hasCh)));
        extra = {};
        if any(rejCh(hasCh)  > 0); extra{end+1} = sprintf('%s removed',      meanSd(rejCh(hasCh)));  end
        if any(intpCh(hasCh) > 0); extra{end+1} = sprintf('%s interpolated', meanSd(intpCh(hasCh))); end
        if ~isempty(extra); chSent = sprintf('%s (%s)', chSent, strjoin(extra, ', ')); end
        parts{end+1} = chSent;
    end

    origTr = cellfun(@(r) r.trials.original, reports);
    finTr  = cellfun(@(r) r.trials.final,    reports);
    rejTr  = cellfun(@(r) r.trials.rejected, reports);
    hasTr  = origTr > 0;
    if any(hasTr)
        parts{end+1} = sprintf('%s of %s epochs were retained (%s rejected)', ...
            meanSd(finTr(hasTr)), meanSd(origTr(hasTr)), meanSd(rejTr(hasTr)));
    end

    nComp = cellfun(@(r) r.ica.nComponents, reports);
    nRej  = cellfun(@(r) r.ica.nRejected,  reports);
    hasICA = nComp > 0;
    if any(hasICA)
        parts{end+1} = sprintf('%s of %s independent components were removed', ...
            meanSd(nRej(hasICA)), meanSd(nComp(hasICA)));
    end
end

function s = softwareSentence(report)
    names    = reportStepNames(report);
    isTMS    = any(contains(names, 'TMS')) || any(contains(names, '(TESA)'));
    usesTesa = any(contains(names, '(TESA)'));
    modality = 'EEG data';
    if isTMS; modality = 'TMS-EEG data'; end
    tool = 'EEGLAB';
    if usesTesa; tool = 'EEGLAB and the TESA toolbox'; end
    s = sprintf('%s were preprocessed in MATLAB using %s (nestapp %s).', ...
        modality, tool, nestappVersion());
end

function s = meanSd(v)
% Compact "mean" or "mean +/- SD" depending on spread.
    v = double(v(:));
    if isempty(v)
        s = '0';
    elseif isscalar(v) || std(v) < 1e-9
        s = sprintf('%.0f', mean(v));
    else
        s = sprintf('%.0f +/- %.0f', mean(v), std(v));
    end
end
