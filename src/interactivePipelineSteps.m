
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function names = interactivePipelineSteps(spec, registry)
% INTERACTIVEPIPELINESTEPS  Steps in a spec that block waiting for a human.
%   names = INTERACTIVEPIPELINESTEPS(spec) returns the unique names of steps
%   in spec flagged `interactive` in the registry - steps that open a modal,
%   a rejection menu, or a plot the user must close before the run continues.
%
%   names = INTERACTIVEPIPELINESTEPS(spec, registry) reuses a registry the
%   caller already loaded.
%
%   Why this matters: such a step cannot run on a parallel worker. Workers are
%   handed uiFigure = [] and have no display, so the run either errors on
%   every file or blocks with nothing to click - after the batch has started,
%   which is the worst time to find out. The app calls this before a run and
%   offers to turn parallel off.
%
%   The flag lives on the registry entry rather than in a name list here, so
%   adding an interactive step cannot forget to update a second file.
%
%   See also: stepRegistry, runPipelineCore

if nargin < 2 || isempty(registry)
    registry = stepRegistry();
end

names = {};
if isempty(spec) || ~isfield(spec, 'name')
    return
end

for i = 1:numel(spec)
    k = find(strcmp({registry.name}, spec(i).name), 1);
    if isempty(k); continue; end
    if isfield(registry(k), 'interactive') && ...
            ~isempty(registry(k).interactive) && registry(k).interactive
        names{end+1} = registry(k).name; %#ok<AGROW>
    end
end
names = unique(names, 'stable');
end
