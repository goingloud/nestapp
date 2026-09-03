% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [entries, categories] = availablePlots(ctx, registry)
% AVAILABLEPLOTS  The plot catalogue, annotated with what can render right now.
%   [entries, categories] = AVAILABLEPLOTS(ctx) returns every registry entry
%   with two fields added:
%     .available  logical, from plotAvailability
%     .reason     why not, when unavailable
%
%   categories groups them for the picker in plotTaxonomy order:
%     .name    heading
%     .entries the entries under it, taxonomy order preserved
%
%   Nothing is removed. Unlike availableSteps, which withholds a step that
%   cannot run because building a pipeline around it would fail later, a plot
%   that cannot render costs nothing to show: the user is one group away from
%   it and needs to be able to see that. So every entry is returned and the
%   picker greys the unavailable ones with their reason.
%
%   An entry the taxonomy does not mention is collected under 'Other', so
%   adding to plotRegistry and forgetting plotTaxonomy loses the ordering but
%   never the feature - the same safety net populateStepsTree has.
%
%   See also: plotRegistry, plotTaxonomy, plotAvailability

if nargin < 1; ctx = struct(); end
if nargin < 2 || isempty(registry); registry = plotRegistry(); end

entries = registry;
for i = 1:numel(entries)
    [entries(i).available, entries(i).reason] = plotAvailability(registry(i), ctx);
end

if nargout < 2; return; end

tax        = plotTaxonomy();
categories = struct('name', {}, 'entries', {});
placed     = {};
names      = {entries.name};

for c = 1:numel(tax)
    idx = [];
    for k = 1:numel(tax(c).plots)
        j = find(strcmp(names, tax(c).plots{k}), 1);
        if ~isempty(j); idx(end+1) = j; end %#ok<AGROW>
    end
    if isempty(idx); continue; end
    categories(end+1) = struct('name', tax(c).name, 'entries', entries(idx)); %#ok<AGROW>
    placed = [placed, names(idx)]; %#ok<AGROW>
end

orphan = find(~ismember(names, placed));
if ~isempty(orphan)
    categories(end+1) = struct('name', 'Other', 'entries', entries(orphan));
end
end
