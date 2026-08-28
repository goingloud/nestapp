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
%     .window  [t1 t2] in ms to average over (default the whole epoch)
%     .clim    force colour limits; default symmetric across ALL groups
%     .titles  cellstr overriding the per-map titles
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

for g = 1:nG
    drawScalpTopo(axList(g), vals{g}, res.chanlocs, struct('clim', clim));
    if isfield(opts, 'titles') && numel(opts.titles) >= g
        title(axList(g), opts.titles{g});
    else
        title(axList(g), sprintf('%s  (%g-%g ms)', res.groups(g).name, ...
                                 opts.window(1), opts.window(2)));
    end
end

% Re-assert the scale on every axes, after all of them are drawn.
% Observed: drawing the second map into a sibling axes resets the colormap of
% the ones already drawn - the first map came out in topoplot's own colours
% while the last came out diverging, which is exactly the misreading the shared
% scale exists to prevent, and it looks like a data difference rather than a
% rendering artefact. Setting it per map inside the loop is therefore not
% enough; the invariant is "all maps share one scale", so it is enforced here,
% once the loop can no longer disturb it.
cmap = divergingColormap();
for g = 1:nG
    colormap(axList(g), cmap);
    axList(g).CLim = clim;
end
end
