% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function info = drawTEPTopo(parent, res, opts)
% DRAWTEPTOPO  Curve panel with scalp maps above it, one column per window.
%   info = DRAWTEPTOPO(parent, res, opts) draws the composite figure: the group
%   waveforms across the bottom, and a grid of scalp maps above - one COLUMN
%   per window of interest, one ROW per group.
%
%   info returns .clim (the shared colour limits) and .axes (every axes made).
%
%   Rows are groups because that is what makes it a comparison. The classic
%   timtopo shows one dataset's maps in a strip; with n groups the same strip
%   per group, aligned on the same columns and the same colour scale, is what
%   lets a reader see that a component differs between conditions rather than
%   just that it exists. With one group it degenerates to the classic figure.
%
%   The maps AVERAGE OVER EACH WINDOW rather than sampling a single latency, so
%   a map and the number in the measures table describe the same interval by
%   construction. Change N45 to 40-55 ms and both move together. Sampling at a
%   window's midpoint instead would put a map beside a mean it does not match.
%
%   One colour scale across every map, every group and every window. Per-map
%   limits would make a 1 uV map and a 10 uV map look identical, which is the
%   one thing a grid of maps must not do.
%
%   The curve panel shades each window, so the reader can see which slice of the
%   waveform each column of maps came from - the linkage the dashed leader lines
%   in AARATEP's c_EEG_plotTimtopo draw. Shading is cheaper and does not break
%   when windows overlap.
%
%   opts:
%     .windows   window structs; omit for defaultTEPComponentDefs. Supplying an
%                EMPTY set means no windows, and draws the curve alone
%     .mode      'TEP' | 'GMFP' | 'LMFP' for the curve's axis label
%     .xlim      curve time limits, default [-50 300]
%     .colors    group colours, default groupColors(nGroups)
%     .showBands shade the windows on the curve, default true
%     .axesFcn   @(parent, position) -> axes. Default makes uiaxes, which is
%                what an in-app panel needs; a publication figure passes a
%                classic-axes maker. The alternative is sniffing the parent's
%                type, which is unreliable - a uifigure and a figure are both
%                matlab.ui.Figure.
%
%   See also: drawTEPOverlay, drawScalpTopo, drawGroupTopo, groupCurves

if nargin < 3; opts = struct(); end
nG = numel(res.groups);
% Whether .windows was SUPPLIED is asked before the defaults are merged in,
% because "not supplied" and "supplied empty" mean opposite things: no windows
% named means fall back to the standard components, but a caller who emptied
% its windows table has said there are none, and reviving the defaults there
% would show six windows the user just deleted.
supplied = isfield(opts, 'windows');
opts = fillDefaults(opts, struct( ...
    'windows', [], 'mode', 'TEP', 'xlim', [-50 300], ...
    'colors', groupColors(max(nG, 1)), 'showBands', true, ...
    'axesFcn', @(p, pos) uiaxes(p, 'Position', pos)));
if ~supplied; opts.windows = defaultTEPComponentDefs(); end

info = struct('clim', [0 0], 'axes', gobjects(0));
if nG == 0 || isempty(res.time); return; end

w  = opts.windows;
nW = numel(w);
if nW == 0
    % No windows means no maps; the curve alone is still worth drawing.
    ax = opts.axesFcn(parent, curveRect(parent, 0));
    drawTEPOverlay(ax, res, opts);
    info.axes = ax;
    return
end

% ── window means per group, all of them, before anything is drawn ────────
% The shared scale can only be computed once every value is known.
vals = cell(nG, nW);
for g = 1:nG
    for k = 1:nW
        sel = res.time >= min(w(k).winStart, w(k).winEnd) & ...
              res.time <= max(w(k).winStart, w(k).winEnd);
        if ~any(sel)
            vals{g, k} = zeros(numel(res.channelLabels), 1);
        else
            vals{g, k} = mean(res.groups(g).chanMeans(:, sel), 2, 'omitnan');
        end
    end
end
m = max(cellfun(@(v) max(abs(v)), vals(:)));
if ~isfinite(m) || m == 0; m = 1; end
info.clim = [-m m];

% ── geometry ────────────────────────────────────────────────────────────
% Maps are SQUARE and sized by whichever budget binds - the width available per
% column, or the height available per row. A head is round, so a cell wider than
% it is tall just adds dead space between columns while the heads stay small;
% sizing off the smaller dimension and centring the block keeps the heads as
% large as the panel allows at any window count and any window size.
P       = parentRect(parent);
PAD     = 10;
TITLE_H = 18;                      % the column titles, above the first row
LABEL_W = 58;                      % room for the row (group) names
CBAR_W  = 62;                      % one shared bar, at the right of the grid
availW  = P(3) - 2*PAD - LABEL_W - CBAR_W;
availH  = P(4) * 0.55 - TITLE_H - PAD;
side    = max(min(availW / nW, availH / nG), 40);
gridW   = side * nW;
gridH   = side * nG + TITLE_H + PAD;
x0      = PAD + LABEL_W + max((availW - gridW) / 2, 0);
yTop    = P(4) - PAD - TITLE_H;

axesMade = gobjects(0);

% ── the map grid ────────────────────────────────────────────────────────
for g = 1:nG
    for k = 1:nW
        x = x0 + (k - 1) * side;
        y = yTop - g * side;
        ax = opts.axesFcn(parent, [x, y, side - 6, side - 6]);
        drawScalpTopo(ax, vals{g, k}, res.chanlocs, ...
                      struct('clim', info.clim, 'colorbar', false));
        % Only the top row is titled: one label per column, not nG copies.
        if g == 1
            title(ax, sprintf('%s  %g-%g', w(k).name, w(k).winStart, w(k).winEnd), ...
                  'FontSize', 9);
        else
            title(ax, '');
        end
        axesMade(end + 1) = ax; %#ok<AGROW>
    end
    % Row label, in the group's own colour so it ties to the curve below.
    % Placed against the grid rather than the panel edge: a centred grid can sit
    % well right of the edge, and a label stranded there reads as unattached.
    yMid = yTop - g * side + side / 2 - 9;
    uilabel(parent, 'Text', res.groups(g).name, ...
        'Position', [x0 - LABEL_W, yMid, LABEL_W - 6, 18], ...
        'HorizontalAlignment', 'right', 'FontWeight', 'bold', ...
        'FontColor', opts.colors(min(g, size(opts.colors, 1)), :));
end

% One bar for the whole grid, since every map shares the scale.
cbAx = sharedColorbar(parent, opts.axesFcn, ...
    [x0 + gridW + 10, yTop - nG * side + 6, 12, side * nG - 16], info.clim);
axesMade(end + 1) = cbAx;

% ── the curve panel ─────────────────────────────────────────────────────
cAx = opts.axesFcn(parent, curveRect(parent, gridH));
drawTEPOverlay(cAx, res, opts);
if opts.showBands
    shadeWindows(cAx, w);
end
axesMade(end + 1) = cAx;
info.axes = axesMade;
end

% ── helpers ─────────────────────────────────────────────────────────────────

function r = parentRect(parent)
p = parent.Position;
r = [0 0 p(3) p(4)];
end

function r = curveRect(parent, gridH)
P   = parentRect(parent);
PAD = 10;
r   = [PAD + 45, PAD + 34, P(3) - 2*PAD - 55, max(P(4) - gridH - PAD - 44, 60)];
end

function shadeWindows(ax, w)
% Behind the curves: patches drawn after the lines would hide them, and the
% bands are context, not data.
%
% ALTERNATE windows are shaded, not all of them. The standard set is
% contiguous - 10-20, 20-40, 40-55, 50-70, 70-150, 150-240 - so shading every
% one produced a single grey block from 10 to 240 ms with no visible
% boundaries, which says less than no shading at all. Alternating makes each
% window's extent readable, and a boundary line at every edge keeps the
% unshaded ones locatable.
yl = ylim(ax);
hold(ax, 'on');
for k = 1:numel(w)
    t1 = min(w(k).winStart, w(k).winEnd);
    t2 = max(w(k).winStart, w(k).winEnd);
    if mod(k, 2) == 1
        p = patch(ax, [t1 t2 t2 t1], [yl(1) yl(1) yl(2) yl(2)], [0.45 0.5 0.58], ...
            'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        uistack(p, 'bottom');
    end
    plot(ax, [t1 t1], yl, ':', 'Color', [0.6 0.63 0.68], ...
         'LineWidth', 0.5, 'HandleVisibility', 'off');
    plot(ax, [t2 t2], yl, ':', 'Color', [0.6 0.63 0.68], ...
         'LineWidth', 0.5, 'HandleVisibility', 'off');
    text(ax, (t1 + t2) / 2, yl(2), w(k).name, 'FontSize', 8, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'Color', [0.35 0.38 0.43]);
end
ylim(ax, yl);
hold(ax, 'off');
end
