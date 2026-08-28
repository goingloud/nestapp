
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function cLim = drawScalpTopo(ax, values, chanlocs, opts)
% DRAWSCALPTOPO  Render an EEGLAB scalp topography into any axes, with a scale.
%   cLim = DRAWSCALPTOPO(ax, values, chanlocs)
%   cLim = DRAWSCALPTOPO(ax, values, chanlocs, opts)
%
%   ax       - destination axes. A classic axes is drawn into directly; a
%              uiaxes goes through a hidden figure (topoplot calls gca/clim/
%              axis, which a uiaxes does not support) and the result is copied
%              back.
%   values   - one scalar per channel (the time-window-averaged voltage, uV).
%   chanlocs - matching EEGLAB chanlocs struct array.
%   opts     - optional struct:
%                .clim  force these colour limits instead of deriving them
%                       from this map alone.
%
%   Returns the symmetric colour limits actually applied, in uV.
%
%   opts.clim exists for comparing maps. Limits derived per map make any two
%   maps look alike whatever their amplitudes - a 1 uV map and a 10 uV map both
%   render as a full-range dipole - so a caller drawing one map per group
%   computes the limits once across all of them and passes them in. Without an
%   override the behaviour is unchanged: symmetric absmax from this map.
%
%   The colour scale is plain linear microvolts: topoplot's default maplimits
%   is 'absmax', so the limits are symmetric about zero and recomputed for
%   every timepoint. We re-read them off the drawing axes and re-apply them to
%   the destination - copying only the children drops them, leaving the
%   destination silently autoscaled to the copied surface instead of the
%   limits topoplot chose. With a symmetric CLim and a diverging map, white is
%   exactly 0 uV and the colorbar reads directly.
%
%   See also: divergingColormap, popOutAxes, topoplot

INTRAD      = 0.55;   % EEGLAB default interpolation radius
NUM_CONTOUR = 5;
CB_LABEL    = 'uV';

topoArgs = {'electrodes', 'off', 'numcontour', NUM_CONTOUR, ...
            'intsquare', 'on', 'style', 'map', 'conv', 'on', ...
            'intrad', INTRAD};

% topoplot draws into gca, so it mutates the current figure/axes either way.
% Callers should not have to think about that, so restore it here - and note
% get(groot,'CurrentFigure') rather than gcf, which would CREATE a figure when
% none is open.
prevFig = get(groot, 'CurrentFigure');
restore = onCleanup(@() restoreCurrentFigure(prevFig));

if isa(ax, 'matlab.ui.control.UIAxes')
    cLim = drawViaHiddenFigure(ax, values, chanlocs, topoArgs);
else
    cla(ax, 'reset');
    axes(ax);
    topoplot(values, chanlocs, topoArgs{:});
    cLim = symmetricLimits(ax);
end

% A caller comparing several maps supplies one scale for all of them; it wins
% over the per-map limits derived above.
if nargin >= 4 && isstruct(opts) && isfield(opts, 'clim') && ~isempty(opts.clim)
    cLim = opts.clim(:)';
end

ax.CLim = cLim;
colormap(ax, divergingColormap());
cb = colorbar(ax);
cb.Label.String = CB_LABEL;
end

% ── local helpers ─────────────────────────────────────────────────────────────

function cLim = drawViaHiddenFigure(uiAx, values, chanlocs, topoArgs)
% topoplot needs a classic axes (it calls axes/gca/clim/axis internally), so
% draw into an offscreen one and copy the graphics across.
hiddenFig = figure('Visible', 'off');
closeFig  = onCleanup(@() delete(hiddenFig));

% A blank axes, NOT a clone of the destination: topoplot does not clear what
% it draws into, so cloning a uiaxes that already holds a map would copy the
% previous render back alongside the new one, growing the child list on every
% redraw. Only allchild is copied back, so nothing about the source's own
% properties is needed here.
tmpAx = axes(hiddenFig);
topoplot(values, chanlocs, topoArgs{:});
cLim = symmetricLimits(tmpAx);

cla(uiAx, 'reset');
copyobj(allchild(tmpAx), uiAx);
axis(uiAx, 'equal');
axis(uiAx, 'off');
end

function restoreCurrentFigure(prevFig)
if ~isempty(prevFig) && isvalid(prevFig)
    set(groot, 'CurrentFigure', prevFig);
end
end

function cLim = symmetricLimits(ax)
% topoplot's 'absmax' limits are already symmetric bar rounding; force exact
% symmetry so the neutral midpoint of the colormap lands on 0 uV. Falls back
% to a unit range for an all-zero (or degenerate) map.
m = max(abs(ax.CLim));
if ~isfinite(m) || m <= 0
    m = 1;
end
cLim = [-m m];
end
