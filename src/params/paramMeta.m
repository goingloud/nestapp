% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [m, friendly] = paramMeta(entry, key)
% PARAMMETA  One setting's declaration from a registry entry, and its label.
%   [m, friendly] = PARAMMETA(entry, key): m is the makeParam struct, or []
%   when the entry has no such setting; friendly is its friendlyName, or the
%   key itself when there is none.
%
%   See also: makeParam, disabledParamKeys, paramProblems

m = [];
friendly = key;
if ~isstruct(entry) || ~isfield(entry, 'params') || isempty(entry.params), return; end
ix = find(strcmp({entry.params.key}, key), 1);
if isempty(ix), return; end
m = entry.params(ix);
friendly = m.friendlyName;
end
