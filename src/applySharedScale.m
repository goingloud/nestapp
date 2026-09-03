% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function applySharedScale(axList, clim)
% APPLYSHAREDSCALE  Put every map in a grid on one colour scale, after drawing.
%   APPLYSHAREDSCALE(axList, clim) applies the diverging colormap and clim to
%   every axes in axList.
%
%   It must run AFTER the whole grid is drawn, not per map inside the loop.
%   Observed: drawing a map into a sibling axes resets the colormap of the ones
%   already drawn, so the first map came out in topoplot's own colours and the
%   last came out diverging. Two maps of the same data then look like two
%   different results - the precise misreading a shared scale exists to
%   prevent, and one that reads as a finding rather than a rendering fault.
%
%   The invariant is "all maps share one scale", so it is enforced here, once,
%   at the point the loop can no longer disturb it. Both grid drawers had their
%   own copy of this loop AND of the reasoning behind it; a MATLAB release that
%   changes the underlying behaviour should not need finding twice.
%
%   See also: drawGroupTopo, drawTEPTopo, drawScalpTopo, divergingColormap

cmap = divergingColormap();
for k = 1:numel(axList)
    if ~isgraphics(axList(k)); continue; end
    colormap(axList(k), cmap);
    axList(k).CLim = clim;
end
end
