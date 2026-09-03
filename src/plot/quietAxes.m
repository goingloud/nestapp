% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function quietAxes(ax)
% QUIETAXES  Strip the hover toolbar and default interactions from an axes.
%   QUIETAXES(ax) is for axes that are pictures rather than instruments - a
%   scalp map or a colour bar, where there is nothing to zoom, pan or data-tip.
%
%   It also matters for export: exportapp captures the toolbar, so a saved
%   figure would carry a row of grey icons over the corner of a head.
%
%   Setting Interactions and Toolbar directly rather than calling
%   disableDefaultInteractivity: the latter costs about 1.4 ms per axes, which
%   at twelve maps a repaint is most of a frame, and reading ax.Toolbar
%   CONSTRUCTS the toolbar object just so it can be hidden. Wrapped in try
%   because neither property exists on every axes flavour or release.
%
%   See also: drawScalpTopo, sharedColorbar

try
    ax.Interactions = [];
catch
end
try
    ax.Toolbar.Visible = 'off';
catch
end
end
