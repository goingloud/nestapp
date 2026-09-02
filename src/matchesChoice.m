% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tf = matchesChoice(value, choice)
% MATCHESCHOICE  Is this stored enum value the named choice?
%   tf = MATCHESCHOICE(value, choice)
%
%   Compares a param value against one of its validRange choices, ignoring
%   case, surrounding whitespace, and the spaces and hyphens INSIDE the words.
%   So 'per map', 'per-map', 'PerMap' and ' Per Map ' all match 'per map'.
%
%   Why the tolerance is needed. A registry choice is written for a reader -
%   'second - first', 'per window' - and that exact string is what the dropdown
%   stores and what a saved .mat carries. But the same value also arrives by
%   hand: typed into a session file, set by a script driving the headless API,
%   or copied out of a docstring where it was spelled with a hyphen. A strict
%   strcmp on the display spelling silently falls back to the default for all
%   of those, which looks like the setting being ignored.
%
%   Factored out because three draw functions had each grown their own version
%   of this and they had already drifted: two stripped only spaces, one
%   stripped spaces and hyphens, so 'per-map' matched in one and not in the
%   others. Any future enum-valued draw option would have been a fourth.
%
%   Non-empty is not assumed: [] and '' match nothing, which is what an unset
%   param should do.
%
%   See also: plotRegistry, makeParam, paramForm, plotDrawOpts

tf = strcmp(squash(value), squash(choice)) && ~isempty(squash(choice));
end

function s = squash(v)
% A dropdown hands back its ItemsData, which for a single-choice list is the
% char itself but for a cell-valued store may arrive wrapped, so one level of
% cell is unwrapped. Anything that is not scalar text is not a choice name.
s = '';
if iscell(v) && isscalar(v); v = v{1}; end
if isempty(v) || ~(ischar(v) || (isstring(v) && isscalar(v))); return; end
s = lower(regexprep(char(strtrim(string(v))), '[\s\-_]+', ''));
end
