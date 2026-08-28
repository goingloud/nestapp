% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function drawDifferenceWave(ax, res, opts)
% DRAWDIFFERENCEWAVE  Group 2 minus group 1, with an interval on the difference.
%   DRAWDIFFERENCEWAVE(ax, res, opts) draws the contrast between exactly two
%   groups from a groupCurves result.
%
%   opts:
%     .colors  n-by-3 (only the difference colour is used; default near-black)
%     .xlim    time limits, default [-50 300]
%
%   The estimator lives in differenceInterval, not here: the window-bars view
%   and the exported measures need the same numbers, and a statistic computed
%   inside a plot function gets reimplemented the moment a second view wants
%   it. This function only draws what that returns.
%
%   A shaded band that excludes zero is not a significance test and is not
%   labelled as one - the app reports estimates, not p-values. It is the
%   interval, and the reader draws their own conclusion.
%
%   See also: differenceInterval, groupCurves, drawTEPOverlay

if nargin < 3; opts = struct(); end
if numel(res.groups) ~= 2
    error('nestapp:differenceNeedsTwoGroups', ...
          'A difference wave needs exactly two groups; got %d.', numel(res.groups));
end

if ~isfield(opts, 'xlim')   || isempty(opts.xlim);   opts.xlim   = [-50 300]; end
if ~isfield(opts, 'colors') || isempty(opts.colors); opts.colors = groupColors(1); end

A   = res.groups(1);
B   = res.groups(2);
est = differenceInterval(A.curves, B.curves, res.design);
d   = est.mean;
lo  = est.lo;
hi  = est.hi;

time = res.time;
cla(ax, 'reset');
hold(ax, 'on');

fill(ax, [time, fliplr(time)], [lo, fliplr(hi)], opts.colors(1, :), ...
     'FaceAlpha', 0.20, 'LineStyle', 'none', 'HandleVisibility', 'off');
plot(ax, time, d, 'Color', opts.colors(1, :), 'LineWidth', 1.75, ...
     'DisplayName', sprintf('%s - %s (n=%d)', B.name, A.name, est.n));

yl = ylim(ax);
plot(ax, [0 0], yl, 'Color', [0 0 0 0.35], 'LineWidth', 0.75, 'HandleVisibility', 'off');
plot(ax, opts.xlim, [0 0], 'Color', [0 0 0 0.55], 'LineWidth', 0.9, 'HandleVisibility', 'off');
ylim(ax, yl);
hold(ax, 'off');

xlim(ax, opts.xlim);
xlabel(ax, 'Time (ms)');
ylabel(ax, 'Difference (\muV)');
title(ax, sprintf('%s minus %s  (%s)', B.name, A.name, est.note));
box(ax, 'off');
legend(ax, 'Location', 'northeast', 'Box', 'off');
end
