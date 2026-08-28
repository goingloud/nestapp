% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function clim = drawGroupTopo(axList, res, opts)
% DRAWGROUPTOPO  One scalp map per group, on a shared microvolt scale.
%   clim = DRAWGROUPTOPO(axList, res, opts) draws the window-averaged scalp
%   distribution for each group into the corresponding axes of axList, and
%   returns the symmetric colour limits used.
%
%   axList must have at least one axes per group; the caller mints them, so
%   this works the same into a uifigure panel and into a publication figure.
%
%   opts:
%     .window   [t1 t2] in ms to average over (default the whole epoch)
%     .clim     force colour limits; default symmetric across ALL groups
%     .titles   cellstr overriding the per-map titles
%     .colorbar false when the caller draws its own shared bar (see
%               sharedColorbar); default true, putting one on the last map
%
%   The shared scale is the point. Each map drawn with its own limits would
%   make two groups look alike whatever their amplitudes - a 1 uV map and a
%   10 uV map both render as a full-range red and blue dipole. Colour limits
%   are computed once across every group and applied to all of them, so the
%   maps are comparable by eye, which is the only reason to put them side by
%   side. They are symmetric about zero for the same reason drawScalpTopo makes
%   them symmetric: with a diverging map, an off-centre zero puts the neutral
%   colour somewhere other than no-deflection and misreads the polarity.
%
%   See also: drawScalpTopo, groupCurves, divergingColormap

if nargin < 3; opts = struct(); end
nG = numel(res.groups);
if nG == 0; clim = [0 0]; return; end
if numel(axList) < nG
    error('nestapp:tooFewAxes', ...
          'drawGroupTopo needs one axes per group: %d groups, %d axes.', ...
          nG, numel(axList));
end

if ~isfield(opts, 'window') || isempty(opts.window)
    opts.window = [res.time(1) res.time(end)];
end

% Window average per group, all computed before anything is drawn so the shared
% scale can be derived from the complete set.
vals = cell(1, nG);
sel  = res.time >= opts.window(1) & res.time <= opts.window(2);
if ~any(sel)
    error('nestapp:windowOutsideEpoch', ...
        'The window %g-%g ms lies outside the epoch (%g to %g ms).', ...
        opts.window(1), opts.window(2), res.time(1), res.time(end));
end
for g = 1:nG
    vals{g} = mean(res.groups(g).chanMeans(:, sel), 2, 'omitnan');
end

if isfield(opts, 'clim') && ~isempty(opts.clim)
    clim = opts.clim;
else
    m    = max(cellfun(@(v) max(abs(v)), vals));
    if ~isfinite(m) || m == 0; m = 1; end
    clim = [-m m];
end

% No bars on the maps. A bar shrinks the axes it attaches to, so putting one on
% the last map alone left that group's head smaller than its siblings - in a
% figure whose whole purpose is that the maps are comparable by eye. The caller
% mints the axes, so the caller reserves a strip and hangs one sharedColorbar
% there; opts.colorbar exists for a caller that has nowhere to put one.
showBar = ~isfield(opts, 'colorbar') || opts.colorbar;
for g = 1:nG
    drawScalpTopo(axList(g), vals{g}, res.chanlocs, ...
                  struct('clim', clim, 'colorbar', showBar && g == nG));
    if isfield(opts, 'titles') && numel(opts.titles) >= g
        title(axList(g), opts.titles{g});
    else
        title(axList(g), sprintf('%s  (%g-%g ms)', res.groups(g).name, ...
                                 opts.window(1), opts.window(2)));
    end
end

applySharedScale(axList(1:nG), clim);
end
