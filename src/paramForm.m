% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function rows = paramForm(parent, meta, values, onChange, context)
% PARAMFORM  Build editing controls for a list of makeParam settings.
%   rows = PARAMFORM(parent, meta, values, onChange)
%   rows = PARAMFORM(parent, meta, values, onChange, context)
%
%   meta     makeParam struct array - the settings to offer
%   values   struct of the values already set; a field that is ABSENT means the
%            setting is at its default
%   onChange @(key, value) called when a control is touched. value = [] means
%            "back to the default", i.e. remove the field
%   context  struct whose fields supply choices for params declaring
%            'choicesFrom'. For a list that is not knowable when the registry
%            is written - the windows in the user's table right now - there is
%            nothing a validRange could say, so the caller passes them in.
%
%   Returns a struct array with .key and .handles, one entry per setting.
%
%   Panel height comes from paramFormHeight, which the CALLER must also use to
%   size the panel - see that function for why the row heights live there.
%
%   THE CONTROL FOLLOWS THE VALUES, not the storage type. makeParam already
%   records enough to choose one, so nothing new has to be declared:
%
%     logical                    a checkbox, sitting at its default
%     a pipe-separated validRange   dropdown of those choices
%     a 2-element vector         a Default box and a from/to pair
%     scalar or integer          a Default box and one number
%     anything else              a text field
%
%   makeParam's 'widget' overrides that inference, for the one control it
%   cannot reach: 'multiselect', a listbox for choosing several of a list the
%   registry does not know.
%
%   A table of text cells could express none of that. It made the user type
%   "on", know that a width was spelled "single", and gave no hint which values
%   a setting would accept - which is how a documented option ended up
%   unreachable from the interface that set it.
%
%   UNSET IS A FIRST-CLASS STATE, and every control can express it - but not
%   all of them need a separate item to say so. WHERE A CONTROL CAN DISPLAY THE
%   DEFAULT AS ONE OF ITS ORDINARY STATES, IT DOES, and unset is inferred by
%   comparing the selection against the default: choosing "on" when on IS the
%   default writes nothing, so the setting stays absent and keeps following the
%   draw function. A logical is then a plain checkbox rather than three items
%   for a two-state setting, and an enum a dropdown of just its choices.
%
%   What that gives up is pinning a value that happens to equal today's default
%   so it survives a later change to it. For a plot setting that is a non-goal,
%   and not worth an extra item in every list.
%
%   Two kinds of row keep an explicit Default control, because there is nothing
%   for a comparison to match against:
%     - the numeric rows, whose defaults are DERIVED (a width-relative font
%       size, say) rather than a number the field could be showing
%     - any setting whose placeholder does not name a default, or names one
%       outside its own choices. Then the form cannot know what unset means,
%       and says so with a "Default" item rather than guessing.
%   Disabled rather than hidden, so the value that would be used stays visible.
%
%   Built as a free function rather than inside a dialog because the pipeline's
%   step parameters are the same problem at fifty-five steps, and they can adopt
%   this without either side knowing about the other.
%
%   See also: makeParam, plotOptionsDialog, plotRegistry, stepRegistry

ROW_H   = 34;
LABEL_W = 150;
CTRL_X  = 170;
if nargin < 5 || isempty(context); context = struct(); end

rows = struct('key', {}, 'handles', {});
if isempty(meta); return; end

[~, rowH] = paramFormHeight(meta);
W      = parent.Position(3);
rowTop = parent.Position(4);

for k = 1:numel(meta)
    y = rowTop - ROW_H;   % a one-line control sits at the bottom of its row
    m      = meta(k);
    val    = valueOf(values, m.key);
    widget = widgetFor(m, context);
    lbl    = m.friendlyName;
    if ~isempty(m.unit); lbl = sprintf('%s (%s)', lbl, m.unit); end

    dflt = statedDefault(m, widget);

    % A checkbox reads as its own label - "[x] Confidence band" - and the box
    % alone is a poor click target, so a toggle spans the row rather than
    % sitting in the control column behind a label that repeats it.
    spansRow = (strcmp(widget, 'toggle') && ~isempty(dflt)) ...
               || strcmp(widget, 'multiselect');   % labels itself, above the list
    if ~spansRow
        uilabel(parent, 'Position', [12 y LABEL_W 22], 'Text', lbl, ...
                'Tooltip', m.description);
    end

    switch widget
        case 'toggle'
            if isempty(dflt)
                % No stated default: no checkbox state means "untouched", so
                % keep the item that says it.
                h = uidropdown(parent, 'Position', [CTRL_X y 170 22], ...
                    'Items', {'Default', 'On', 'Off'}, ...
                    'ItemsData', {[], true, false}, ...
                    'Tooltip', m.description, ...
                    'ValueChangedFcn', @(src, ~) onChange(m.key, src.Value));
                if ~isempty(val); h.Value = asLogical(val); end
            else
                shown = dflt;
                if ~isempty(val); shown = asLogical(val); end
                h = uicheckbox(parent, 'Position', [12 y W-36 22], 'Text', lbl, ...
                    'Tooltip', m.description, 'Value', shown, ...
                    'ValueChangedFcn', @(src, ~) ...
                        onChange(m.key, unsetIfDefault(src.Value, dflt)));
            end

        case 'multiselect'
            % Unset shows EVERYTHING selected, because that is what unset
            % does: no subset named means every item is used. Selecting them
            % all again therefore reports absence, exactly as choosing a
            % dropdown's default does.
            %
            % An empty selection also means unset rather than "none". The two
            % are indistinguishable to the onChange contract, where an empty
            % value IS the signal to drop the field, and the state it would
            % buy - a TEP-topo grid with no maps - is a plot the catalogue
            % already offers three other ways. One fewer ambiguous state is
            % worth more than reaching it from here.
            choices = choicesOf(m, context);
            uilabel(parent, 'Position', [12 rowTop-26 LABEL_W 22], 'Text', lbl, ...
                    'Tooltip', m.description);
            h = uilistbox(parent, ...
                'Position', [CTRL_X, rowTop - rowH(k) + 6, W - CTRL_X - 24, rowH(k) - 32], ...
                'Items', choices, 'Multiselect', 'on', ...
                'Tooltip', m.description, ...
                'ValueChangedFcn', @(src, ~) ...
                    onChange(m.key, subsetOrAll(src.Value, choices)));
            h.Value = shownSubset(val, choices);

        case 'choice'
            choices = choicesOf(m, context);
            if isempty(dflt)
                h = uidropdown(parent, 'Position', [CTRL_X y 170 22], ...
                    'Items', [{'Default'}, choices], ...
                    'ItemsData', [{[]}, choices], ...
                    'Tooltip', m.description, ...
                    'ValueChangedFcn', @(src, ~) onChange(m.key, src.Value));
                if ~isempty(val) && ismember(char(val), choices); h.Value = char(val); end
            else
                shown = dflt;
                if ~isempty(val) && ismember(char(val), choices); shown = char(val); end
                h = uidropdown(parent, 'Position', [CTRL_X y 170 22], ...
                    'Items', choices, 'Value', shown, ...
                    'Tooltip', m.description, ...
                    'ValueChangedFcn', @(src, ~) ...
                        onChange(m.key, unsetIfDefault(src.Value, dflt)));
            end

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
    rowTop = rowTop - rowH(k);
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

function s = shownSubset(val, choices)
% What the listbox starts on. An absent value means every item, and anything
% no longer in the list - a window since renamed or deleted - is dropped
% rather than crashing the form.
if isempty(val); s = choices; return; end
if ~iscell(val); val = cellstr(string(val)); end
s = choices(ismember(lower(choices), lower(val)));
if isempty(s); s = choices; end
end

function v = subsetOrAll(selected, choices)
% Report a genuine subset; report absence for "all of them" and for "none of
% them", both of which mean the same as never having touched it.
if ~iscell(selected); selected = cellstr(string(selected)); end
if isempty(selected) || numel(selected) == numel(choices)
    v = [];
else
    v = selected;
end
end

function w = widgetFor(m, context)
if isfield(m, 'widget') && ~isempty(m.widget)
    % The registry asked for a specific control, because inference could not
    % have reached it. Only honoured when the choices actually arrived - a
    % context missing its key would otherwise build an empty listbox with no
    % hint why, where a text field at least still accepts a value.
    w = lower(char(m.widget));
    if ~strcmp(w, 'multiselect') || ~isempty(choicesOf(m, context)); return; end
end
switch lower(char(m.type))
    case 'logical'
        w = 'toggle';
    case 'vector'
        w = 'range';
    case {'scalar', 'integer'}
        w = 'number';
    otherwise
        if ~isempty(choicesOf(m, context)); w = 'choice'; else; w = 'text'; end
end
end

function c = choicesOf(m, context)
% Either the caller supplied this param's list, or validRange already is one.
%
% A validRange written as "a | b | c" is a closed list, so nothing new has to
% be declared in the registry for it to become a dropdown. 'choicesFrom' is for
% the list that cannot be written down in advance.
c = {};
if isfield(m, 'choicesFrom') && ~isempty(m.choicesFrom)
    key = char(m.choicesFrom);
    if isstruct(context) && isfield(context, key) && ~isempty(context.(key))
        c = cellstr(context.(key));
        c = c(:)';
    end
    return
end
if isempty(m.validRange) || ~contains(m.validRange, '|'); return; end
parts = strtrim(strsplit(m.validRange, '|'));
c = parts(~cellfun(@isempty, parts));
end

function d = statedDefault(m, widget)
% The default this control can SHOW as one of its ordinary states, or [] when
% there is none to show. Read from the placeholder, which by convention names
% it - "(on)", "(mean)". Returning [] is what routes the row back to an
% explicit Default item, so a registry entry that names no default, or names
% one outside its own choices, degrades honestly instead of guessing.
d = [];
txt = defaultText(m);
switch widget
    case 'toggle'
        if any(strcmpi(txt, {'on', 'true'}));   d = true;  end
        if any(strcmpi(txt, {'off', 'false'})); d = false; end
    case 'choice'
        if ismember(txt, choicesOf(m, struct())); d = txt; end
end
end

function v = unsetIfDefault(v, dflt)
% Selecting the default is not the same as setting it: report absence, so the
% setting stays out of the struct and keeps following the draw function.
if isequal(v, dflt); v = []; end
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
