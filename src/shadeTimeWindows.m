% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function shadeTimeWindows(ax, w)
% SHADETIMEWINDOWS  Mark the windows of interest on a time-domain axes.
%   SHADETIMEWINDOWS(ax, w) shades ALTERNATE windows behind whatever is already
%   drawn, marks every boundary with a dotted line, and labels each window with
%   its name along the top.
%
%   Alternate, not all. The standard set is contiguous - 10-20, 20-40, 40-55,
%   50-70, 70-150, 150-240 - so shading every one produced a single grey block
%   from 10 to 240 ms with no visible boundaries, which says less than no
%   shading at all. Alternating makes each window's extent readable, and a
%   boundary at every edge keeps the unshaded ones locatable.
%
%   Everything is drawn behind the data and with HandleVisibility off: the bands
%   are context, so they must not cover a curve or claim a legend entry. The y
%   limits are read first and restored after, since patches spanning the current
%   limits would otherwise re-trigger autoscaling and creep the axes outward.
%
%   This is the linkage the dashed leader lines in AARATEP's c_EEG_plotTimtopo
%   draw between a map and the slice of waveform it came from. Shading is
%   cheaper, survives overlapping windows, and reads on a plot with no maps at
%   all - which is why the waveform plots use it too.
%
%   See also: drawTEPTopo, drawTEPOverlay, drawDifferenceWave

if isempty(w); return; end

t1 = arrayfun(@(x) min(x.winStart, x.winEnd), w);
t2 = arrayfun(@(x) max(x.winStart, x.winEnd), w);
shaded = 1:2:numel(w);

yl = ylim(ax);
hold(ax, 'on');

% One patch for every shaded band and one line for every boundary, rather than
% a patch/uistack/plot per window. Six windows meant thirty high-level graphics
% calls - each plot() re-parsing its arguments, each uistack reordering the
% whole child list - which measured about 78 ms on every repaint of every
% waveform plot. Multi-face patches and a NaN-separated line do the same
% drawing in three.
if ~isempty(shaded)
    X = [t1(shaded); t2(shaded); t2(shaded); t1(shaded)];
    Y = repmat([yl(1); yl(1); yl(2); yl(2)], 1, numel(shaded));
    p = patch(ax, 'XData', X, 'YData', Y, 'FaceColor', [0.45 0.5 0.58], ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    uistack(p, 'bottom');
end

% Every window edge as one NaN-separated polyline: each boundary contributes
% (e, ymin) -> (e, ymax) -> NaN, so one line object draws all 2n of them.
ev = reshape([t1(:)'; t2(:)'], 1, []);
bx = reshape([ev; ev; nan(1, numel(ev))], 1, []);
by = repmat([yl(1); yl(2); NaN], 1, numel(ev));
line(ax, bx, by(:)', 'LineStyle', ':', 'Color', [0.6 0.63 0.68], ...
     'LineWidth', 0.5, 'HandleVisibility', 'off');

text(ax, (t1 + t2) / 2, repmat(yl(2), 1, numel(w)), {w.name}, 'FontSize', 8, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
    'Color', [0.35 0.38 0.43]);

ylim(ax, yl);
hold(ax, 'off');
end
