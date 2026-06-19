
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function keys = overriddenParamKeys(stepName, params)
% OVERRIDDENPARAMKEYS  Parameter keys disabled by a mutually-exclusive sibling.
%   keys = OVERRIDDENPARAMKEYS(stepName, params) returns the param keys that
%   should be shown disabled (greyed, non-editable) in the parameter table
%   because a mutually-exclusive sibling parameter is in use. The two params
%   are just two ways of writing the same selection, so only one may hold a
%   value at a time.
%
%   'Remove un-needed Channels' is the one step with such a pair: 'channel'
%   ("Keep channels") and 'nochannel' ("Remove channels"). pop_select keeps
%   only the 'channel' list when it is set, so 'channel' takes precedence:
%     - 'channel' set      -> 'nochannel' is overridden (whether or not both
%                             are set; this also breaks the both-set tie).
%     - only 'nochannel'   -> 'channel' is overridden, so the user clears
%                             'nochannel' first to switch to a keep-list.
%
%   Inputs:
%     stepName - pipeline step name.
%     params   - the step's params struct (spec(i).params).
%
%   Output:
%     keys - cellstr of overridden param keys (possibly empty).

    keys = {};
    if ~strcmp(stepName, 'Remove un-needed Channels')
        return
    end

    keepSet = isfield(params, 'channel')   && ~isempty(params.channel);
    rmSet   = isfield(params, 'nochannel') && ~isempty(params.nochannel);

    if keepSet
        keys = {'nochannel'};   % Keep channels in use (or both) -> Remove disabled
    elseif rmSet
        keys = {'channel'};     % only Remove channels in use   -> Keep disabled
    end
end
