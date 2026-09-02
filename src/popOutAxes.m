
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function fig = popOutAxes(srcAx, opts)
% POPOUTAXES  Copy a uiaxes into a real, fully editable MATLAB figure.
%   fig = POPOUTAXES(srcAx)
%   fig = POPOUTAXES(srcAx, opts)
%
%   The app draws into uiaxes inside a uifigure, where the plot editor, the
%   Property Inspector and Export Setup are unavailable. This clones the drawn
%   content into a classic figure + axes, which supports all of them - so a
%   user can retitle, rescale, recolour and save the plot by hand, and
%   File > Save As gives a .fig that reopens as a plot rather than as the whole
%   app window.
%
%   srcAx - source axes (uiaxes or classic axes) to copy.
%   opts  - optional struct:
%     .name    figure Name (default: 'nestapp figure')
%     .visible figure visibility (default 'on'; the .fig export path passes
%              'off' so the figure never flashes on screen).
%
%   Returns the new figure handle.
%
%   Scalp maps do not come through here - drawScalpTopo redraws them into a
%   fresh figure at full resolution instead of copying the in-app rendering.
%
%   See also: drawScalpTopo, divergingColormap

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'name'),    opts.name    = 'nestapp figure'; end
if ~isfield(opts, 'visible'), opts.visible = 'on';             end

if ~(isscalar(srcAx) && isgraphics(srcAx))
    error('nestapp:popOutAxes:badAxes', 'srcAx must be a valid axes handle.');
end

fig = figure('Name', opts.name, 'NumberTitle', 'off', 'Color', 'w', ...
             'Visible', opts.visible);
ax  = axes(fig);

% Content first, then the axes-level state, so nothing we set is overwritten
% by an autoscale triggered while the children are added.
copyobj(allchild(srcAx), ax);
copyAxesState(srcAx, ax);
copyAxesLabels(srcAx, ax);

addLegendIfNamed(ax);
end

% ── local helpers ─────────────────────────────────────────────────────────────

function copyAxesState(srcAx, ax)
% Carry over the appearance properties a uiaxes and a classic axes share.
% CLim matters most: for a topography it is the voltage scale itself, and it
% is not implied by the copied children.
props = {'XLim', 'YLim', 'ZLim', 'CLim', 'XDir', 'YDir', ...
         'XScale', 'YScale', 'TickDir', 'Box', 'View', ...
         'DataAspectRatio', 'PlotBoxAspectRatio', 'Colormap'};
for k = 1:numel(props)
    p = props{k};
    if isprop(srcAx, p) && isprop(ax, p)
        try
            ax.(p) = srcAx.(p);
        catch
            % A property that will not take (e.g. a mode-locked aspect ratio)
            % is cosmetic here - the plot is still correct without it.
        end
    end
end
end

function copyAxesLabels(srcAx, ax)
% Title / axis labels are Text objects, so copy the text and interpreter
% rather than assigning the handles (which belong to the source axes).
pairs = {'Title', 'XLabel', 'YLabel', 'ZLabel'};
for k = 1:numel(pairs)
    p = pairs{k};
    if ~(isprop(srcAx, p) && isprop(ax, p)), continue; end
    src = srcAx.(p);
    dst = ax.(p);
    if isempty(src) || ~isvalid(src), continue; end
    dst.String      = src.String;
    dst.Interpreter = src.Interpreter;
end
end

function addLegendIfNamed(ax)
% Rebuild the legend only when something was actually named. A caller names the
% mean line and hides the SEM ribbon, so an unconditional legend('show') would
% invent entries such as 'data1' for anything left unnamed.
kids = findobj(ax, '-property', 'DisplayName');
for k = 1:numel(kids)
    if ~isempty(kids(k).DisplayName)
        legend(ax, 'show', 'Location', 'best');
        return
    end
end
end
