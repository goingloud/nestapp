
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
%   See also: canStepBlock, stepRegistry, runPipelineCore

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

    % canStepBlock owns "could this ever block"; the conditional half below
    % is what needs the params this function has and it does not.
    [~, blocks] = canStepBlock(registry(k));

    % Some steps block only in certain modes - TESA compselect opens its
    % manual component review and waits only when compCheck is on. Check the
    % parameters this step is actually configured with, so a pipeline that
    % leaves review off is not warned about a dialog it will never see.
    if ~blocks && isfield(registry(k), 'interactiveWhen')
        blocks = matchesAnyRule(registry(k).interactiveWhen, params(spec(i)));
    end

    if blocks
        names{end+1} = registry(k).name; %#ok<AGROW>
    end
end
names = unique(names, 'stable');
end

% ── helpers ─────────────────────────────────────────────────────────────────
function p = params(step)
if isfield(step, 'params') && isstruct(step.params)
    p = step.params;
else
    p = struct();
end
end

function tf = matchesAnyRule(rules, p)
tf = false;
for r = 1:numel(rules)
    key = rules(r).param;
    if ~isfield(p, key); continue; end
    v = p.(key);
    if isstring(v); v = char(v); end
    if ~ischar(v); continue; end
    if any(strcmpi(v, rules(r).values))
        tf = true; return
    end
end
end
