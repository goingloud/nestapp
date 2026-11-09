% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function r = paramRelation(kind, params, controller, values)
% PARAMRELATION  One declared relationship between a step's settings.
%   r = PARAMRELATION('exclusive',  {a, b, ...})
%       Two (or more) ways of writing one setting. Only one may hold a value;
%       setting it disables the others. Listed in precedence order: if an old
%       file sets several, the first one set wins.
%   r = PARAMRELATION('enableWhen', a, controller, {v1, v2, ...})
%       a only applies while controller is one of the values. Otherwise it is
%       disabled in the form and NOT passed upstream.
%   r = PARAMRELATION('requires',   a, controller, {v1, ...})
%       a must hold a value while controller is one of the values. (A setting
%       that must ALWAYS hold a value is declared with makeParam's 'required'.)
%   r = PARAMRELATION('anyOf',      {a, b, ...})
%       At least one of these must hold a value.
%   r = PARAMRELATION('order',      {a, b})
%       When both hold a value, a < b.
%
%   One vocabulary for every step, read by the form (disabled states and their
%   reasons), the pre-flight check (paramProblems) and toUpstream (what is
%   passed). A relationship that exists only in a description's prose is one
%   the interface cannot honour, which is why steps declare them here.
%
%   See also: disabledParamKeys, paramProblems, toUpstream, stepRegistry

if nargin < 3, controller = ''; end
if nargin < 4, values = {}; end
if ischar(params), params = {params}; end
known = {'exclusive', 'enableWhen', 'requires', 'anyOf', 'order'};
if ~any(strcmp(kind, known))
    error('paramRelation:kind', 'Unknown relationship "%s".', kind);
end
if any(strcmp(kind, {'enableWhen', 'requires'})) && (isempty(controller) || isempty(values))
    error('paramRelation:controller', '"%s" needs a controller and its values.', kind);
end
r = struct('kind', kind, 'params', {params}, 'controller', controller, ...
    'values', {cellstr(values)});
end
