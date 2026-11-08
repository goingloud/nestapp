% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tf = paramHasValue(v, meta)
% PARAMHASVALUE  Does a stored setting hold a value, rather than nothing?
%   tf = PARAMHASVALUE(v)        generic: empty, '[]', {''} and NaN are nothing
%   tf = PARAMHASVALUE(v, meta)  also: a named mode ("Off", "All channels",
%                                "Automatic") is a state, not a value
%
%   The one definition of "set" used by every relationship (exclusive,
%   requires, anyOf, order), so the form, the pre-flight check and the upstream
%   translation cannot disagree about whether a setting was given.
%
%   See also: paramRelation, disabledParamKeys, paramProblems, toUpstream

if nargin < 2, meta = []; end
tf = false;
if isempty(v); return; end
if (ischar(v) || isstring(v)) && any(strcmp(strtrim(char(v)), {'', '[]'})); return; end
if iscell(v) && isscalar(v) && (ischar(v{1}) || isstring(v{1})) ...
        && any(strcmp(strtrim(char(v{1})), {'', '[]'})); return; end
if isnumeric(v) && isscalar(v) && isnan(v); return; end
if ~isempty(meta) && isfield(meta, 'modes') && ~isempty(meta.modes) ...
        && ischar(v) && any(strcmp(v, {meta.modes.key}))
    return
end
tf = true;
end
