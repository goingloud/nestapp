% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [keys, reasons] = disabledParamKeys(regEntry, params)
% DISABLEDPARAMKEYS  Settings that do not apply right now, and why.
%   [keys, reasons] = DISABLEDPARAMKEYS(regEntry, params) returns the keys to
%   disable for a step given its current values, and reasons.(key), a sentence
%   the form shows for each.
%
%   Read from the step's declared relations (see paramRelation):
%     exclusive  - only one member may hold a value. The first member set (in
%                  declared precedence order) stays editable; the rest are
%                  disabled. Nothing set: nothing disabled.
%     enableWhen - a setting is disabled unless its controller holds one of
%                  the listed values.
%
%   toUpstream drops the same keys, so a disabled setting is never passed to
%   the upstream function either.
%
%   See also: paramRelation, paramHasValue, toUpstream, paramForm

keys    = {};
reasons = struct();
rels    = fieldOr(regEntry, 'relations', []);
for r = rels(:)'
    switch r.kind
        case 'exclusive'
            isSet = cellfun(@(k) paramHasValue(getParam(params, k), metaOf(regEntry, k)), r.params);
            if ~any(isSet), continue; end
            keep = find(isSet, 1);
            for j = setdiff(1:numel(r.params), keep)
                keys{end+1} = r.params{j}; %#ok<AGROW>
                reasons.(r.params{j}) = sprintf( ...
                    ['"%s" is set, and these are two ways of writing the same ' ...
                     'setting. Clear it to use this one.'], friendlyOf(regEntry, r.params{keep}));
            end
        case 'enableWhen'
            cur = valueText(getParam(params, r.controller));
            if ~ismember(cur, r.values)
                keys{end+1} = r.params{1}; %#ok<AGROW>
                reasons.(r.params{1}) = sprintf('Only used when "%s" is %s.', ...
                    friendlyOf(regEntry, r.controller), ...
                    strjoin(choiceLabels(regEntry, r.controller, r.values), ' or '));
            end
    end
end
keys = unique(keys, 'stable');
end

% ── local helpers ─────────────────────────────────────────────────────────────

function v = getParam(params, key)
v = [];
if isstruct(params) && isfield(params, key), v = params.(key); end
end

function m = metaOf(regEntry, key)
m = [];
if isfield(regEntry, 'params') && ~isempty(regEntry.params)
    ix = find(strcmp({regEntry.params.key}, key), 1);
    if ~isempty(ix), m = regEntry.params(ix); end
end
end

function f = friendlyOf(regEntry, key)
f = key;
m = metaOf(regEntry, key);
if ~isempty(m), f = m.friendlyName; end
end

function labels = choiceLabels(regEntry, key, values)
% The words the user sees for those values: a choice's label where the setting
% has choices, "on"/"off" for a typed checkbox, else the value itself.
labels = values;
m = metaOf(regEntry, key);
if isempty(m), return; end
for k = 1:numel(values)
    if isfield(m, 'choices') && ~isempty(m.choices)
        ix = find(strcmp({m.choices.key}, values{k}), 1);
        if ~isempty(ix), labels{k} = m.choices(ix).label; end
    elseif any(strcmp(values{k}, {'true', 'false'}))
        labels{k} = strrep(strrep(values{k}, 'true', 'on'), 'false', 'off');
    end
end
labels = cellfun(@(s) ['"' s '"'], labels, 'UniformOutput', false);
end

function s = valueText(v)
% Compare a stored value against declared values as text. A typed logical
% reads as 'true'/'false', which is how schema-2 steps declare them.
if islogical(v) && isscalar(v)
    s = char(string(v));
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif ischar(v)
    s = v;
elseif isnumeric(v) && isscalar(v)
    s = num2str(v);
else
    s = '';
end
end
