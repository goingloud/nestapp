% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [params, accepted] = plotOptionsDialog(entry, params, anchor)
% PLOTOPTIONSDIALOG  Edit one plot's settings, generated from its registry entry.
%   [params, accepted] = PLOTOPTIONSDIALOG(entry, params, anchor)
%
%   entry    one element of plotRegistry(), whose .params drives the form
%   params   the values already set for this plot (struct, possibly empty)
%   anchor   optional figure to centre on
%
%   Returns the edited params and whether the user accepted them. On cancel -
%   including the window's X - the input is handed back untouched.
%
%   Nothing here knows which plot it is editing. paramForm reads the makeParam
%   metadata and picks a control per setting, so a plot that declares a new
%   param in plotRegistry gets a usable editor for it with no change to this
%   file or to the tab. That is the whole reason plot params are makeParam
%   -shaped.
%
%   AN UNSET PARAM STAYS UNSET. Every control can say "default", and a setting
%   the user has not touched is absent from the returned struct rather than
%   frozen to a copy of whatever the default is today. So "I never touched this"
%   and "I set this to the default value" stay distinguishable - the first
%   follows the draw function if its default ever changes, the second does not.
%
%   Modal discipline: waitfor(fig) and a plain delete, never uiwait/uiresume.
%   A nested uiconfirm or uialert inside a figure already sitting in uiwait
%   leaves uiresume unable to release it, and the app hangs - the trap
%   selectDataTree documents and exploreFilesTable was caught by.
%
%   See also: paramForm, plotRegistry, makeParam, plotDrawOpts

if nargin < 2 || isempty(params); params = struct(); end
if nargin < 3; anchor = []; end
accepted = false;

meta = entry.params;
if isempty(meta)
    return   % nothing to edit; the caller should not have offered the button
end
original = params;

ROW_H = 34;
W     = 470;
formH = ROW_H * numel(meta) + 8;
H     = formH + 108;

fig = uifigure('Name', sprintf('%s - options', entry.name), ...
               'Position', centreOn(anchor, W, H), 'Resize', 'off');
fig.CloseRequestFcn = @(src, ~) delete(src);   % X == cancel, and nothing else

uilabel(fig, 'Position', [16 H-32 W-32 22], 'Text', entry.name, ...
        'FontWeight', 'bold');

form = uipanel(fig, 'Position', [16 56 W-32 formH], 'BorderType', 'none');
paramForm(form, meta, params, @onChange);

uibutton(fig, 'Text', 'Reset', 'Position', [16 16 90 26], ...
    'Tooltip', 'Put every setting back to its default.', ...
    'ButtonPushedFcn', @(~,~) onReset());
uibutton(fig, 'Text', 'Cancel', 'Position', [W-206 16 90 26], ...
    'ButtonPushedFcn', @(~,~) delete(fig));
uibutton(fig, 'Text', 'OK', 'Position', [W-106 16 90 26], ...
    'ButtonPushedFcn', @(~,~) onOk());

waitfor(fig);

% Cancel, or the X, leaves the caller with exactly what it passed in. Edits are
% applied to the live struct as they are made - that is what keeps the controls
% and the values in step - so the discard has to happen here.
if ~accepted
    params = original;
end

    function onChange(key, value)
        if isempty(value)
            if isfield(params, key); params = rmfield(params, key); end
        else
            params.(key) = value;
        end
    end

    function onReset()
        params = struct();
        delete(form.Children);
        paramForm(form, meta, params, @onChange);
    end

    function onOk()
        accepted = true;
        delete(fig);
    end
end
