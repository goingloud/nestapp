% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function selected = roiPicker(current, available, opts)
% ROIPICKER  Modal head-diagram picker for a region of interest.
%   selected = ROIPICKER(current) opens the montage with the electrodes in
%   `current` switched on and returns the chosen cellstr, or [] if cancelled.
%   Returning [] rather than {} for a cancel matters: an empty ROI is a legal
%   thing to choose, so the two cannot share a value.
%
%   selected = ROIPICKER(current, available) greys out electrodes the loaded
%   data does not offer. They stay visible - a missing electrode is information
%   about the data, and hiding it makes the montage look wrong.
%
%   selected = ROIPICKER(current, available, opts):
%     .parent         figure to centre the dialog over
%     .title          window title
%     .availableNote  why the greyed ones are unavailable, e.g.
%                     'not on the modal cap'. The picker renders this reason
%                     rather than asserting one: availability used to mean
%                     "in every loaded file", and groupCurves has since moved
%                     to a modal montage, so a hard-coded sentence would
%                     misstate why an electrode is greyed.
%     .presets        struct array (.name .labels .userDefined) overriding the
%                     stored presets
%     .savePreset     @(name, labels) overriding where a preset is written
%
%   The last two exist so a caller can supply its own preset store. Without
%   them a modal dialog performs global persistent writes with no interception
%   point, which is also what made the picker awkward to test against live
%   user preferences.
%
%   Why this is a popup rather than part of a tab. The montage occupies 350x336
%   of an 867x529 tab - the largest single consumer of space there - to serve a
%   choice most users make once a session.
%
%   It also moves where the ROI lives. findTEPelecs reads the selection back out
%   of the widgets, looping over app.(NAMEButton).Value, so the UI *is* the
%   state: an ROI cannot be set programmatically, saved into a session, or
%   applied without the buttons existing. The picker takes a cellstr in and
%   hands one back, with the buttons as a view over it.
%
%   See also: roiSelectionState, applyRoiPreset, roiMontageLayout, roiPresets

if nargin < 1 || isempty(current);   current = {};   end
if nargin < 2;                       available = {}; end
if nargin < 3;                       opts = struct(); end
opts = fillDefaults(opts, struct( ...
    'parent', [], 'title', 'Select ROI electrodes', ...
    'availableNote', 'not in every loaded file', ...
    'presets', [], 'savePreset', @saveRoiPreset));

if ischar(current) || isstring(current);     current = cellstr(current);     end
if ischar(available) || isstring(available); available = cellstr(available); end

[layout, headSize] = roiMontageLayout();
% Every set-of-labels decision lives in roiSelectionState, which is pure and
% unit-tested; this function is the view over it.
st          = roiSelectionState(current, available);
labels      = st.labels;
enabled     = st.enabled;
selected    = st.selected;
unplaceable = st.unplaceable;
accepted    = false;

PAD    = 12;
SIDE_W = 190;
BAR_H  = 44;
BTN_W  = 150;
GAP    = 5;
figW   = headSize(1) + SIDE_W + PAD * 3;
figH   = headSize(2) + BAR_H + PAD * 2;

fig = uifigure('Name', char(opts.title), 'Resize', 'off', ...
               'Position', centreOn(opts.parent, figW, figH), ...
               'WindowStyle', 'modal');
% Deliberately NOT an onCleanup. The figure's callbacks are nested functions,
% which hold this workspace alive, and an onCleanup living in that workspace
% would hold the figure alive in turn - a cycle in which neither is released
% and every call leaks a window. Deleted explicitly below, on both paths.

try
% ── head diagram with one toggle per electrode ───────────────────────────
headPanel = uipanel(fig, 'BorderType', 'none', ...
    'Position', [PAD, BAR_H + PAD, headSize(1), headSize(2)]);
uiimage(headPanel, 'Position', [0 0 headSize], ...
        'ImageSource', headImagePath(), 'ScaleMethod', 'fit');

btns = gobjects(1, numel(layout));
for i = 1:numel(layout)
    btns(i) = uibutton(headPanel, 'state', ...
        'Text', labels{i}, 'Position', layout(i).pos, ...
        'FontSize', 8, 'FontWeight', 'bold', ...
        'IconAlignment', 'center', 'HorizontalAlignment', 'left', ...
        'Value', selected(i), 'Enable', enabled(i));
    btns(i).ValueChangedFcn = @(src, ~) onToggle(i, src.Value);
end

% ── preset / bulk-action column ──────────────────────────────────────────
sx = PAD * 2 + headSize(1);
y  = figH - PAD;

uilabel(fig, 'Text', 'Presets', 'FontWeight', 'bold', 'Position', row(22, 0));
presetDrop = uidropdown(fig, 'Position', row(22, 4), 'Items', {}, ...
    'Editable', 'off', 'ValueChangedFcn', @(~, ~) updateDeleteEnable());
uibutton(fig, 'Text', 'Apply preset',     'Position', row(24, 4), ...
    'ButtonPushedFcn', @(~, ~) applyPreset());
uibutton(fig, 'Text', 'Save current as…', 'Position', row(24, 4), ...
    'ButtonPushedFcn', @(~, ~) savePreset());
deleteBtn = uibutton(fig, 'Text', 'Delete preset', 'Position', row(24, 4), ...
    'ButtonPushedFcn', @(~, ~) deletePreset());

uilabel(fig, 'Text', 'Selection', 'FontWeight', 'bold', 'Position', row(22, 16));
uibutton(fig, 'Text', 'Select all available', 'Position', row(24, 4), ...
    'ButtonPushedFcn', @(~, ~) setAll(true));
uibutton(fig, 'Text', 'Clear all', 'Position', row(24, 4), ...
    'ButtonPushedFcn', @(~, ~) setAll(false));

countLabel = uilabel(fig, 'Position', row(46, 12), 'WordWrap', 'on', ...
                     'VerticalAlignment', 'top', 'FontColor', [0.35 0.38 0.43]);

% ── accept / cancel ──────────────────────────────────────────────────────
right = figW - PAD;
uibutton(fig, 'Text', 'Use these electrodes', ...
    'Position', [right - 2 * BTN_W - GAP, PAD, BTN_W, 26], ...
    'ButtonPushedFcn', @(~, ~) accept());
uibutton(fig, 'Text', 'Cancel', ...
    'Position', [right - BTN_W, PAD, BTN_W, 26], ...
    'ButtonPushedFcn', @(~, ~) uiresume(fig));
fig.CloseRequestFcn = @(~, ~) uiresume(fig);

presets = struct('name', {}, 'labels', {}, 'userDefined', {});
refreshPresets();
refreshCount();

% Announce that the dialog is about to block. Anything driving it - a test, a
% script - otherwise has to guess when uiwait has started, and uiresume issued
% before that point is silently a no-op, leaving the dialog up for good. The
% flag makes "is it waiting yet" answerable instead of a race against however
% long the 69 buttons took to build.
setappdata(fig, 'nestappModalReady', true);
uiwait(fig);
catch ME
    if isvalid(fig); delete(fig); end
    rethrow(ME);
end

if accepted
    selected = labels(selected);
else
    selected = [];        % cancelled - distinct from an empty selection
end
if isvalid(fig); delete(fig); end

% ── nested callbacks ─────────────────────────────────────────────────────
    function p = row(h, gap)
    % One cursor down the side column, so a gap is a named number rather than
    % an offset every control below has to be re-derived from by hand.
        y = y - gap - h;
        p = [sx, y, SIDE_W, h];
    end

    function onToggle(i, value)
        selected(i) = value;
        refreshCount();
    end

    function setAll(value)
        % "All" means all AVAILABLE: switching on an electrode the data does
        % not have would put a channel in the ROI that cannot be averaged.
        selected = value & enabled;
        syncButtons();
    end

    function applyPreset()
        k = find(strcmp({presets.name}, presetDrop.Value), 1);
        if isempty(k); return; end
        [selected, missing] = applyRoiPreset(labels, enabled, presets(k).labels);
        syncButtons();
        if ~isempty(missing)
            % Silently dropping part of a named ROI would change what the
            % preset means without saying so.
            uialert(fig, sprintf(['This preset names %s, which %s %s. The rest ' ...
                'has been applied.'], strjoin(missing, ', '), ...
                isAre(numel(missing)), opts.availableNote), ...
                'Preset partly unavailable', 'Icon', 'warning');
        end
    end

    function savePreset()
        answer = inputdlg('Name for this ROI:', 'Save ROI preset', [1 45]);
        if isempty(answer) || isempty(strtrim(answer{1})); return; end
        opts.savePreset(strtrim(answer{1}), labels(selected));
        refreshPresets(strtrim(answer{1}));
    end

    function deletePreset()
        if isempty(presetDrop.Value); return; end
        opts.savePreset(presetDrop.Value, {});
        refreshPresets();
    end

    function refreshPresets(selectName)
        if isempty(opts.presets)
            presets = roiPresets();
        else
            presets = opts.presets;
        end
        presetDrop.Items = {presets.name};
        if nargin >= 1 && any(strcmp(presetDrop.Items, selectName))
            presetDrop.Value = selectName;
        end
        updateDeleteEnable();
    end

    function updateDeleteEnable()
        % Only a user-defined preset can be deleted. Every name in the list is
        % either a built-in or came from the store, so roiPresets' own
        % userDefined flag settles it - no second look at the preferences.
        k = find(strcmp({presets.name}, presetDrop.Value), 1);
        deleteBtn.Enable = ~isempty(k) && presets(k).userDefined;
    end

    function syncButtons()
        for j = 1:numel(btns)
            btns(j).Value = selected(j);
        end
        refreshCount();
    end

    function refreshCount()
        n    = sum(selected);
        nOff = sum(~enabled);
        txt  = sprintf('%d electrode%s selected', n, plural(n));
        if nOff > 0
            txt = sprintf('%s\n%d %s', txt, nOff, opts.availableNote);
        end
        if ~isempty(unplaceable)
            txt = sprintf('%s\nNot on this diagram: %s', txt, ...
                          strjoin(unplaceable, ', '));
        end
        countLabel.Text = txt;
    end

    function accept()
        accepted = true;
        uiresume(fig);
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function p = headImagePath()
% Head.png sits in src/, alongside this file. createComponents reaches the same
% file as fileparts(fileparts(mfilename)) from inside @nestapp.
p = fullfile(fileparts(mfilename('fullpath')), 'Head.png');
end

function pos = centreOn(parent, w, h)
if ~isempty(parent) && isvalid(parent)
    p = parent.Position;
    pos = [p(1) + (p(3) - w) / 2, p(2) + (p(4) - h) / 2, w, h];
else
    s = get(groot, 'ScreenSize');
    pos = [(s(3) - w) / 2, (s(4) - h) / 2, w, h];
end
pos(1:2) = max(pos(1:2), 1);
end
