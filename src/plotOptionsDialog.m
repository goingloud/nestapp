% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [params, accepted] = plotOptionsDialog(entry, params, anchor)
% PLOTOPTIONSDIALOG  Edit one plot's settings, generated from its registry entry.
%   [params, accepted] = PLOTOPTIONSDIALOG(entry, params, anchor)
%
%   entry    - one element of plotRegistry(), whose .params drives the table
%   params   - the values already set for this plot (struct, possibly empty)
%   anchor   - optional figure to centre on
%
%   Returns the edited params and whether the user accepted them. On cancel -
%   including the window's X - the input is handed back untouched.
%
%   Nothing here knows which plot it is editing. The table is built by
%   buildParamTableData and edits are parsed by applyParamEdit, the same two
%   functions the pipeline's step parameters use, so a plot that declares a new
%   param in plotRegistry gets an editor for it with no change to this file or
%   to the tab. That is the whole reason plot params are makeParam-shaped.
%
%   An unset param stays unset. The table shows the placeholder naming the
%   default and clearing a cell removes the key again, so "I never touched
%   this" and "I set this to the default value" stay distinguishable - the
%   first follows the draw function if its default ever changes, the second
%   does not.
%
%   Modal discipline: waitfor(fig) and a plain delete, never uiwait/uiresume.
%   A nested uiconfirm or uialert inside a figure already sitting in uiwait
%   leaves uiresume unable to release it, and the app hangs - the trap
%   selectDataTree documents and exploreFilesTable was caught by.
%
%   See also: plotRegistry, makeParam, buildParamTableData, applyParamEdit

if nargin < 2 || isempty(params); params = struct(); end
if nargin < 3; anchor = []; end
accepted = false;

meta = entry.params;
if isempty(meta)
    return   % nothing to edit; the caller should not have offered the button
end
original = params;

W = 460; H = min(150 + 24 * numel(meta), 520);
fig = uifigure('Name', sprintf('%s - options', entry.name), ...
               'Position', centreOn(anchor, W, H), 'Resize', 'off');
fig.CloseRequestFcn = @(src, ~) delete(src);   % X == cancel, and nothing else

uilabel(fig, 'Position', [16 H-38 W-32 22], 'Text', entry.name, ...
        'FontWeight', 'bold');

tbl = uitable(fig, 'Position', [16 76 W-32 H-124], ...
    'ColumnName', {'Setting', 'Value'}, 'ColumnWidth', {200, 'auto'}, ...
    'ColumnEditable', [false true], 'RowName', {});
tbl.CellEditCallback   = @onEdit;
tbl.CellSelectionCallback = @onSelect;

hint = uilabel(fig, 'Position', [16 44 W-32 26], 'Text', '', ...
    'FontSize', 11, 'FontColor', [0.35 0.38 0.43], 'WordWrap', 'on');

uibutton(fig, 'Text', 'Reset', 'Position', [16 12 90 26], ...
    'ButtonPushedFcn', @(~,~) onReset());
uibutton(fig, 'Text', 'Cancel', 'Position', [W-206 12 90 26], ...
    'ButtonPushedFcn', @(~,~) delete(fig));
uibutton(fig, 'Text', 'OK', 'Position', [W-106 12 90 26], ...
    'ButtonPushedFcn', @(~,~) onOk());

refresh();
waitfor(fig);

% Cancel, or the X, leaves the caller with exactly what it passed in. Edits are
% applied to the live struct as they are typed - that is what keeps the table
% and the values in step - so the discard has to happen here.
if ~accepted
    params = original;
end

    function refresh()
        tbl.Data = buildParamTableData(struct('name', entry.name, ...
                                              'params', params), entry);
        greyPlaceholderCells(tbl);
    end

    function onEdit(~, ev)
        r = ev.Indices(1);
        if r > numel(meta); return; end
        raw = ev.NewData;
        if isempty(raw) || (ischar(raw) && isempty(strtrim(raw)))
            % Cleared: back to unset, so the draw function's default applies
            % again rather than a frozen copy of what it used to be.
            if isfield(params, meta(r).key)
                params = rmfield(params, meta(r).key);
            end
        else
            s = applyParamEdit(struct('name', entry.name, 'params', params), ...
                               1, r, raw, entry);
            params = s.params;
        end
        refresh();
    end

    function onSelect(~, ev)
        if isempty(ev.Indices); hint.Text = ''; return; end
        r = ev.Indices(1);
        if r <= numel(meta); hint.Text = meta(r).description; end
    end

    function onReset()
        params = struct();
        refresh();
    end

    function onOk()
        accepted = true;
        delete(fig);
    end
end
