
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function v = reportCounts(report, group, names)
% REPORTCOUNTS  Numeric counts out of one pipeline-report sub-struct.
%   v = REPORTCOUNTS(report, group, names)
%
%   report - a pipeline report struct (see initPipelineReport).
%   group  - name of the sub-struct to read ('channels', 'trials', 'ica').
%   names  - cellstr of field names to pull from it.
%
%   Returns a 1xN double, NaN wherever the report does not carry a usable
%   scalar numeric value. NaN rather than 0 is the whole point: a legacy or
%   partial report that never recorded a count must not read downstream as
%   "zero channels retained" and be averaged in as a real measurement.
%
%   Used by the batch session_summary.csv writer so every run records the
%   retention numbers a methods table needs.
%
%   See also: initPipelineReport, runPipelineCore, summarizeReports

v = nan(1, numel(names));
if ~isstruct(report) || ~isfield(report, group) || ~isstruct(report.(group))
    return
end
g = report.(group);
for k = 1:numel(names)
    if isfield(g, names{k}) && isnumeric(g.(names{k})) && isscalar(g.(names{k}))
        v(k) = double(g.(names{k}));
    end
end
end
