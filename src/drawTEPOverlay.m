% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function drawTEPOverlay(ax, res, opts)
% DRAWTEPOVERLAY  One curve per group with its confidence band.
%   DRAWTEPOVERLAY(ax, res, opts) draws the output of groupCurves into ax: a
%   shaded interval and a mean line per group, with a legend naming each group
%   and its subject count.
%
%   ax may be a classic axes or a uiaxes - the caller mints it, following the
%   convention drawScalpTopo already set, so this function needs to know
%   nothing about where it is being drawn.
%
%   opts:
%     .mode      'TEP' | 'GMFP' | 'LMFP', for the axis label (default from res)
%     .xlim      time limits, default [-50 300] as the app has always used
%     .colors    n-by-3, default groupColors(nGroups)
%     .showBand  draw the interval, default true
%     .legend    draw the legend, default true
%
%   The band is the confidence interval curveInterval computed, not a decorative
%   spread. The app previously shaded mean +/- SEM/2 with no label, which is not
%   an interval anyone can interpret; the legend and label here state what is
%   being shown and over how many subjects, because a band whose meaning is not
%   stated is worse than no band.
%
%   Bands are drawn before lines and with transparency, so an overlap reads as
%   overlap rather than as whichever group happened to be drawn last.
%
%   See also: groupCurves, curveInterval, groupColors, drawDifferenceWave

if nargin < 3; opts = struct(); end
opts = withDefaults(opts, res);

cla(ax, 'reset');
if isempty(res.groups); return; end

nG   = numel(res.groups);
time = res.time;
hold(ax, 'on');

% Bands first, so every mean line sits above every band.
if opts.showBand
    for g = 1:nG
        e = res.est(g);
        if isempty(e.lo) || all(isnan(e.lo)); continue; end
        xf = [time, fliplr(time)];
        yf = [e.lo,  fliplr(e.hi)];
        fill(ax, xf, yf, opts.colors(g, :), ...
             'FaceAlpha', 0.20, 'LineStyle', 'none', 'HandleVisibility', 'off');
    end
end

labels = cell(1, nG);
for g = 1:nG
    e = res.est(g);
    labels{g} = sprintf('%s (n=%d)', res.groups(g).name, e.n);
    plot(ax, time, e.mean, 'Color', opts.colors(g, :), ...
         'LineWidth', 1.75, 'DisplayName', labels{g});
end

% A zero line and a stimulus marker: without them the reader has to infer where
% the pulse was, and every latency on the axis is relative to it.
yl = ylim(ax);
plot(ax, [0 0], yl, 'Color', [0 0 0 0.35], 'LineWidth', 0.75, ...
     'HandleVisibility', 'off');
plot(ax, opts.xlim, [0 0], 'Color', [0 0 0 0.25], 'LineWidth', 0.75, ...
     'HandleVisibility', 'off');
ylim(ax, yl);
hold(ax, 'off');

xlim(ax, opts.xlim);
xlabel(ax, 'Time (ms)');
ylabel(ax, yLabelFor(opts.mode));
title(ax,  titleFor(opts.mode));
grid(ax, 'off');
box(ax, 'off');

if opts.legend && nG >= 1
    legend(ax, 'Location', 'northeast', 'Box', 'off');
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function opts = withDefaults(opts, res)
nG   = numel(res.groups);
opts = fillDefaults(opts, struct('mode', 'TEP', 'xlim', [-50 300], ...
    'colors', groupColors(nG), 'showBand', true, 'legend', true));
% A caller may pass a palette sized for a different group count.
if size(opts.colors, 1) < nG
    opts.colors = groupColors(nG);
end
end

function s = yLabelFor(mode)
switch upper(char(mode))
    case 'GMFP', s = 'GMFP (\muV)';
    case 'LMFP', s = 'LMFP (\muV)';
    otherwise,   s = 'Amplitude (\muV)';
end
end

function s = titleFor(mode)
switch upper(char(mode))
    case 'GMFP', s = 'Global Mean Field Power';
    case 'LMFP', s = 'Local Mean Field Power';
    otherwise,   s = 'TMS-Evoked Potential';
end
end
