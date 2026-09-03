
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function txt = methodsNarrative(report)
% METHODSNARRATIVE  Full parameterized methods paragraph for one report.
%   txt = METHODSNARRATIVE(report) returns a publication-style methods paragraph:
%   a software sentence, the ordered pipeline description (built from the report's
%   own step parameters by pipelineProse), and the outcome counts for this file.
%   Falls back to the brief outcomes-only sentence (methodsParagraph) when the
%   report carries no step parameters (e.g. a legacy report).
%
%   The prose is generated from the report's parameters and standard methods
%   vocabulary; it reproduces no external text.
%
%   See also: pipelineProse, methodsClause, methodsParagraphAggregate, methodsParagraph

    body = pipelineProse(report);
    if isempty(body)
        txt = methodsParagraph(report);     % graceful fallback
        return
    end
    parts = {softwareSentence(report), body};
    counts = outcomeSentence(report);
    if ~isempty(counts)
        parts{end+1} = counts;
    end
    txt = strjoin(parts, ' ');
end

% ── helpers ───────────────────────────────────────────────────────────────────

function s = outcomeSentence(report)
% Closing outcome sentence for one file: channels/epochs retained + ICA removed.
    ret = {};
    ch = report.channels;
    if ch.original > 0
        ret{end+1} = sprintf('%d of %d channels', ch.final, ch.original);
    end
    if isfield(report, 'trials') && report.trials.original > 0
        ret{end+1} = sprintf('%d of %d epochs', report.trials.final, report.trials.original);
    end
    s = '';
    if ~isempty(ret)
        s = sprintf('%s were retained', joinAnd(ret));
    end
    if isfield(report, 'ica') && report.ica.nComponents > 0 && report.ica.nRejected > 0
        icaTxt = sprintf('%d independent components were removed', report.ica.nRejected);
        if isempty(s)
            s = icaTxt;
        else
            s = sprintf('%s, and %s', s, icaTxt);
        end
    end
    if ~isempty(s)
        s = [upper(s(1)), s(2:end), '.'];
    end
end

function s = joinAnd(c)
    if numel(c) <= 1
        s = strjoin(c, '');
    else
        s = sprintf('%s and %s', c{1}, c{2});
    end
end
