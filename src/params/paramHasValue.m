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
if isBlankText(v); return; end
% A list of blank (or '[]') strings is how an unset list arrives from text.
if iscell(v) && all(cellfun(@isBlankText, v)); return; end
if isnumeric(v) && isscalar(v) && isnan(v); return; end
if ~isempty(meta) && isfield(meta, 'modes') && ~isempty(meta.modes) ...
        && ischar(v) && any(strcmp(v, {meta.modes.key}))
    return
end
tf = true;
end

function tf = isBlankText(x)
% '' / '[]' / whitespace, as a char row or a scalar string. Anything else -
% a char matrix, a missing string, a number - is not blank text.
tf = false;
if ischar(x) && (isempty(x) || isrow(x))
    tf = any(strcmp(strtrim(x), {'', '[]'}));
elseif isstring(x) && isscalar(x) && ~ismissing(x)
    tf = any(strcmp(strtrim(char(x)), {'', '[]'}));
end
end
