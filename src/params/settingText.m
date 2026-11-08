% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = settingText(meta, v)
% SETTINGTEXT  A setting's value in the words the user sees.
%   s = SETTINGTEXT(meta, v): a choice or mode by its label, a logical as
%   on/off, a list joined with commas, a number as written. Used for the
%   "Default:" line in tooltips and the help pane, so a default is never shown
%   as an upstream token.
%
%   See also: settingsForm, makeParam

if islogical(v) && isscalar(v)
    s = 'on'; if ~v, s = 'off'; end
elseif ischar(v) && isfield(meta, 'modes') && ~isempty(meta.modes) && any(strcmp(v, {meta.modes.key}))
    s = meta.modes(strcmp(v, {meta.modes.key})).label;
elseif ischar(v) && isfield(meta, 'choices') && ~isempty(meta.choices) && any(strcmp(v, {meta.choices.key}))
    s = meta.choices(strcmp(v, {meta.choices.key})).label;
elseif iscell(v)
    if isempty(v), s = '(none)'; else, s = strjoin(cellfun(@(x) settingText(meta, x), v, 'UniformOutput', false), ', '); end
elseif ischar(v) || isstring(v)
    s = char(v);
    if isempty(s) || strcmp(s, '[]'), s = '(none)'; end
elseif isnumeric(v) && isempty(v)
    s = '(none)';
elseif isnumeric(v) && numel(v) == 2
    s = sprintf('%g to %g', v(1), v(2));
elseif isnumeric(v) || islogical(v)
    s = mat2str(v);
else
    s = sprintf('<%s>', class(v));
end
end
