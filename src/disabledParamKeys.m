
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [keys, reasons] = disabledParamKeys(regEntry, params)
% DISABLEDPARAMKEYS  Parameters the GUI should grey out and lock for a step.
%   [keys, reasons] = DISABLEDPARAMKEYS(regEntry, params) returns the param
%   keys to disable for a step, given its registry entry and current values,
%   plus a struct of per-key explanations (reasons.(key)) for the alert shown
%   when the user tries to edit a disabled param.
%
%   Two declarative relationships are honoured, both read from regEntry:
%     exclusiveParamGroups - cell of ordered key-lists. The members of a group
%       are alternative ways of writing one setting, so only one may hold a
%       value. The highest-precedence member that is set (index 1 = precedence)
%       stays editable; the rest are disabled. (Reproduces the old keep/remove
%       behaviour: both set -> lower disabled; only one set -> the other
%       disabled; neither set -> nothing disabled.)
%     paramEnableWhen - rules struct array (.param, .controller, .values). A
%       param is disabled unless params.(controller) is one of .values.
%
%   Inputs:
%     regEntry - one element of stepRegistry() (uses .exclusiveParamGroups,
%                .paramEnableWhen and .params for friendly names).
%     params   - the step's params struct (spec(i).params).
%
%   Output:
%     keys    - cellstr of disabled param keys (possibly empty).
%     reasons - struct keyed by disabled key -> human-readable explanation.

    keys    = {};
    reasons = struct();

    % -- mutually-exclusive groups --
    groups = {};
    if isfield(regEntry, 'exclusiveParamGroups')
        groups = regEntry.exclusiveParamGroups;
    end
    for gi = 1:numel(groups)
        grp   = groups{gi};
        isSet = cellfun(@(k) ~isempty(getParam(params, k)), grp);
        if ~any(isSet)
            continue
        end
        keep = find(isSet, 1);   % highest-precedence member that is set
        for j = 1:numel(grp)
            if j == keep
                continue
            end
            keys{end+1} = grp{j}; %#ok<AGROW>
            reasons.(grp{j}) = sprintf( ...
                ['"%s" is set, and these are two ways of writing the same ' ...
                 'setting. Clear it before editing this one.'], ...
                friendlyOf(regEntry, grp{keep}));
        end
    end

    % -- conditional enablement --
    rules = [];
    if isfield(regEntry, 'paramEnableWhen')
        rules = regEntry.paramEnableWhen;
    end
    for ri = 1:numel(rules)
        rule = rules(ri);
        cur  = getParam(params, rule.controller);
        if ~ismember(char(string(cur)), rule.values)
            keys{end+1} = rule.param; %#ok<AGROW>
            reasons.(rule.param) = sprintf('Applies only when "%s" is %s.', ...
                friendlyOf(regEntry, rule.controller), strjoin(rule.values, ' or '));
        end
    end

    keys = unique(keys, 'stable');
end

% ── local helpers ─────────────────────────────────────────────────────────────

function v = getParam(params, key)
    if isstruct(params) && isfield(params, key)
        v = params.(key);
    else
        v = [];
    end
end

function f = friendlyOf(regEntry, key)
% Friendly label for a param key, falling back to the key itself.
    f = key;
    if isfield(regEntry, 'params') && ~isempty(regEntry.params)
        ix = find(strcmp({regEntry.params.key}, key), 1);
        if ~isempty(ix)
            f = regEntry.params(ix).friendlyName;
        end
    end
end
