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
%   selected = ROIPICKER(current, available) greys out electrodes not present
%   in every loaded file. They stay visible - a missing electrode is
%   information about the data, and hiding it makes the montage look wrong.
%
%   selected = ROIPICKER(current, available, opts):
%     .parent  figure to centre the dialog over
%     .title   window title
%
%   Why this is a popup rather than part of a tab. The montage occupied
%   350x336 of an 867x529 tab - the single largest consumer of space on it -
%   to serve a choice most users make once per session. Moving it here frees
%   that region for the group and view controls, and turns 69 hand-written
%   uibutton blocks (637 lines) plus 69 class properties into a loop over
%   roiMontageLayout.
%
%   It also fixes where the ROI lives. The old code read the selection back
%   out of the widgets (findTEPelecs looped over app.(NAMEButton).Value), so
%   the UI *was* the state: the ROI could not be set programmatically, saved
%   into a session, or applied without the buttons existing. Here the buttons
%   are a view over a cellstr that goes in and comes out.
%
%   See also: roiMontageLayout, roiPresets, saveRoiPreset, roiChannelIndex

if nargin < 1 || isempty(current);   current = {};   end
if nargin < 2;                       available = {}; end
if nargin < 3;                       opts = struct(); end
opts = fillDefaults(opts, struct('parent', [], 'title', 'Select ROI electrodes'));

if ischar(current) || isstring(current);     current = cellstr(current);     end
if ischar(available) || isstring(available); available = cellstr(available); end

[layout, headSize] = roiMontageLayout();
PAD        = 12;
SIDE_W     = 190;                       % preset / action column
BAR_H      = 44;                        % OK / Cancel strip
figW       = headSize(1) + SIDE_W + PAD * 3;
figH       = headSize(2) + BAR_H + PAD * 2;

state = struct('labels', {{layout.label}}, 'selected', {selectedMask(layout, current)}, ...
               'enabled', {enabledMask(layout, available)}, 'accepted', false);

fig = uifigure('Name', char(opts.title), 'Resize', 'off', ...
               'Position', centreOn(opts.parent, figW, figH), ...
               'WindowStyle', 'modal');
% Deliberately NOT an onCleanup. The figure's callbacks are nested functions,
% which hold this workspace alive, and an onCleanup living in that workspace
% would hold the figure alive in turn - a cycle in which neither is ever
% released and every call leaks a window. The figure is deleted explicitly
% below, on both the accept and the cancel path, with a try/catch so a
% construction error cannot leak one either.

try
% ── head diagram with one toggle per electrode ───────────────────────────
headPanel = uipanel(fig, 'BorderType', 'none', ...
    'Position', [PAD, BAR_H + PAD, headSize(1), headSize(2)]);
uiimage(headPanel, 'Position', [0 0 headSize], ...
        'ImageSource', headImagePath(), 'ScaleMethod', 'fit');

btns = gobjects(1, numel(layout));
for i = 1:numel(layout)
    btns(i) = uibutton(headPanel, 'state', ...
        'Text', layout(i).label, 'Position', layout(i).pos, ...
        'FontSize', 8, 'FontWeight', 'bold', ...
        'IconAlignment', 'center', 'HorizontalAlignment', 'left', ...
        'Value', state.selected(i), 'Enable', onOff(state.enabled(i)));
    btns(i).ValueChangedFcn = @(src, ~) onToggle(i, src.Value);
end

% ── preset / bulk-action column ──────────────────────────────────────────
sx = PAD * 2 + headSize(1);
sy = figH - PAD - 22;

uilabel(fig, 'Text', 'Presets', 'FontWeight', 'bold', ...
        'Position', [sx, sy, SIDE_W, 22]);
presetDrop = uidropdown(fig, 'Position', [sx, sy - 26, SIDE_W, 22], ...
    'Items', {}, 'Editable', 'off');
uibutton(fig, 'Text', 'Apply preset', 'Position', [sx, sy - 54, SIDE_W, 24], ...
    'ButtonPushedFcn', @(~, ~) applyPreset());
uibutton(fig, 'Text', 'Save current as…', 'Position', [sx, sy - 82, SIDE_W, 24], ...
    'ButtonPushedFcn', @(~, ~) savePreset());
deleteBtn = uibutton(fig, 'Text', 'Delete preset', ...
    'Position', [sx, sy - 110, SIDE_W, 24], ...
    'ButtonPushedFcn', @(~, ~) deletePreset());

uilabel(fig, 'Text', 'Selection', 'FontWeight', 'bold', ...
        'Position', [sx, sy - 148, SIDE_W, 22]);
uibutton(fig, 'Text', 'Select all available', ...
    'Position', [sx, sy - 174, SIDE_W, 24], ...
    'ButtonPushedFcn', @(~, ~) setAll(true));
uibutton(fig, 'Text', 'Clear all', 'Position', [sx, sy - 202, SIDE_W, 24], ...
    'ButtonPushedFcn', @(~, ~) setAll(false));

countLabel = uilabel(fig, 'Position', [sx, sy - 240, SIDE_W, 32], ...
    'WordWrap', 'on', 'FontColor', [0.35 0.38 0.43]);

% ── accept / cancel ──────────────────────────────────────────────────────
uibutton(fig, 'Text', 'Use these electrodes', ...
    'Position', [figW - PAD - 300, PAD, 150, 26], ...
    'ButtonPushedFcn', @(~, ~) accept());
uibutton(fig, 'Text', 'Cancel', ...
    'Position', [figW - PAD - 145, PAD, 145, 26], ...
    'ButtonPushedFcn', @(~, ~) uiresume(fig));
fig.CloseRequestFcn = @(~, ~) uiresume(fig);

presets = struct('name', {}, 'labels', {});
builtins = {};
refreshPresets();
refreshCount();

uiwait(fig);
catch ME
    if isvalid(fig); delete(fig); end
    rethrow(ME);
end

if state.accepted
    selected = state.labels(state.selected);
else
    selected = [];        % cancelled - distinct from an empty selection
end
delete(fig);

% ── nested callbacks ─────────────────────────────────────────────────────
    function onToggle(i, value)
        state.selected(i) = value;
        refreshCount();
    end

    function setAll(value)
        % "All" means all AVAILABLE: switching on an electrode that is not in
        % every file would put a channel in the ROI that cannot be averaged.
        state.selected = value & state.enabled;
        syncButtons();
    end

    function applyPreset()
        k = find(strcmp({presets.name}, presetDrop.Value), 1);
        if isempty(k); return; end
        wanted = presets(k).labels;
        state.selected = ismember(lower(state.labels), lower(wanted)) & state.enabled;
        missing = wanted(~ismember(lower(wanted), lower(state.labels(state.enabled))));
        syncButtons();
        if ~isempty(missing)
            % Silently dropping part of a named ROI would change what the
            % preset means without saying so.
            uialert(fig, sprintf(['This preset names %s, which %s not available ' ...
                'in every loaded file. The rest has been applied.'], ...
                strjoin(missing, ', '), isAre(numel(missing))), ...
                'Preset partly unavailable', 'Icon', 'warning');
        end
    end

    function savePreset()
        answer = inputdlg('Name for this ROI:', 'Save ROI preset', [1 45]);
        if isempty(answer) || isempty(strtrim(answer{1})); return; end
        saveRoiPreset(strtrim(answer{1}), state.labels(state.selected));
        refreshPresets(strtrim(answer{1}));
    end

    function deletePreset()
        name = presetDrop.Value;
        if isempty(name); return; end
        saveRoiPreset(name, {});
        refreshPresets();
    end

    function refreshPresets(selectName)
        [presets, builtins] = roiPresets();
        names = {presets.name};
        presetDrop.Items = names;
        if nargin >= 1 && any(strcmp(names, selectName))
            presetDrop.Value = selectName;
        end
        updateDeleteEnable();
        presetDrop.ValueChangedFcn = @(~, ~) updateDeleteEnable();
    end

    function updateDeleteEnable()
        % Only user presets can be deleted; a built-in override reverts.
        isUser = ~isempty(presetDrop.Value) && ...
                 (~any(strcmp(builtins, presetDrop.Value)) || isOverridden(presetDrop.Value));
        deleteBtn.Enable = onOff(isUser);
    end

    function syncButtons()
        for j = 1:numel(btns)
            btns(j).Value = state.selected(j);
        end
        refreshCount();
    end

    function refreshCount()
        n = sum(state.selected);
        nOff = sum(~state.enabled);
        txt = sprintf('%d electrode%s selected', n, plural(n));
        if nOff > 0
            txt = sprintf('%s\n%d not in every file', txt, nOff);
        end
        countLabel.Text = txt;
    end

    function accept()
        state.accepted = true;
        uiresume(fig);
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function mask = selectedMask(layout, current)
mask = ismember(lower({layout.label}), lower(current));
end

function mask = enabledMask(layout, available)
if isempty(available)
    mask = true(1, numel(layout));       % nothing loaded yet: offer everything
else
    mask = ismember(lower({layout.label}), lower(available));
end
end

function tf = isOverridden(name)
saved = getpref('nestapp', 'roiPresets', struct('name', {}, 'labels', {}));
tf = ~isempty(saved) && isfield(saved, 'name') && any(strcmp({saved.name}, name));
end

function p = headImagePath()
% Head.png sits in src/, alongside this file. createComponents reaches it as
% fileparts(fileparts(mfilename)) from inside @nestapp, which resolves to the
% same place.
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

function s = onOff(tf)
if tf; s = 'on'; else; s = 'off'; end
end

function s = plural(n)
if n == 1; s = ''; else; s = 's'; end
end

function s = isAre(n)
if n == 1; s = 'is'; else; s = 'are'; end
end
