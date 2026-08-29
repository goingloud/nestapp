% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function rows = paramForm(parent, meta, values, onChange)
% PARAMFORM  Build editing controls for a list of makeParam settings.
%   rows = PARAMFORM(parent, meta, values, onChange)
%
%   meta     makeParam struct array - the settings to offer
%   values   struct of the values already set; a field that is ABSENT means the
%            setting is at its default
%   onChange @(key, value) called when a control is touched. value = [] means
%            "back to the default", i.e. remove the field
%
%   Returns a struct array with .key and .handles, one entry per setting.
%
%   THE CONTROL FOLLOWS THE VALUES, not the storage type. makeParam already
%   records enough to choose one, so nothing new has to be declared:
%
%     logical                    dropdown - Default / On / Off
%     a pipe-separated validRange   dropdown of those choices
%     a 2-element vector         a Default box and a from/to pair
%     scalar or integer          a Default box and one number
%     anything else              a text field
%
%   A table of text cells could express none of that. It made the user type
%   "on", know that a width was spelled "single", and gave no hint which values
%   a setting would accept - which is how a documented option ended up
%   unreachable from the interface that set it.
%
%   UNSET IS A FIRST-CLASS STATE, and every control can express it: the
%   dropdowns carry a leading "Default (x)" item, the numeric rows a Default
%   checkbox that disables the field it governs. Disabled rather than hidden, so
%   the value that would be used stays visible. This matters because the
%   defaults live in the function that applies them - the registry only names
%   them in a placeholder - so a setting must be able to stay absent rather than
%   being frozen to a copy of whatever the default happened to be today.
%
%   Built as a free function rather than inside a dialog because the pipeline's
%   step parameters are the same problem at fifty-five steps, and they can adopt
%   this without either side knowing about the other.
%
%   See also: makeParam, plotOptionsDialog, plotRegistry, stepRegistry

ROW_H   = 34;
LABEL_W = 150;
CTRL_X  = 170;

rows = struct('key', {}, 'handles', {});
if isempty(meta); return; end

W = parent.Position(3);
y = parent.Position(4) - ROW_H;

for k = 1:numel(meta)
    m   = meta(k);
    val = valueOf(values, m.key);
    lbl = m.friendlyName;
    if ~isempty(m.unit); lbl = sprintf('%s (%s)', lbl, m.unit); end

    uilabel(parent, 'Position', [12 y LABEL_W 22], 'Text', lbl, ...
            'Tooltip', m.description);

    switch widgetFor(m)
        case 'toggle'
            h = uidropdown(parent, 'Position', [CTRL_X y 170 22], ...
                'Items', {sprintf('Default (%s)', defaultText(m)), 'On', 'Off'}, ...
                'ItemsData', {[], true, false}, ...
                'Tooltip', m.description, ...
                'ValueChangedFcn', @(src, ~) onChange(m.key, src.Value));
            if ~isempty(val); h.Value = asLogical(val); end

        case 'choice'
            choices = choicesOf(m);
            h = uidropdown(parent, 'Position', [CTRL_X y 170 22], ...
                'Items', [{sprintf('Default (%s)', defaultText(m))}, choices], ...
                'ItemsData', [{[]}, choices], ...
                'Tooltip', m.description, ...
                'ValueChangedFcn', @(src, ~) onChange(m.key, src.Value));
            if ~isempty(val) && ismember(char(val), choices); h.Value = char(val); end

        case 'range'
            h = numericRow(parent, y, CTRL_X, m, val, onChange, 2);

        case 'number'
            h = numericRow(parent, y, CTRL_X, m, val, onChange, 1);

        otherwise
            h = uieditfield(parent, 'text', ...
                'Position', [CTRL_X y W-CTRL_X-24 22], ...
                'Tooltip', m.description, ...
                'ValueChangedFcn', @(src, ~) onChange(m.key, textOrEmpty(src.Value)));
            if ~isempty(val); h.Value = char(string(val)); end
    end

    rows(end+1) = struct('key', m.key, 'handles', h); %#ok<AGROW>
    y = y - ROW_H;
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function h = numericRow(parent, y, x, m, val, onChange, n)
% A Default checkbox governing one or two number fields. Ticking it puts the
% setting back to absent; unticking hands over whatever the fields show.
h = struct();
h.auto = uicheckbox(parent, 'Position', [x y 84 22], 'Text', 'Default', ...
    'Tooltip', sprintf('%s  Default: %s', m.description, defaultText(m)), ...
    'Value', isempty(val));

seed = defaultNumbers(m, n);
if ~isempty(val); seed = padTo(val(:)', n, seed); end

h.fields = gobjects(1, n);
for i = 1:n
    h.fields(i) = uieditfield(parent, 'numeric', ...
        'Position', [x + 92 + (i-1)*74, y, 66, 22], ...
        'Value', seed(i), 'ValueDisplayFormat', '%g', ...
        'Tooltip', m.description);
end

push = @() onChange(m.key, currentValue(h, n));
set(h.auto,   'ValueChangedFcn', @(~, ~) applyAuto(h, push));
set(h.fields, 'ValueChangedFcn', @(~, ~) push());
applyAuto(h, @() []);   % set the initial enable state without reporting a change
end

function applyAuto(h, push)
set(h.fields, 'Enable', matlab.lang.OnOffSwitchState(~h.auto.Value));
push();
end

function v = currentValue(h, n)
if h.auto.Value
    v = [];                       % absent: the draw function's default applies
else
    v = arrayfun(@(f) f.Value, h.fields(1:n));
end
end

function w = widgetFor(m)
switch lower(char(m.type))
    case 'logical'
        w = 'toggle';
    case 'vector'
        w = 'range';
    case {'scalar', 'integer'}
        w = 'number';
    otherwise
        if ~isempty(choicesOf(m)); w = 'choice'; else; w = 'text'; end
end
end

function c = choicesOf(m)
% A validRange written as "a | b | c" is already a closed list; nothing new has
% to be declared in the registry for it to become a dropdown.
c = {};
if isempty(m.validRange) || ~contains(m.validRange, '|'); return; end
parts = strtrim(strsplit(m.validRange, '|'));
c = parts(~cellfun(@isempty, parts));
end

function s = defaultText(m)
% The placeholder names the default by convention - "(on)", "(-50 300)". Shown
% on the control so the user can see what leaving it alone will do.
s = strtrim(char(m.placeholder));
s = regexprep(s, '^\(|\)$', '');
if isempty(s); s = 'unset'; end
end

function v = defaultNumbers(m, n)
v = str2num(defaultText(m)); %#ok<ST2NM>  a placeholder like "-50 300"
if isempty(v) || ~isnumeric(v)
    v = zeros(1, n);
end
v = padTo(v(:)', n, zeros(1, n));
end

function v = padTo(v, n, fallback)
if numel(v) >= n
    v = v(1:n);
else
    fallback(1:numel(v)) = v;
    v = fallback;
end
end

function v = valueOf(values, key)
v = [];
if isstruct(values) && isfield(values, key); v = values.(key); end
end

function tf = asLogical(v)
if ischar(v) || isstring(v)
    tf = strcmpi(strtrim(char(v)), 'on');
else
    tf = logical(v);
end
end

function v = textOrEmpty(s)
v = char(s);
if isempty(strtrim(v)); v = []; end
end
