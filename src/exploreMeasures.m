% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function T = exploreMeasures(res, windows)
% EXPLOREMEASURES  Per-subject, per-group window measures as a table.
%   T = EXPLOREMEASURES(res, windows) takes a groupCurves result and the windows
%   of interest and returns one row per (group, subject, window).
%
%   This is the Measures exit - the thing a CSV should carry. It is small,
%   tabular, and shaped for the software that will actually run the statistics:
%   one row per observation, group and subject as columns to split by. Curves at
%   sampling rate deliberately do NOT come out this way; they are millions of
%   cells with no units and no metadata, and they belong in the Results .mat
%   (see exploreResults).
%
%   The per-window arithmetic is tepWindowTable's, unchanged, so a measure here
%   is the same number the Analysis tab's export and the batch CSV produce. Only
%   two things are added: the group column, and subject in place of file -
%   because rows are subjects now, files having already been collapsed by
%   groupCurves.
%
%   windows defaults to defaultTEPComponentDefs (N15, P30, N45, P60, N100,
%   P180 - the windows the TEP-topo view places its maps at, so a measure and
%   the map above it always describe the same interval).
%
%   See also: tepWindowTable, groupCurves, defaultTEPComponentDefs, exploreResults

if nargin < 2 || isempty(windows)
    windows = defaultTEPComponentDefs();
end

T = table();
if isempty(res) || ~isfield(res, 'groups') || isempty(res.groups)
    return
end

mode = 'TEP';
if isfield(res, 'mode') && ~isempty(res.mode); mode = res.mode; end

parts = cell(1, numel(res.groups));
for g = 1:numel(res.groups)
    grp = res.groups(g);
    if isempty(grp.subjects); continue; end
    part = tepWindowTable(grp.subjects, grp.curves, res.time, windows, mode);
    part.Properties.VariableNames{strcmp(part.Properties.VariableNames, 'file')} ...
        = 'subject';
    part = addvars(part, repmat({grp.name}, height(part), 1), ...
                   'Before', 1, 'NewVariableNames', 'group');
    parts{g} = part;
end

parts = parts(~cellfun(@isempty, parts));
if ~isempty(parts)
    T = vertcat(parts{:});
end
end
