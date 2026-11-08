% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [msgs, keys] = paramProblems(regEntry, params)
% PARAMPROBLEMS  What is wrong with a step's settings, in the user's words.
%   [msgs, keys] = PARAMPROBLEMS(regEntry, params): msgs is a cellstr, empty when the
%   settings are usable, and keys, the settings involved (the form turns them
%   red). Checked for schema-2 steps:
%     - each value against its own declaration (choices, limits, integer,
%       step, a range's order) - see paramValueProblem;
%     - the step's relations: requires, anyOf, order.
%   Disabled settings (disabledParamKeys) are skipped: they are not passed.
%
%   Used by the pre-flight check, so a run cannot start with settings the
%   upstream function would reject halfway through a batch, and by the form,
%   which shows the involved settings in red.
%
%   See also: paramValueProblem, paramRelation, disabledParamKeys

msgs = {};
keys = {};
if fieldOr(regEntry, 'schema', 1) < 2, return; end
off = disabledParamKeys(regEntry, params);

for m = regEntry.params(:)'
    if any(strcmp(m.key, off)) || ~isfield(params, m.key), continue; end
    why = paramValueProblem(m, params.(m.key));
    if ~isempty(why)
        msgs{end+1} = sprintf('%s: %s', m.friendlyName, why); %#ok<AGROW>
        keys = [keys, {m.key}]; %#ok<AGROW>
    end
end

has  = @(k) ~any(strcmp(k, off)) && isfield(params, k) && paramHasValue(params.(k), metaOf(regEntry, k));
name = @(k) ['"' friendlyOf(regEntry, k) '"'];
rels = fieldOr(regEntry, 'relations', []);
for r = rels(:)'
    switch r.kind
        case 'requires'
            applies = isempty(r.controller) || ismember(valueText(params, r.controller), r.values);
            if applies && ~any(strcmp(r.params{1}, off)) && ~has(r.params{1})
                keys = [keys, r.params(1)]; %#ok<AGROW>
                if isempty(r.controller)
                    msgs{end+1} = sprintf('%s must be set.', name(r.params{1})); %#ok<AGROW>
                else
                    msgs{end+1} = sprintf('%s must be set when %s is "%s".', ...
                        name(r.params{1}), name(r.controller), valueText(params, r.controller)); %#ok<AGROW>
                end
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

function m = metaOf(regEntry, key)
m = [];
ix = find(strcmp({regEntry.params.key}, key), 1);
if ~isempty(ix), m = regEntry.params(ix); end
end

function f = friendlyOf(regEntry, key)
f = key;
m = metaOf(regEntry, key);
if ~isempty(m), f = m.friendlyName; end
end

function s = valueText(params, key)
s = '';
if ~isfield(params, key), return; end
v = params.(key);
if islogical(v) && isscalar(v), s = char(string(v));
elseif ischar(v),               s = v;
elseif isstring(v),             s = char(v);
end
end
