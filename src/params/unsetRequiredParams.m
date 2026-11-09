
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [stepIdx, keys, labels] = unsetRequiredParams(spec, registry)
% UNSETREQUIREDPARAMS  Required parameters a pipeline has not been given.
%   [stepIdx, keys, labels] = UNSETREQUIREDPARAMS(spec) finds the first step in
%   spec that declares a required parameter with no value, and returns its
%   index, the unset keys, and their friendly labels. stepIdx is empty when
%   nothing is missing.
%
%   "Required" is declared on the parameter (makeParam(..., 'required', true)),
%   not listed here, so a step that grows a new required parameter is picked up
%   without editing this function or the GUI that calls it.
%
%   This exists so a template whose parameters cannot have sensible defaults -
%   AARATEP needs an output folder, and there is no reasonable guess - can ask
%   for them when it is loaded, instead of the user discovering it when a run
%   they have already started fails.
%
%   See also: availableSteps, stepRegistry

if nargin < 2 || isempty(registry)
    registry = stepRegistry();
end

stepIdx = [];
keys    = {};
labels  = {};

if isempty(spec) || ~isfield(spec, 'name')
    return
end

for i = 1:numel(spec)
    k = find(strcmp({registry.name}, spec(i).name), 1);
    if isempty(k); continue; end
    params = registry(k).params;
    if isempty(params) || ~isfield(params, 'required'); continue; end

    stepKeys = {}; stepLabels = {};
    for j = 1:numel(params)
        if isempty(params(j).required) || ~params(j).required
            continue
        end
        if ~hasValue(spec(i), params(j).key)
            stepKeys{end+1}   = params(j).key;          %#ok<AGROW>
            stepLabels{end+1} = params(j).friendlyName; %#ok<AGROW>
        end
    end

    if ~isempty(stepKeys)
        stepIdx = i; keys = stepKeys; labels = stepLabels;
        return
    end
end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function tf = hasValue(step, key)
% Set, by the one definition every settings check uses (paramHasValue).
tf = isfield(step, 'params') && isstruct(step.params) && isfield(step.params, key) ...
    && paramHasValue(step.params.(key));
end
