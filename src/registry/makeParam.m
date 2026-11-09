% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function p = makeParam(key, friendlyName, unit, validRange, description, varargin)
% MAKEPARAM  One parameter's metadata, for any registry that has parameters.
%   p = MAKEPARAM(key, friendlyName, unit, validRange, description, ...)
%
%   Optional name-value pairs:
%     'placeholder' - shown in a text field left empty, e.g. '(all channels)'.
%                     By convention it starts with '(' so it reads as a hint,
%                     and it should NAME THE DEFAULT where there is one -
%                     that keeps the default itself in exactly one place (the
%                     function that applies it) while still telling the reader
%                     what leaving the cell alone will do.
%     'type'        - scalar (default) | integer | vector | logical | string |
%                     stringlist | folder | file. folder/file behave exactly as
%                     string; they record that the value is a path.
%     'required'    - true when the owner cannot run until the user supplies a
%                     value. Used to prompt on load rather than letting the run
%                     fail later, and kept as data here so the check is not
%                     hardcoded in the GUI.
%     'choicesFrom' - name of a CONTEXT key supplying this param's choices, for
%                     a list that is not knowable when the registry is written.
%                     "Which windows to map" is the case: the windows are the
%                     ones in the user's table right now, so they cannot be a
%                     validRange. The form is handed a context struct and reads
%                     the named field from it. In the step settings form,
%                     'channels' gives a channel list the chooser picks from
%                     (the field may hold a function that returns the list).
%
%   Typed settings (steps with schema 2; see docs/ui-design-language.md):
%     'choices'     - N x 3 cell {key, label, help}: a closed list. key is the
%                     value stored AND passed upstream; label is what the user
%                     reads; help is one line shown in the help pane.
%     'modes'       - N x 3 (or x 4) cell {key, label, help[, emit]}: named
%                     states of a setting that otherwise takes a value - "Off",
%                     "Automatic", "All channels". A stored char is a mode key;
%                     anything else is the value. emit is what toUpstream passes
%                     for that mode (default []).
%     'valueLabel'  - name of the "set a value" state beside the modes
%                     (default 'Custom').
%     'limits'      - [min max] accepted for a number (Inf allowed).
%     'openMin'     - true when min itself is not allowed (a width > 0).
%     'step'        - allowed values count from min in this step (a spinner's
%                     step): from 2 in steps of 2 is the even numbers.
%     'section'     - heading the setting is grouped under in the form.
%     'advanced'    - true to start folded under "Advanced".
%     'upstream'    - how a logical is passed: 'onoff' | 'yesno' | '01' |
%                     'logical'. Default 'onoff'.
%
%   Lifted out of stepRegistry when plotRegistry needed the same shape. The
%   whole param toolchain - the settings forms (settingsForm, paramForm),
%   convertParam, disabledParamKeys, toUpstream - reads these fields and nothing else,
%   so anything built with this constructor gets the editor for free. A second
%   near-identical struct would have meant those functions quietly
%   supporting two shapes.
%
%   See also: stepRegistry, plotRegistry, settingsForm, convertParam

placeholder = ''; type = 'scalar'; required = false; choicesFrom = '';
choices = {}; modes = {}; valueLabel = 'Custom'; limits = []; openMin = false;
step = []; section = ''; advanced = false; upstream = 'onoff';
if mod(numel(varargin), 2) ~= 0
    error('makeParam:oddArgs', 'Name-value arguments must come in pairs.');
end
for i = 1:2:numel(varargin)
    v = varargin{i+1};
    switch lower(varargin{i})
        case 'placeholder'; placeholder = v;
        case 'type';        type = v;
        case 'required';    required = logical(v);
        case 'choicesfrom'; choicesFrom = v;
        case 'choices';     choices = v;
        case 'modes';       modes = v;
        case 'valuelabel';  valueLabel = v;
        case 'limits';      limits = v;
        case 'openmin';     openMin = logical(v);
        case 'step';        step = v;
        case 'section';     section = v;
        case 'advanced';    advanced = logical(v);
        case 'upstream';    upstream = v;
        otherwise
            error('makeParam:unknownOpt', 'Unknown option "%s".', varargin{i});
    end
end
p = struct('key',key,'friendlyName',friendlyName,'unit',unit, ...
           'validRange',validRange,'description',description, ...
           'placeholder',placeholder,'type',type,'required',required, ...
           'choicesFrom',choicesFrom, 'choices',{asRows(choices, 3)}, ...
           'modes',{asRows(modes, 4)}, 'valueLabel',valueLabel, ...
           'limits',limits, 'openMin',openMin, 'step',step, ...
           'section',section, 'advanced',advanced, 'upstream',upstream);
end

function s = asRows(c, width)
% {key, label, help[, emit]} rows -> struct array; a missing column is empty.
s = struct('key', {}, 'label', {}, 'help', {}, 'emit', {});
for r = 1:size(c, 1)
    row = [c(r, :), cell(1, width - size(c, 2))];
    if numel(row) < 4, row{4} = []; end
    s(r) = struct('key', row{1}, 'label', row{2}, 'help', row{3}, 'emit', row(4));
end
end
