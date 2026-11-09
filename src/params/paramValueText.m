% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = paramValueText(params, key)
% PARAMVALUETEXT  A stored setting as text, for comparing against a relation's values.
%   s = PARAMVALUETEXT(params, key): char as is, a typed logical as
%   'true'/'false' (how schema-2 steps declare them), a numeric scalar via
%   num2str; '' when absent or anything else.
%
%   The one rule every relation uses, so enableWhen and requires cannot
%   disagree about whether a controller holds a listed value.
%
%   See also: paramRelation, disabledParamKeys, paramProblems

s = '';
if ~isstruct(params) || ~isfield(params, key), return; end
v = params.(key);
if islogical(v) && isscalar(v)
    s = char(string(v));
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif ischar(v)
    s = v;
elseif isnumeric(v) && isscalar(v)
    s = num2str(v);
end
end
