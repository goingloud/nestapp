% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function form = settingsForm(varargin)
% SETTINGSFORM  The Cleaning tab's form for one pipeline step's settings.
%   form = SETTINGSFORM(parent, entry, values, cb, ctx)   build it
%   form = SETTINGSFORM('refresh', form, entry, values, badKeys, off, reasons)
%                                                         update states only
%
%   parent  a (scrollable) uipanel; the form fills its current width
%   entry   the step's stepRegistry entry
%   values  the step's params struct
%   cb      struct of callbacks:
%             onChange(key, value)   a setting was edited (value is typed)
%             onFocus(key)           the user is working on this setting
%             onToggleAdvanced()     the "advanced settings" link was clicked
%   ctx     struct: showAdvanced (logical), figure (parent for dialogs), and a
%           field per choicesFrom list a setting names - e.g. channels, the
%           labels the channel chooser offers (a cellstr, or a function that
%           returns one, so they are only read when the chooser opens)
%
%   Follows docs/ui-design-language.md. The control is derived from the
%   setting's declaration (makeParam): a checkbox for a binary setting, a
%   dropdown for choices, a mode dropdown with a value control beside it, a
%   spinner for stepped integers, a numeric field with limits, a from/to pair
%   for a range, a chooser for channel lists. A step not yet converted to typed
%   settings (schema 1) gets a dropdown where its validRange lists choices and
%   a text field otherwise, storing the same text the old table did.
%
%   'refresh' re-applies the states that depend on the values - bold for a
%   changed setting, grey for a disabled one, red for one with a problem -
%   without rebuilding, so focus and scroll position survive an edit. It only
%   touches rows whose state changed, and returns the form with that state.
%   off/reasons are disabledParamKeys' output, passed in so the caller
%   works them out once per edit.
%
%   See also: paramForm (the plot Options dialogs), disabledParamKeys,
%   paramProblems, pickChannels

if ischar(varargin{1}) && strcmp(varargin{1}, 'refresh')
    form = refreshStates(varargin{2:end});
    return
end
[parent, entry, values, cb, ctx] = varargin{:};
form = build(parent, entry, values, cb, ctx);
end

% ===========================================================================

function form = build(parent, entry, values, cb, ctx)
delete(parent.Children);
ROW = 32; HEAD = 30; GAP = 12; LINK = 34;
W     = max(parent.Position(3) - 22, 280);
ctrlX = max(170, round(0.42 * W));
ctrlW = W - ctrlX - 6;
typed = fieldOr(entry, 'schema', 1) >= 2;
params = entry.params;
if isempty(params)
    uilabel(parent, 'Position', [12 parent.Position(4)-34 W-12 22], ...
        'Text', 'This step has no settings.', 'FontColor', nestColours('muted'));
    form = struct('rows', emptyRows(), 'width', parent.Position(3));
    return
end

% Which rows show, in which sections, and how tall the content is.
adv     = [params.advanced];
shown   = params(~adv | ctx.showAdvanced);
secs    = unique({shown.section}, 'stable');
nHeads  = sum(~cellfun(@isempty, secs));
LINE2 = 28;   % a mode's value control too wide for its row goes on a line below
two = arrayfun(@(m) typed && needsSecondLine(m, ctrlW), shown);
H = 6 + nHeads * (HEAD + GAP) + numel(shown) * ROW + sum(two) * LINE2 + any(adv) * LINK;
top = max(H, parent.Position(4) - 4);

rows = emptyRows();
y = top;
for s = 1:numel(secs)
    inSec = shown(strcmp({shown.section}, secs{s}));
    if ~isempty(secs{s})
        y = y - HEAD - (s > 1) * GAP;
        uilabel(parent, 'Position', [10 y W-10 20], 'Text', upper(secs{s}), ...
            'FontWeight', 'bold', 'FontSize', 10, 'FontColor', nestColours('navy'));
        uipanel(parent, 'Position', [10 y-3 W-14 1], 'BorderType', 'none', ...
            'BackgroundColor', nestColours('mintLine'));
    end
    for m = inSec
        y = y - ROW;
        second = two(strcmp({shown.key}, m.key));
        rows(end+1) = buildRow(parent, y, m, values, entry, typed, ctrlX, ctrlW, W, cb, ctx, second * LINE2); %#ok<AGROW>
        y = y - second * LINE2;
    end
end
if any(adv)
    y = y - LINK + 6;
    word = 'Show'; arrow = char(9654);
    if ctx.showAdvanced, word = 'Hide'; arrow = char(9660); end
    uihyperlink(parent, 'Position', [10 y W-10 22], ...
        'Text', sprintf('%s  %s advanced settings (%d)', arrow, word, sum(adv)), ...
        'URL', '', 'HyperlinkClickedFcn', @(~, ~) cb.onToggleAdvanced());
end
form = struct('rows', rows, 'width', parent.Position(3));
if top > parent.Position(4), scroll(parent, 'top'); end
end

% ---------------------------------------------------------------------------

function r = buildRow(parent, y, m, values, entry, typed, X, CW, W, cb, ctx, drop)
% drop > 0: a mode's value control goes on a line that far below the row.
v = [];
if isfield(values, m.key), v = values.(m.key); end
lbl = m.friendlyName;
if ~isempty(m.unit), lbl = sprintf('%s (%s)', lbl, m.unit); end
tip = tooltipFor(m, entry);
focus = @(varargin) cb.onFocus(m.key);
r = struct('key', m.key, 'label', [], 'ctrls', gobjects(0), 'tip', tip, 'state', '');

if ~typed
    r.label = uilabel(parent, 'Position', [10 y X-16 22], 'Text', lbl, 'Tooltip', tip);
    choices = validRangeChoices(m);
    if ~isempty(choices)
        cur = asText(v);
        if ~any(strcmp(cur, choices)), choices = [{cur}, choices]; end
        r.ctrls = uidropdown(parent, 'Position', [X y CW 22], 'Items', choices, ...
            'Value', cur, 'Tooltip', tip, 'DropDownOpeningFcn', focus, ...
            'ValueChangedFcn', @(src, ~) commit(src.Value));
    else
        r.ctrls = uieditfield(parent, 'Position', [X y CW 22], 'Value', asText(v), ...
            'Placeholder', m.placeholder, 'Tooltip', tip, 'ValueChangingFcn', focus, ...
            'ValueChangedFcn', @(src, ~) commit(convertParam(src.Value, m.type)));
    end
    return
end

if strcmp(m.type, 'logical')
    r.label = uicheckbox(parent, 'Position', [10 y W-10 22], 'Text', lbl, ...
        'Value', isequal(v, true), 'Tooltip', tip, ...
        'ValueChangedFcn', @(src, ~) commit(logical(src.Value)));
    r.ctrls = r.label;
    return
end

r.label = uilabel(parent, 'Position', [10 y X-16 22], 'Text', lbl, 'Tooltip', tip);
if ~isempty(m.choices)
    r.ctrls = uidropdown(parent, 'Position', [X y CW 22], 'Items', {m.choices.label}, ...
        'ItemsData', {m.choices.key}, 'Value', pickValid(v, {m.choices.key}), 'Tooltip', tip, ...
        'DropDownOpeningFcn', focus, 'ValueChangedFcn', @(src, ~) commit(src.Value));
elseif ~isempty(m.modes)
    VALUE = '__value';
    isMode = ischar(v) && any(strcmp(v, {m.modes.key}));
    dd = uidropdown(parent, 'Position', [X y min(130, CW) 22], ...
        'Items', [{m.modes.label}, {m.valueLabel}], 'ItemsData', [{m.modes.key}, {VALUE}], ...
        'Value', ternary(isMode, v, VALUE), 'Tooltip', tip, 'DropDownOpeningFcn', focus);
    vx = X + min(130, CW) + 6; vy = y; vw = X + CW - vx;
    if drop > 0, vx = X; vy = y - drop; vw = CW; end
    seed = v;
    if isMode, seed = defaultValueFor(m, entry); end
    [vc, readValue] = valueControl(parent, m, seed, vx, vy, vw, tip, focus, @commitValue, ctx);
    set(vc, 'Visible', ternary(isMode, 'off', 'on'));
    dd.ValueChangedFcn = @(src, ~) modeChanged(src.Value);
    r.ctrls = [dd, vc];
else
    [r.ctrls, ~] = valueControl(parent, m, v, X, y, CW, tip, focus, @commit, ctx);
end

    function commit(val)
        cb.onFocus(m.key);
        cb.onChange(m.key, val);
    end
    function commitValue(val)
        if ~isempty(val), commit(val); end
    end
    function modeChanged(choice)
        isVal = strcmp(choice, VALUE);
        set(vc, 'Visible', ternary(isVal, 'on', 'off'));
        if isVal
            commitValue(readValue());   % a value already in the field takes effect
        else
            commit(choice);
        end
    end
end

% ---------------------------------------------------------------------------

function [h, readValue] = valueControl(parent, m, v, X, y, CW, tip, focus, commit, ctx)
% The control for the value itself. readValue() returns what it currently
% holds as a typed value ([] when incomplete).
switch m.type
    case 'stringlist'
        % With a choicesFrom list: picked from it in a chooser. Without: typed,
        % comma-separated.
        listed = ~isempty(m.choicesFrom);
        txtW = ternary(listed, max(CW-84, 60), CW);
        txt = uieditfield(parent, 'Position', [X y txtW 22], 'Editable', ternary(listed, 'off', 'on'), ...
            'Value', asText(v), 'Tooltip', tip);
        readValue = @() convertParam(txt.Value, 'stringlist');
        h = txt;
        if listed
            h = [txt, uibutton(parent, 'Position', [X+txtW+6 y 78 22], 'Text', 'Choose...', ...
                'Tooltip', tip, 'ButtonPushedFcn', @(~, ~) choose())];
        else
            txt.ValueChangedFcn = @(~, ~) commit(readValue());
        end
    case 'vector'
        w = max(round((CW - 28) / 2), 50);
        a = uieditfield(parent, 'numeric', 'Position', [X y w 22], 'AllowEmpty', 'on', ...
            'Value', firstOr(v, 1), 'Tooltip', tip);
        t = uilabel(parent, 'Position', [X+w+4 y 20 22], 'Text', 'to', 'HorizontalAlignment', 'center');
        b = uieditfield(parent, 'numeric', 'Position', [X+w+28 y w 22], 'AllowEmpty', 'on', ...
            'Value', firstOr(v, 2), 'Tooltip', tip);
        applyLimits([a b], m);
        readValue = @() pairOf(a.Value, b.Value);
        set([a b], 'ValueChangedFcn', @(~, ~) commit(readValue()));
        h = [a, t, b];
    case 'integer'
        if ~isempty(m.step)
            h = uispinner(parent, 'Position', [X y min(110, CW) 22], 'Step', m.step, ...
                'Value', numOr(v, max(0, firstOr(m.limits, 1))), 'Tooltip', tip, ...
                'RoundFractionalValues', 'on', 'ValueChangingFcn', focus);
        else
            h = uieditfield(parent, 'numeric', 'Position', [X y min(110, CW) 22], ...
                'Value', numOr(v, 0), 'RoundFractionalValues', 'on', 'Tooltip', tip);
        end
        applyLimits(h, m);
        readValue = @() h.Value;
        h.ValueChangedFcn = @(src, ~) commit(src.Value);
    case 'scalar'
        h = uieditfield(parent, 'numeric', 'Position', [X y min(110, CW) 22], ...
            'Value', numOr(v, 0), 'Tooltip', tip);
        applyLimits(h, m);
        readValue = @() h.Value;
        h.ValueChangedFcn = @(src, ~) commit(src.Value);
    otherwise   % string / file / folder
        h = uieditfield(parent, 'Position', [X y CW 22], 'Value', asText(v), ...
            'Tooltip', tip, 'ValueChangingFcn', focus);
        readValue = @() h.Value;
        h.ValueChangedFcn = @(src, ~) commit(src.Value);
end

    function choose()
        focus();
        list = ctx.(m.choicesFrom);
        if isa(list, 'function_handle'), list = list(); end
        pickChannels(ctx.figure, readValue(), list, m.friendlyName, @chosen);
    end
    function chosen(labels)
        txt.Value = strjoin(labels, ', ');
        commit(labels);
    end
end

% ===========================================================================

function form = refreshStates(form, entry, values, badKeys, off, reasons)
if nargin < 5, [off, reasons] = disabledParamKeys(entry, values); end
for i = 1:numel(form.rows)
    r = form.rows(i);
    if ~all(isvalid(r.label)), continue; end
    isOff = any(strcmp(r.key, off));
    isBad = any(strcmp(r.key, badKeys));
    changed = isfield(values, r.key) && isfield(entry.defaults, r.key) ...
        && ~isequal(values.(r.key), entry.defaults.(r.key));
    state = sprintf('%d%d%d', isOff, isBad, changed);
    if strcmp(state, r.state), continue; end   % nothing to repaint
    colour = [0 0 0];
    if isOff, colour = nestColours('disabled'); end
    if isBad, colour = nestColours('problem'); end
    tip = r.tip;
    if isOff, tip = sprintf('%s\n\n%s', reasons.(r.key), tip); end
    set(r.label, 'FontWeight', ternary(changed, 'bold', 'normal'), 'FontColor', colour, 'Tooltip', tip);
    set(r.ctrls, 'Enable', ternary(isOff, 'off', 'on'));
    form.rows(i).state = state;
end
end

% ---------------------------------------------------------------------------

function tip = tooltipFor(m, entry)
tip = m.description;
if isfield(entry.defaults, m.key)
    tip = sprintf('%s\nDefault: %s', tip, settingText(m, entry.defaults.(m.key)));
end
end

function tf = needsSecondLine(m, CW)
% A range or channel list beside a mode dropdown needs ~170 px; below that it
% goes on its own line rather than spilling past the panel.
tf = ~isempty(m.modes) && any(strcmp(m.type, {'vector', 'stringlist'})) ...
    && (CW - min(130, CW) - 6) < 170;
end

function v = defaultValueFor(m, entry)
% What the value control starts at when the setting is in a named state: the
% default if that is a value, else nothing.
v = [];
if isfield(entry.defaults, m.key) && ~ischar(entry.defaults.(m.key))
    v = entry.defaults.(m.key);
end
end

function applyLimits(h, m)
if isempty(m.limits), return; end
set(h, 'Limits', m.limits);
if m.openMin, set(h, 'LowerLimitInclusive', 'off'); end
end

function v = pickValid(v, keys)
if ~(ischar(v) && any(strcmp(v, keys))), v = keys{1}; end
end

function s = asText(v)
if ischar(v), s = v;
elseif isstring(v), s = char(v);
elseif iscell(v), s = strjoin(cellfun(@asText, v, 'UniformOutput', false), ', ');
elseif isempty(v), s = '';
else, s = mat2str(v);
end
end

function rows = emptyRows()
rows = struct('key', {}, 'label', {}, 'ctrls', {}, 'tip', {}, 'state', {});
end

function x = firstOr(v, k)
x = [];
if isnumeric(v) && numel(v) >= k, x = v(k); end
end

function x = numOr(v, d)
x = d;
if isnumeric(v) && ~isempty(v) && isfinite(v(1)), x = v(1); end
end

function p = pairOf(a, b)
p = [];
if ~isempty(a) && ~isempty(b), p = [a b]; end
end
