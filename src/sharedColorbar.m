% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function ax = sharedColorbar(parent, axesFcn, rect, clim, label)
% SHAREDCOLORBAR  One colour bar for a grid of maps drawn on one scale.
%
%   ax = SHAREDCOLORBAR(parent, axesFcn, rect, clim, label) makes an invisible
%   axes at rect carrying the diverging colormap and clim, and puts a colour bar
%   on it. Returns the axes so the caller can delete it.
%
%   A grid of maps on a shared scale needs exactly one bar. Letting each map
%   carry its own repeats the same information N times and takes the space out
%   of the maps - with two groups and six windows that is twelve bars for one
%   fact. The bar is hung on a dedicated invisible axes rather than on one of
%   the maps so it can sit outside the grid without distorting a head.
%
%   See also: drawScalpTopo, drawTEPTopo, drawGroupTopo, divergingColormap

if nargin < 5 || isempty(label); label = 'uV'; end

ax = axesFcn(parent, rect);
axis(ax, 'off');
colormap(ax, divergingColormap());
ax.CLim = clim;
cb = colorbar(ax);
cb.Label.String = label;
try
    ax.Toolbar.Visible = 'off';
    disableDefaultInteractivity(ax);
catch
end
end
