
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function summaryText = buildReportText(report)
% BUILDREPORTTEXT  Pure text formatter for a PipelineReport struct.
%   summaryText = BUILDREPORTTEXT(report)
%   Used by exportReport (for the .mat side + UI display) and by
%   exportFileReportPDF (for the cover page) so both share one
%   canonical formatter.

lines = {};
lines{end+1} = '=== Pipeline Report ===';
lines{end+1} = sprintf('File:      %s', report.inputFile);
lines{end+1} = sprintf('Processed: %s', string(report.processedAt, 'yyyy-MM-dd HH:mm:ss'));

% Failure banner - shown when the file was abandoned mid-pipeline and this
% is a partial report (set by processOneFile on a Quality-Gate fail-skip or
% a step error).
if isfield(report, 'failure') && isstruct(report.failure) ...
        && isfield(report.failure, 'failed') && report.failure.failed
    f = report.failure;
    stepTxt = '';
    if isfield(f, 'stepIndex') && isfield(f, 'stepName')
        stepTxt = sprintf(' at step %d (%s)', f.stepIndex, f.stepName);
    end
    msg = '';
    if isfield(f, 'message'); msg = f.message; end
    lines{end+1} = '';
    lines{end+1} = '*** PROCESSING FAILED - partial report ***';
    lines{end+1} = sprintf('Failed%s: %s', stepTxt, msg);
end

% Quality reports - single folder path (all PNGs share a parent).
if isfield(report, 'quality') && isfield(report.quality, 'figures') ...
        && ~isempty(report.quality.figures)
    qcFolder = fileparts(report.quality.figures{1});
    lines{end+1} = sprintf('QC images: %s  (%d files)', ...
        qcFolder, numel(report.quality.figures));
end

% Quality Gate verdict - one summary line for the whole file.
if isfield(report, 'quality') && isfield(report.quality, 'worstVerdict') ...
        && ~strcmp(report.quality.worstVerdict, 'NotChecked')
    lines{end+1} = sprintf('Quality:   %s', report.quality.worstVerdict);
end

lines{end+1} = '';

% Quality Gate details - per-gate verdict and reasons (if any gates ran).
if isfield(report, 'quality') && isfield(report.quality, 'gates') ...
        && ~isempty(report.quality.gates)
    lines{end+1} = 'QUALITY GATES';
    for gi = 1:numel(report.quality.gates)
        g = report.quality.gates{gi};
        stepIx = '';
        if isfield(g, 'stepIndex') && ~isempty(g.stepIndex)
            stepIx = sprintf(' (step %d)', g.stepIndex);
        end
        lines{end+1} = sprintf('  %s%s: %s', g.label, stepIx, g.verdict); %#ok<AGROW>
        if isfield(g, 'reasons') && ~isempty(g.reasons)
            for ri = 1:numel(g.reasons)
                lines{end+1} = sprintf('    - %s', g.reasons{ri}); %#ok<AGROW>
            end
        end
    end
    lines{end+1} = '';
end

% Channels
lines{end+1} = 'CHANNELS';
origCh = report.channels.original;
rejCh  = report.channels.nRejected;
intpCh = report.channels.nInterpolated;
finCh  = report.channels.final;
% Names are optional - older reports predate them, so read defensively.
rejNames  = chFieldOr(report.channels, 'rejectedNames');
intpNames = chFieldOr(report.channels, 'interpolatedNames');
badNames  = chFieldOr(report.channels, 'badChannelNames');
unNames   = chFieldOr(report.channels, 'unneededNames');
lines{end+1} = sprintf('  Original:     %d', origCh);
if rejCh > 0
    % Distinguish detection from intent when the split is available; otherwise
    % fall back to the flat named list (legacy reports) or the bare count.
    if ~isempty(badNames) || ~isempty(unNames)
        lines{end+1} = sprintf('  Rejected:     %d', rejCh);
        if ~isempty(badNames)
            lines{end+1} = sprintf('    bad channels (%d): %s', numel(badNames), strjoin(badNames, ', '));
        end
        if ~isempty(unNames)
            lines{end+1} = sprintf('    un-needed (%d): %s', numel(unNames), strjoin(unNames, ', '));
        end
    elseif ~isempty(rejNames)
        lines{end+1} = sprintf('  Rejected:     %d (%s)', rejCh, strjoin(rejNames, ', '));
    else
        lines{end+1} = sprintf('  Rejected:     %d', rejCh);
    end
end
if intpCh > 0
    if ~isempty(intpNames)
        lines{end+1} = sprintf('  Interpolated: %d (%s)', intpCh, strjoin(intpNames, ', '));
    else
        lines{end+1} = sprintf('  Interpolated: %d', intpCh);
    end
end
lines{end+1} = sprintf('  Final:        %d', finCh);
lines{end+1} = '';

% Trials
lines{end+1} = 'TRIALS';
if report.trials.original > 0
    origTr = report.trials.original;
    rejTr  = report.trials.rejected;
    finTr  = report.trials.final;
    lines{end+1} = sprintf('  Original:  %d', origTr);
    if rejTr > 0
        lines{end+1} = sprintf('  Rejected:  %d', rejTr);
    end
    lines{end+1} = sprintf('  Final:     %d', finTr);
else
    lines{end+1} = '  Not epoched (continuous data)';
end
lines{end+1} = '';

% ICA
lines{end+1} = 'ICA';
if report.ica.nComponents > 0
    nComp = report.ica.nComponents;
    nRej  = report.ica.nRejected;
    % nKept added in M3; fall back for reports saved before that field existed.
    if isfield(report.ica, 'nKept')
        nKept = report.ica.nKept;
    else
        nKept = nComp - nRej;
    end
    multiRound = isfield(report.ica, 'rounds') && numel(report.ica.rounds) > 1;

    % Component counts are only comparable WITHIN a round. Each round
    % re-decomposes the data left by the previous one, and that decomposition
    % is sized by the data's rank, not by how many components the last round
    % removed - remove 11 of 32 components from 32 channels and the next
    % runica still returns ~32. Printing a single Identified/Removed/Kept
    % triple across rounds therefore renders as broken arithmetic
    % ("Identified 32, Removed 11, Kept 32") and makes the later rounds look
    % like they did nothing. For multi-round, report per round instead.
    if multiRound
        lines{end+1} = sprintf(['  Rounds:     %d decompositions ' ...
            '(counts are per-round - each re-decomposes the cleaned data)'], ...
            numel(report.ica.rounds));
    else
        lines{end+1} = sprintf('  Identified: %d components', nComp);
    end

    if nRej > 0
        hasVar   = ~isnan(report.ica.varRemoved);
        hasRange = ~isnan(report.ica.varMin);

        if multiRound
            if hasVar
                % Top-level variance is compounded across rounds (see
                % recomputeICATotals); label it so it is not confused with the
                % per-round, per-basis figures listed below.
                lines{end+1} = sprintf( ...
                    '  Removed:    %d total (%d rounds, %.1f%% ICA variance compounded)', ...
                    nRej, numel(report.ica.rounds), report.ica.varRemoved);
            else
                lines{end+1} = sprintf('  Removed:    %d total (%d rounds)', ...
                    nRej, numel(report.ica.rounds));
            end
        elseif hasVar && hasRange
            lines{end+1} = sprintf( ...
                '  Removed:    %d  (%.1f%% ICA variance, %.1f-%.1f%% per component)', ...
                nRej, report.ica.varRemoved, report.ica.varMin, report.ica.varMax);
        elseif hasVar
            lines{end+1} = sprintf('  Removed:    %d  (%.1f%% ICA variance)', ...
                nRej, report.ica.varRemoved);
        else
            lines{end+1} = sprintf('  Removed:    %d', nRej);
        end
        if ~multiRound
            % Only meaningful on one basis; the per-round lines carry it for
            % multi-round pipelines.
            lines{end+1} = sprintf('  Kept:       %d', nKept);
        end

        % Per-category summary (totals across all rounds). For multi-round the
        % shares are compounded onto the original-variance basis (so they sum to
        % the compounded total above); for single-round they are that round's
        % shares. Either way they are now meaningful to display.
        if isfield(report.ica, 'categories') && any(report.ica.categories.nRemoved > 0)
            if multiRound
                lines{end+1} = '  By category (all rounds, % of original variance):';
            else
                lines{end+1} = '  By category:';
            end
            lines = appendCategoryLines(lines, report.ica.categories, hasVar);
        end

        % Per-round detail for multi-round TESA
        if multiRound
            for ri = 1:numel(report.ica.rounds)
                rnd = report.ica.rounds{ri};
                rndHasVar = ~isnan(rnd.varRemoved);
                if rndHasVar
                    lines{end+1} = sprintf('  Round %d: %d components, %d removed (%.1f%% ICA var, %.1f-%.1f%% per comp)', ...
                        ri, rnd.nComponents, rnd.nRejected, rnd.varRemoved, rnd.varMin, rnd.varMax);
                else
                    lines{end+1} = sprintf('  Round %d: %d components, %d removed', ...
                        ri, rnd.nComponents, rnd.nRejected);
                end
                lines = appendCategoryLines(lines, rnd.categories, rndHasVar);
            end
        end
    else
        lines{end+1} = sprintf('  Removed:    0  (kept all %d)', nKept);
    end
else
    lines{end+1} = '  ICA not run';
end
lines{end+1} = '';

% Steps run
lines{end+1} = 'STEPS RUN';
for k = 1:numel(report.steps)
    rec = report.steps{k};
    chanNote = '';
    if rec.chansAfter ~= rec.chansBefore
        chanNote = sprintf('  [%d -> %d ch]', rec.chansBefore, rec.chansAfter);
    end
    trialNote = '';
    if rec.trialsAfter ~= rec.trialsBefore && rec.trialsBefore > 1
        trialNote = sprintf('  [%d -> %d trials]', rec.trialsBefore, rec.trialsAfter);
    elseif rec.trialsAfter > 1 && rec.trialsBefore <= 1
        trialNote = sprintf('  [-> %d trials]', rec.trialsAfter);
    end
    lines{end+1} = sprintf('  %2d. %-35s %.1fs%s%s', ...
        k, rec.name, rec.duration, chanNote, trialNote);
end
lines{end+1} = '';

% Methods note - one concise sentence per file. The full cross-file methods
% prose (mean +/- SD across files) lives in the session summary; see
% summarizeReports / methodsParagraphAggregate.
lines{end+1} = 'METHODS';
lines{end+1} = ['  ', methodsParagraph(report)];

% Citation - references for the methods this file's pipeline actually used,
% derived from the steps that ran. Same block runPipelineCore prints to the
% batch log and the session summary shows; rendered here so each per-file
% report (and its PDF) carries it.
citeLines = citationLines(reportStepNames(report));
if ~isempty(citeLines)
    lines{end+1} = '';
    lines = [lines, citeLines];
end

summaryText = strjoin(lines, newline);
end
function v = chFieldOr(channels, field)
% A channel name-list field, or {} when absent (older reports predate it).
if isfield(channels, field)
    v = channels.(field);
else
    v = {};
end
end

function lines = appendCategoryLines(lines, cats, showVar)
for ci = 1:numel(cats.names)
    if cats.nRemoved(ci) > 0
        if showVar
            lines{end+1} = sprintf('    %-12s %d  (%.1f%% ICA var)', ...
                [cats.names{ci} ':'], cats.nRemoved(ci), cats.varShare(ci));
        else
            lines{end+1} = sprintf('    %-12s %d', ...
                [cats.names{ci} ':'], cats.nRemoved(ci));
        end
    end
end
end