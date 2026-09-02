% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function renderQcImages(parent, figures, opts)
% RENDERQCIMAGES  Show one file's QC checkpoint images inside a panel.
%   RENDERQCIMAGES(parent, figures)
%   RENDERQCIMAGES(parent, figures, opts)
%
%   figures  cellstr of PNG paths, as recorded on report.quality.figures
%   opts     .selected  1-based index to show first (default 1)
%            .onOpen    @(path) called when the user asks to open the folder
%
%   The images already exist: renderQualityFigure writes one per Quality Gate
%   checkpoint - channel x trial attribute heatmap, IC topography grid,
%   butterfly, per-channel PSD - and processOneFile records the paths. Until
%   now buildReportText printed only the containing FOLDER as text and the only
%   code that rendered them was the PDF exporter, so seeing an image the app had
%   already made meant exporting a PDF and opening it outside the app.
%
%   A dropdown rather than a grid of thumbnails: a run with several Quality
%   Gates produces several 1600x1200 figures, and shrinking four dense panels
%   into a thumbnail makes all of them unreadable while showing one at panel
%   size makes it useful.
%
%   Clears the parent first, so re-rendering after a resize or a selection
%   change replaces the contents rather than stacking a second copy on top.
%
%   See also: renderQualityFigure, renderDashboardPanel, buildReportText

if nargin < 3; opts = struct(); end
opts = fillDefaults(opts, struct('selected', 1, 'onOpen', []));

delete(parent.Children);

figures = figures(:)';
if isempty(figures)
    uilabel(parent, 'Position', [12 12 parent.Position(3)-24 parent.Position(4)-24], ...
        'VerticalAlignment', 'top', 'FontColor', [0.4 0.4 0.4], ...
        'WordWrap', 'on', ...
        'Text', ['No QC images for this file. They are written when ' ...
                 '"Auto quality report" is on in Settings and the pipeline ' ...
                 'includes a Quality Gate step.']);
    return
end

W = parent.Position(3);
H = parent.Position(4);
ROW_H = 26;

sel = min(max(round(opts.selected), 1), numel(figures));

labels = cell(1, numel(figures));
for i = 1:numel(figures)
    [~, base, ext] = fileparts(figures{i});
    labels{i} = [base ext];
end

img = uiimage(parent, 'Position', [6 6 W-12 H-ROW_H-14], ...
              'ScaleMethod', 'fit');

dd = uidropdown(parent, 'Position', [6 H-ROW_H+2 W-120 22], ...
                'Items', labels, 'ItemsData', 1:numel(figures), 'Value', sel, ...
                'Tooltip', 'Which checkpoint to show', ...
                'ValueChangedFcn', @(src, ~) show(src.Value));

if ~isempty(opts.onOpen)
    uibutton(parent, 'Text', 'Open folder', ...
        'Position', [W-108 H-ROW_H+2 102 22], ...
        'Tooltip', 'Show these images in the file browser', ...
        'ButtonPushedFcn', @(~, ~) opts.onOpen(fileparts(figures{dd.Value})));
end

show(sel);

    function show(i)
        p = figures{i};
        if isfile(p)
            img.ImageSource = p;
            img.Tooltip     = p;
        else
            % A report loaded from disk can outlive the images it names -
            % say which file is missing rather than showing a blank panel.
            img.ImageSource = '';
            img.Tooltip     = sprintf('Missing: %s', p);
        end
    end
end
