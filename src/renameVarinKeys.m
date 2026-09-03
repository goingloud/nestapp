
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function vars = renameVarinKeys(vars, fromKeys, toKeys)
% RENAMEVARINKEYS  Rename name/value keys in a varargin cell.
%   vars = RENAMEVARINKEYS(vars, fromKeys, toKeys) replaces each key in
%   fromKeys with the key at the same position in toKeys, leaving values and
%   ordering untouched. Only key positions (odd indices) are eligible, so a
%   value that happens to equal a from-key is never rewritten.
%
%   Used at dispatch to map nestapp's param keys onto an upstream function's
%   exact spelling where that function is case-sensitive about option names
%   (e.g. tesa_findpulse's tmsLabel/pairLabel), so the mapping is applied to
%   every call - including one rebuilt from an old saved pipeline.

for i = 1:numel(fromKeys)
    for k = 1:2:numel(vars)
        if strcmp(vars{k}, fromKeys{i})
            vars{k} = toKeys{i};
        end
    end
end
end
