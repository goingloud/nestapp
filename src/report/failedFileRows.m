
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function rows = failedFileRows(failed)
% FAILEDFILEROWS  Dashboard table rows for files that did not complete.
%   rows = FAILEDFILEROWS(failed) turns the failure-record array produced by
%   runPipelineCore (fields: name, step, stepName, message, kind) into an
%   Nx4 cell array matching the "Failed / Marginal files" dashboard table
%   columns {File, Gate, Verdict, Reasons}. Errored files get a verdict of
%   'Errored'; files skipped at a hard Quality Gate get 'Skipped'.
%
%   These files never produced a report, so they are invisible to the
%   report-driven collectFailures inside renderDashboardPanel - this is the
%   seam through which they reach the dashboard. Returns cell(0,4) for an
%   empty or missing failure list.

rows = cell(0, 4);
if isempty(failed); return; end

for k = 1:numel(failed)
    f = failed(k);

    [~, stem] = fileparts(f.name);           % stem only, matching report rows

    if isfield(f, 'kind') && strcmp(f.kind, 'skipped')
        verdict = 'Skipped';
    else
        verdict = 'Errored';
    end

    stepCol = '';
    if isfield(f, 'stepName') && ~isempty(f.stepName)
        stepCol = f.stepName;
    elseif isfield(f, 'step') && ~isempty(f.step)
        stepCol = sprintf('step %s', f.step);
    end
    if isempty(stepCol)
        stepCol = char(8212);                % em dash: failed before any step
    end

    reason = '';
    if isfield(f, 'message') && ~isempty(f.message)
        reason = regexprep(f.message, '\s*[\r\n]+\s*', ' | ');
    end

    rows(end+1, :) = {stem, stepCol, verdict, reason}; %#ok<AGROW>
end
end
