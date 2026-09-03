
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tf = reportHasGates(report)
% REPORTHASGATES  True if one pipeline report carries Quality Gate data.
%   report : a pipeline report struct (see initPipelineReport).
%
%   The scalar predicate behind anyReportHasGates. Callers that hold raw
%   report structs (runPipelineCore) use this directly; callers that hold
%   Reports-tab entries use anyReportHasGates, which unwraps them first.
%   Keeping the two apart means neither side has to fake the other's shape.
%
%   See also: anyReportHasGates, qualityGate, renderDashboardPanel

tf = isstruct(report) && isfield(report, 'quality') ...
    && isfield(report.quality, 'gates') && ~isempty(report.quality.gates);
end
