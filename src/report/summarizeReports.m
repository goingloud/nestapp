
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function summaryText = summarizeReports(reports, failed)
% SUMMARIZEREPORTS  Build a cross-file summary from a cell array of PipelineReport structs.
%
%   summaryText = SUMMARIZEREPORTS(reports)
%   summaryText = SUMMARIZEREPORTS(reports, failed)
%
%   reports - 1xN cell array of structs returned by initPipelineReport and
%             populated by runPipelineCore. N >= 1; a single-file run gets a
%             summary too (fmtStat renders a lone value without a spread).
%   failed  - optional struct array of files that did not complete (from
%             runPipelineCore). When non-empty, a "FILES THAT DID NOT
%             COMPLETE" section is listed up front so the failures are not
%             silently dropped from the session view.
%
%   Returns a formatted char suitable for display in the pipeline report dialog
%   above the individual per-file reports.
%
%   See also: initPipelineReport, exportReport, runPipelineCore

if nargin < 2, failed = struct([]); end

N = numel(reports);
lines = {};
lines{end+1} = sprintf('=== PIPELINE SUMMARY  (%d files) ===', N);
lines{end+1} = '';

% Failures first: the operational "what do I re-run" question comes before
% the aggregate stats and publication prose below.
lines = [lines, didNotCompleteLines(failed)];

%% Channels
origCh  = cellfun(@(r) r.channels.original,      reports);
rejCh   = cellfun(@(r) r.channels.nRejected,     reports);
intpCh  = cellfun(@(r) r.channels.nInterpolated, reports);
finalCh = cellfun(@(r) r.channels.final,          reports);

lines{end+1} = 'CHANNELS';
lines{end+1} = sprintf('  Original:     %s', fmtStat(origCh));
if any(rejCh > 0)
    lines{end+1} = sprintf('  Rejected:     %s', fmtStat(rejCh));
end
if any(intpCh > 0)
    lines{end+1} = sprintf('  Interpolated: %s', fmtStat(intpCh));
end
lines{end+1} = sprintf('  Final:        %s', fmtStat(finalCh));
lines = [lines, badChannelTallyLines(reports, N)];
lines{end+1} = '';

%% Trials
origTr  = cellfun(@(r) r.trials.original, reports);
rejTr   = cellfun(@(r) r.trials.rejected, reports);
finalTr = cellfun(@(r) r.trials.final,    reports);

epoched = origTr > 0;
if any(epoched)
    lines{end+1} = 'TRIALS';
    if ~all(epoched)
        lines{end+1} = sprintf('  %d of %d files epoched', sum(epoched), N);
    end
    ep = find(epoched);
    lines{end+1} = sprintf('  Original:  %s', fmtStat(origTr(ep)));
    if any(rejTr(ep) > 0)
        pctRej = rejTr(ep) ./ origTr(ep) * 100;
        lines{end+1} = sprintf('  Rejected:  %s  (%.1f%%+/-%.1f%% of trials)', ...
            fmtStat(rejTr(ep)), mean(pctRej), std(pctRej));
    end
    lines{end+1} = sprintf('  Final:     %s', fmtStat(finalTr(ep)));
    lines{end+1} = '';
end

%% ICA
nComp  = cellfun(@(r) r.ica.nComponents, reports);
nRej   = cellfun(@(r) r.ica.nRejected,  reports);
varRem = cellfun(@(r) r.ica.varRemoved,  reports);

hasICA = nComp > 0;
if any(hasICA)
    lines{end+1} = 'ICA';
    icaIdx = find(hasICA);
    lines{end+1} = sprintf('  Identified: %s components', fmtStat(nComp(icaIdx)));
    lines{end+1} = sprintf('  Removed:    %s', fmtStat(nRej(icaIdx)));

    % r.ica.varRemoved is compounded across rounds (recomputeICATotals), so this
    % per-file value is a valid subject total before we average it across files.
    hasVar = ~isnan(varRem) & hasICA;
    if any(hasVar)
        lines{end+1} = sprintf('  ICA var removed (compounded): %s%%', fmtStat(varRem(hasVar)));
    end

    % Per-category totals (only if all ICA files share the same category scheme)
    icaReports = reports(hasICA);
    catNames = icaReports{1}.ica.categories.names;
    allSameCats = all(cellfun(@(r) isequal(r.ica.categories.names, catNames), icaReports));
    anyRejected = any(cellfun(@(r) any(r.ica.categories.nRemoved > 0), icaReports));

    if allSameCats && anyRejected
        lines{end+1} = '  By category (mean per file):';
        nCats = numel(catNames);
        for ci = 1:nCats
            counts = cellfun(@(r) r.ica.categories.nRemoved(ci), icaReports);
            if any(counts > 0)
                lines{end+1} = sprintf('    %-12s %s', [catNames{ci} ':'], fmtStat(counts));
            end
        end
    end
    lines{end+1} = '';
end

%% Pipeline steps - the plain numbered skeleton (the verbal methods follow).
%% Kept alongside the prose so the summary has both the quick step list (as in
%% the per-file reports) and the publication paragraph.
lines = [lines, pipelineStepLines(reports)];

%% Methods - publication-ready prose aggregated across the session
lines{end+1} = 'METHODS';
lines{end+1} = ['  ', methodsParagraphAggregate(reports)];
lines{end+1} = '';

%% Citation - references for every method used across the session, from the
%% union of steps that ran (stepCitations dedupes by method).
allSteps = {};
for i = 1:numel(reports)
    allSteps = [allSteps, reportStepNames(reports{i})]; %#ok<AGROW>
end
citeLines = citationLines(allSteps);
if ~isempty(citeLines)
    lines = [lines, citeLines];
    lines{end+1} = '';
end

summaryText = strjoin(lines, newline);
end

%% ---- helpers ---------------------------------------------------------------

function out = didNotCompleteLines(failed)
% List files that errored or were skipped at a hard Quality Gate, grouped by
% kind. Empty (no section) when nothing failed.
out = {};
if isempty(failed), return; end

kinds = arrayfun(@failKind, failed, 'UniformOutput', false);
isSkipped = strcmp(kinds, 'skipped');
errored = failed(~isSkipped);
skipped = failed(isSkipped);

out{end+1} = sprintf('FILES THAT DID NOT COMPLETE (%d)', numel(failed));
out = [out, failGroupLines('Errored:', errored)];
out = [out, failGroupLines('Skipped at Quality Gate:', skipped)];
out{end+1} = '';
end

function out = failGroupLines(header, group)
out = {};
if isempty(group), return; end
out{end+1} = ['  ' header];
for k = 1:numel(group)
    f = group(k);
    [~, stem] = fileparts(f.name);
    stepStr = '';
    if isfield(f, 'stepName') && ~isempty(f.stepName)
        stepStr = sprintf(' at %s', f.stepName);
    end
    reason = '';
    if isfield(f, 'message') && ~isempty(f.message)
        reason = regexprep(f.message, '\s*[\r\n]+\s*', ' | ');
    end
    out{end+1} = sprintf('    %s%s: %s', stem, stepStr, reason); %#ok<AGROW>
end
end

function k = failKind(f)
if isfield(f, 'kind') && ~isempty(f.kind)
    k = f.kind;
else
    k = 'errored';
end
end

function out = pipelineStepLines(reports)
% Numbered list of the pipeline steps in run order, taken from the report that
% ran the most steps (the same representative the methods prose uses). Names
% only - the deliberately "straightforward" companion to the prose paragraph.
out = {};
nSteps = cellfun(@(r) numel(reportStepNames(r)), reports);
[mx, idx] = max(nSteps);
if mx == 0, return; end
names = reportStepNames(reports{idx});
out{end+1} = 'PIPELINE STEPS';
for i = 1:numel(names)
    out{end+1} = sprintf('  %2d. %s', i, names{i}); %#ok<AGROW>
end
out{end+1} = '';
end

function out = badChannelTallyLines(reports, N)
% Cross-file tally of removed electrodes, kept distinct by reason so intentional
% removals are shown but never conflated with bad-channel detection:
%   - quality-based bad-channel steps (kurt/spec/ARTIST/ASR), surfacing
%     recurrent picks so a systematic pattern (montage/reference quirk) is
%     visible rather than buried in the per-file reports;
%   - the deliberate "Remove un-needed Channels" step, listed separately.
out = {};

% Bad-channel detection: recurrent picks first, one-offs collapsed under "once".
[labels, counts] = electrodeFileCounts(reports, 'badChannelNames');
if ~isempty(labels)
    out{end+1} = sprintf('  Bad-channel removals by electrode (%d files):', N);
    recur = counts >= 2;
    if any(recur)
        parts = arrayfun(@(k) sprintf('%s (%d/%d)', labels{k}, counts(k), N), ...
            find(recur), 'UniformOutput', false);
        out{end+1} = ['    ' strjoin(parts, ', ')];
    end
    if any(~recur)
        out{end+1} = ['    once: ' strjoin(labels(~recur), ', ')];
    end
end

% Intentional (un-needed) removals: always shown, distinct from detection. A
% file count is appended only when an electrode was not removed from every file.
[ulabels, ucounts] = electrodeFileCounts(reports, 'unneededNames');
if ~isempty(ulabels)
    parts = arrayfun(@(k) tallyTag(ulabels{k}, ucounts(k), N), ...
        1:numel(ulabels), 'UniformOutput', false);
    out{end+1} = sprintf('  Intentionally removed (un-needed): %s', strjoin(parts, ', '));
end
end

function tag = tallyTag(label, count, N)
% "<label>" when removed from every file, else "<label> (count/N)".
if count >= N
    tag = label;
else
    tag = sprintf('%s (%d/%d)', label, count, N);
end
end

function [labels, counts] = electrodeFileCounts(reports, field)
% For one channel name-list field, the distinct electrode labels and the number
% of FILES each was removed in, sorted by file count descending.
N = numel(reports);
perFile = cell(1, N);
for i = 1:N
    if isfield(reports{i}.channels, field)
        perFile{i} = unique(reports{i}.channels.(field));
    else
        perFile{i} = {};   % legacy report saved before the field existed
    end
end
labels = unique([perFile{:}]);
if isempty(labels)
    counts = [];
    return
end
counts = cellfun(@(lab) sum(cellfun(@(f) any(strcmp(lab, f)), perFile)), labels);
[counts, ord] = sort(counts, 'descend');
labels = labels(ord);
end

function s = fmtStat(v)
% Format a numeric vector as "mean +/- SD" or just the value when all equal.
v = double(v(:));
if isscalar(v)
    s = sprintf('%.1f', v);
elseif std(v) < 1e-9
    s = sprintf('%.1f (all equal)', mean(v));
else
    s = sprintf('%.1f +/- %.1f  [%g - %g]', mean(v), std(v), min(v), max(v));
end
end
