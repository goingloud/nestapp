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
%   The interval is computed on the DIFFERENCE, not carried over from the two
%   groups, because those are different quantities. In a paired design the
%   per-subject differences are taken first and the interval is their own SEM,
%   which is the quantity the contrast is actually about: two heavily
%   overlapping group bands can still have a difference that is nowhere near
%   zero, and two tight bands can have a difference that is. Reading a contrast
%   off a pair of overlapping bands is the single most common way to get this
%   wrong, so the difference gets its own panel and its own interval.
%
%   Unpaired groups use the standard two-sample standard error
%   sqrt(s1^2/n1 + s2^2/n2) with Welch degrees of freedom, so unequal group
%   sizes and unequal variances do not quietly narrow the band.
%
%   A shaded band that excludes zero is not a significance test and is not
%   labelled as one - the app reports estimates, not p-values. It is the
%   interval, and the reader draws their own conclusion.
%
%   See also: groupCurves, curveInterval, drawTEPOverlay

if nargin < 3; opts = struct(); end
if numel(res.groups) ~= 2
    error('nestapp:differenceNeedsTwoGroups', ...
          'A difference wave needs exactly two groups; got %d.', numel(res.groups));
end

if ~isfield(opts, 'xlim')   || isempty(opts.xlim);   opts.xlim   = [-50 300]; end
if ~isfield(opts, 'colors') || isempty(opts.colors); opts.colors = groupColors(1); end

A = res.groups(1);
B = res.groups(2);
[d, lo, hi, n, note] = differenceInterval(A.curves, B.curves, res.design);

time = res.time;
cla(ax, 'reset');
hold(ax, 'on');

fill(ax, [time, fliplr(time)], [lo, fliplr(hi)], opts.colors(1, :), ...
     'FaceAlpha', 0.20, 'LineStyle', 'none', 'HandleVisibility', 'off');
plot(ax, time, d, 'Color', opts.colors(1, :), 'LineWidth', 1.75, ...
     'DisplayName', sprintf('%s - %s (n=%d)', B.name, A.name, n));

yl = ylim(ax);
plot(ax, [0 0], yl, 'Color', [0 0 0 0.35], 'LineWidth', 0.75, 'HandleVisibility', 'off');
plot(ax, opts.xlim, [0 0], 'Color', [0 0 0 0.55], 'LineWidth', 0.9, 'HandleVisibility', 'off');
ylim(ax, yl);
hold(ax, 'off');

xlim(ax, opts.xlim);
xlabel(ax, 'Time (ms)');
ylabel(ax, 'Difference (\muV)');
title(ax, sprintf('%s minus %s  (%s)', B.name, A.name, note));
box(ax, 'off');
legend(ax, 'Location', 'northeast', 'Box', 'off');
end

% ── helpers ─────────────────────────────────────────────────────────────────

function [d, lo, hi, n, note] = differenceInterval(A, B, design)
% The difference and its own interval. Paired and unpaired are different
% estimators, not a presentation choice.
if strcmpi(design, 'paired')
    D    = B - A;                       % rows are the same subjects, in order
    n    = size(D, 1);
    d    = mean(D, 1, 'omitnan');
    sem  = std(D, 0, 1, 'omitnan') / sqrt(n);
    df   = n - 1;
    note = 'paired, 95% CI';
else
    n1 = size(A, 1); n2 = size(B, 1);
    d  = mean(B, 1, 'omitnan') - mean(A, 1, 'omitnan');
    v1 = var(A, 0, 1, 'omitnan') / n1;
    v2 = var(B, 0, 1, 'omitnan') / n2;
    sem = sqrt(v1 + v2);
    % Welch-Satterthwaite: unequal n and unequal variance must not be papered
    % over with a pooled df.
    df  = (v1 + v2).^2 ./ (v1.^2 / max(n1 - 1, 1) + v2.^2 / max(n2 - 1, 1));
    n    = min(n1, n2);
    note = 'unpaired, 95% CI';
end

if all(n < 2)
    lo = nan(size(d)); hi = lo;
    return
end
t  = tCritical(df, 0.05);
lo = d - t .* sem;
hi = d + t .* sem;
end
