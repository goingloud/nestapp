% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [opts, action] = figureExportDialog(defaults, anchor)
% FIGUREEXPORTDIALOG  Choose the size and resolution of a publication figure.
%   [opts, action] = FIGUREEXPORTDIALOG(defaults, anchor)
%
%   Returns a publicationFigure opts struct and one of:
%     'open'   open the figure in MATLAB, leave it there to be edited
%     'save'   write it to opts.file at the chosen resolution
%     'cancel' do nothing
%
%   Both exits matter, and offering only one is why the old tab confused
%   people. A figure that lands in MATLAB is for adjusting - the MATLAB figure
%   tools are better at that than anything the app could grow, and the app
%   should not try to compete with them. A figure that lands in a file is
%   finished, at the width the journal asked for and at print resolution. The
%   same composition backs both, so what is saved is what was opened.
%
%   Settings are the makeParam/uitable pattern the rest of the app uses, so the
%   greying convention and the value parsing are the ones the user already
%   knows from the step and plot tables.
%
%   Modal discipline: waitfor + delete, never uiwait/uiresume - a nested
%   uiputfile inside a figure sitting in uiwait is exactly the freeze that
%   selectDataTree documents.
%
%   See also: publicationFigure, plotOptionsDialog, makeParam

if nargin < 1 || isempty(defaults); defaults = struct(); end
if nargin < 2; anchor = []; end

% Seeded EMPTY, not with real values. publicationFigure owns these defaults and
% derives some of them from each other - the font size follows the column width
% and floors at 5 pt for a single column. Seeding 8 here made that branch
% unreachable from the only caller, so single-column figures printed at 8 pt
% with exactly the collision the derivation exists to prevent. Same rule the
% plot params follow: the placeholder names the default, the value stays unset,
% and the function that applies it stays the one place it is written down.
opts   = fillDefaults(defaults, struct('width', [], 'height', [], ...
                                       'dpi', [], 'fontSize', [], 'file', ''));
action = 'cancel';
meta   = exportParams();
entry  = struct('name', 'Figure', 'params', meta);

W = 470; H = 260;
fig = uifigure('Name', 'Publication figure', 'Resize', 'off', ...
               'Position', centreOn(anchor, W, H));
fig.CloseRequestFcn = @(src, ~) delete(src);

uilabel(fig, 'Position', [16 H-38 W-32 22], ...
        'Text', 'Publication figure', 'FontWeight', 'bold');

tbl = uitable(fig, 'Position', [16 78 W-32 H-126], ...
    'ColumnName', {'Setting', 'Value'}, 'ColumnWidth', {210, 'auto'}, ...
    'ColumnEditable', [false true], 'RowName', {});
tbl.CellEditCallback      = @onEdit;
tbl.CellSelectionCallback = @onSelect;

hint = uilabel(fig, 'Position', [16 46 W-32 26], 'Text', '', ...
    'FontSize', 11, 'FontColor', [0.35 0.38 0.43], 'WordWrap', 'on');

uibutton(fig, 'Text', 'Cancel', 'Position', [16 12 90 26], ...
    'ButtonPushedFcn', @(~,~) delete(fig));
uibutton(fig, 'Text', 'Open in MATLAB', 'Position', [W-236 12 120 26], ...
    'ButtonPushedFcn', @(~,~) finish('open'));
uibutton(fig, 'Text', 'Save as...', 'Position', [W-106 12 90 26], ...
    'ButtonPushedFcn', @(~,~) onSave());

refresh();
waitfor(fig);

    function refresh()
        % No pruning of empty fields first: buildParamTableData already renders
        % any empty value as the param's placeholder.
        tbl.Data = buildParamTableData(struct('name', 'Figure', ...
                                              'params', opts), entry);
        greyPlaceholderCells(tbl);
    end

    function onEdit(~, ev)
        r = ev.Indices(1);
        if r > numel(meta); return; end
        s = applyParamEdit(struct('name', 'Figure', 'params', opts), ...
                           1, r, ev.NewData, entry);
        opts = s.params;
        refresh();
    end

    function onSelect(~, ev)
        if isempty(ev.Indices); hint.Text = ''; return; end
        r = ev.Indices(1);
        if r <= numel(meta); hint.Text = meta(r).description; end
    end

    function onSave()
        [f, p] = uiputfile({'*.png', 'PNG image'; '*.pdf', 'PDF (vector)'; ...
                            '*.tiff', 'TIFF image'; '*.eps', 'EPS (vector)'}, ...
                           'Save figure', 'tep_figure.png');
        if isequal(f, 0); return; end
        opts.file = fullfile(p, f);
        finish('save');
    end

    function finish(what)
        action = what;
        delete(fig);
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function p = exportParams()
p = [ ...
    makeParam('width', 'Column width', 'mm', 'single | double | mm', ...
        ['Journal column width. "single" is 89 mm and "double" 183 mm, the ' ...
         'two widths most journals ask for; a number is taken as millimetres.'], ...
        'type', 'string', 'placeholder', '(double - 183 mm)'), ...
    makeParam('height', 'Height', 'mm', '', ...
        'Figure height. Left unset it follows the width, at 0.62 of it.', ...
        'type', 'scalar', 'placeholder', '(0.62 x width)'), ...
    makeParam('dpi', 'Resolution', 'dpi', '>= 300 for print', ...
        ['Export resolution. 600 dpi is the usual requirement for a figure ' ...
         'containing line art; screen resolution is 96 and will be rejected.'], ...
        'type', 'integer', 'placeholder', '(600)'), ...
    makeParam('fontSize', 'Font size', 'pt', '', ...
        ['Applied to every axes, so the composite prints at one size ' ...
         'throughout. Most journals set a floor between 5 and 7 pt at final ' ...
         'size.'], ...
        'type', 'scalar', 'placeholder', '(8)')];
end
