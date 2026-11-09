% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [msgs, keys] = paramProblems(regEntry, params, off)
% PARAMPROBLEMS  What is wrong with a step's settings, in the user's words.
%   [msgs, keys] = PARAMPROBLEMS(regEntry, params): msgs is a cellstr, empty when the
%   settings are usable, and keys, the settings involved (the form turns them
%   red). Checked for schema-2 steps:
%     - each value against its own declaration (choices, limits, integer,
%       step, a range's order) - see paramValueProblem;
%     - the step's relations: requires, anyOf, order.
%   Disabled settings (disabledParamKeys) are skipped: they are not passed.
%   A caller that already has them can pass them as off.
%
%   Used by the pre-flight check, so a run cannot start with settings the
%   upstream function would reject halfway through a batch, and by the form,
%   which shows the involved settings in red.
%
%   See also: paramValueProblem, paramRelation, disabledParamKeys

msgs = {};
keys = {};
if fieldOr(regEntry, 'schema', 1) < 2, return; end
if nargin < 3, off = disabledParamKeys(regEntry, params); end

for m = regEntry.params(:)'
    if any(strcmp(m.key, off)) || ~isfield(params, m.key), continue; end
    why = paramValueProblem(m, params.(m.key));
    if ~isempty(why)
        msgs{end+1} = sprintf('%s: %s', m.friendlyName, why); %#ok<AGROW>
        keys = [keys, {m.key}]; %#ok<AGROW>
    end
end

has  = @(k) ~any(strcmp(k, off)) && isfield(params, k) && paramHasValue(params.(k), paramMeta(regEntry, k));
name = @(k) ['"' nameOf(regEntry, k) '"'];
rels = fieldOr(regEntry, 'relations', []);
for r = rels(:)'
    switch r.kind
        case 'requires'
            ctl = paramValueText(params, r.controller);
            if ismember(ctl, r.values) && ~any(strcmp(r.params{1}, off)) && ~has(r.params{1})
                keys = [keys, r.params(1)]; %#ok<AGROW>
                msgs{end+1} = sprintf('%s must be set when %s is "%s".', ...
                    name(r.params{1}), name(r.controller), settingText(paramMeta(regEntry, r.controller), ctl)); %#ok<AGROW>
            end
        case 'anyOf'
            if ~any(cellfun(has, r.params))
                keys = [keys, r.params]; %#ok<AGROW>
                msgs{end+1} = sprintf('Set at least one of %s.', ...
                    strjoin(cellfun(name, r.params, 'UniformOutput', false), ' or ')); %#ok<AGROW>
            end
        case 'order'
            a = r.params{1}; b = r.params{2};
            if has(a) && has(b) && isnumeric(params.(a)) && isnumeric(params.(b)) ...
                    && ~(params.(a)(1) < params.(b)(1))
                keys = [keys, {a, b}]; %#ok<AGROW>
                msgs{end+1} = sprintf('%s must be below %s.', name(a), name(b)); %#ok<AGROW>
            end
    end
end
end

function f = nameOf(regEntry, key)
[~, f] = paramMeta(regEntry, key);
end
