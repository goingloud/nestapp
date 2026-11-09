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
%   See also: paramRelation, paramHasValue, toUpstream, settingsForm

keys    = {};
reasons = struct();
rels    = fieldOr(regEntry, 'relations', []);
for r = rels(:)'
    switch r.kind
        case 'exclusive'
            isSet = cellfun(@(k) isfield(params, k) && ...
                paramHasValue(params.(k), paramMeta(regEntry, k)), r.params);
            if ~any(isSet), continue; end
            keep = find(isSet, 1);
            [~, keptName] = paramMeta(regEntry, r.params{keep});
            for j = setdiff(1:numel(r.params), keep)
                keys{end+1} = r.params{j}; %#ok<AGROW>
                reasons.(r.params{j}) = sprintf( ...
                    ['"%s" is set, and these are two ways of writing the same ' ...
                     'setting. Clear it to use this one.'], keptName);
            end
        case 'enableWhen'
            if ~ismember(paramValueText(params, r.controller), r.values)
                [ctl, ctlName] = paramMeta(regEntry, r.controller);
                keys{end+1} = r.params{1}; %#ok<AGROW>
                reasons.(r.params{1}) = sprintf('Only used when "%s" is %s.', ...
                    ctlName, strjoin(cellfun(@(v) ['"' valueLabel(ctl, v) '"'], ...
                    r.values, 'UniformOutput', false), ' or '));
            end
    end
end
keys = unique(keys, 'stable');
end

function s = valueLabel(meta, v)
% A declared value in the user's words: its choice label, on/off for a typed
% checkbox (declared as 'true'/'false'), else as written.
s = v;
if isempty(meta), return; end
if any(strcmp(v, {'true', 'false'})), s = settingText(meta, strcmp(v, 'true')); return; end
s = settingText(meta, v);
end
