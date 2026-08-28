
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function L = captureBaseLayout(app)
% CAPTUREBASELAYOUT  Snapshot every rescalable component's base geometry.
%   L = CAPTUREBASELAYOUT(app) walks the app's component properties and records,
%   per component, its base Position, whether it is a fixed-height control
%   (scaled without changing height), and its base font size when its font
%   should scale. Called once from startupFcn; rescaleComponents then scales
%   from this snapshot.
%
%   This makes createComponents the single source of truth for geometry: the
%   coordinates live there as literals, are captured here at run time, and are
%   never duplicated in rescaleComponents. New components are picked up
%   automatically - add one to createComponents and it rescales with no extra
%   wiring. StatusBar/TabGroup are excluded (rescaleComponents handles their
%   special full-width / computed-height layout); the figure and the tabs are
%   not repositioned.
%
%   See also: rescaleComponents, UIFigureSizeChanged

    % Excluded from rescale: the status bar and TabGroup, which
    % rescaleComponents lays out explicitly, and the figure itself.
    exclude   = {'UIFigure', 'TabGroup', 'StatusBar'};
    fontMap = fontScaledMap();

    L       = struct();
    mc      = metaclass(app);
    thisCls = class(app);
    for i = 1:numel(mc.PropertyList)
        prop = mc.PropertyList(i);
        % Only properties declared on this class - skip inherited AppBase
        % internals (e.g. TimingFields) that are hidden / not readable here.
        if ~strcmp(prop.DefiningClass.Name, thisCls) || prop.Hidden
            continue
        end
        name = prop.Name;
        if any(strcmp(name, exclude))
            continue
        end
        h = app.(name);
        % Require a real [x y w h] rectangle: this skips menus (scalar Position
        % = menu order) and any non-positional graphics.
        if ~(isscalar(h) && isgraphics(h) && isprop(h, 'Position') && numel(h.Position) == 4)
            continue
        end
        % Tabs are sized by their TabGroup and their Position is READ-ONLY, so
        % including one makes the next resize throw. Excluded by TYPE rather
        % than by name: the previous version listed the four tabs that existed,
        % and adding a fifth silently broke resizing until a resize was tried.
        if isa(h, 'matlab.ui.container.Tab')
            continue
        end
        e = struct('pos', h.Position, 'fixedH', isFixedHeightControl(h), 'font', []);
        if isfield(fontMap, name)
            e.font = fontMap.(name);
        end
        L.(name) = e;
    end
end

% ── local helpers ─────────────────────────────────────────────────────────────

function tf = isFixedHeightControl(h)
% Controls whose height cannot scale (MATLAB warns / clamps). Their width and
% position scale, but height stays at the base value.
    tf = isa(h, 'matlab.ui.control.CheckBox')        || ...
         isa(h, 'matlab.ui.control.EditField')       || ...
         isa(h, 'matlab.ui.control.NumericEditField')|| ...
         isa(h, 'matlab.ui.control.Spinner')         || ...
         isa(h, 'matlab.ui.control.RangeSlider')     || ...
         isa(h, 'matlab.ui.control.DropDown')        || ...
         isa(h, 'matlab.ui.control.Slider');
end

function m = fontScaledMap()
% Components whose font scales with the window, with their base point size
% (mirrors the previous rescaleComponents fs() calls). Everything else keeps a
% fixed font.
    m = struct( ...
        'StepsTree', 11, 'CommandDescriptionLabel', 14, 'StepsListBoxLabel', 16, ...
        'SelectedListBox', 11, 'SelectedListBoxLabel', 16, 'SelectedListBoxLabel_2', 16, ...
        'RunAnalysisButton', 18, 'NESTAPPLabel', 14, 'ReStartStepsButton', 18, ...
        'ReportsListBoxLabel', 16, 'ReportsListBox', 11, 'ReportsTextArea', 10);
end
