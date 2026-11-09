% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [params, notes] = migrateStepParams(regEntry, params)
% MIGRATESTEPPARAMS  Saved settings, converted to a schema-2 step's typed values.
%   [params, notes] = MIGRATESTEPPARAMS(regEntry, params)
%
%   Pipelines and templates saved before a step moved to typed settings carry
%   the text the old table produced: 'on'/'yes', '[]', {''}, a number as text,
%   a choice in any capitalisation. This converts them, per setting, using the
%   setting's own declaration:
%     logical  'on' 'yes' 'true' 1 -> true;  'off' 'no' 'false' 0 -> false
%     choices  matched to a key, ignoring case and spacing (matchesChoice)
%     modes    a mode key is kept; an empty legacy value becomes the mode
%              that passes [] upstream - which is exactly what the empty
%              value passed before, so the run does not change
%     numbers / lists   parsed from text (convertParam); {''} becomes {}
%   Keys a step renamed or merged, or values it re-encoded, are rewritten
%   first by the step's own 'legacy' function, declared beside it in
%   stepRegistry.
%
%   Idempotent: typed values pass through unchanged, so it is safe to run on
%   every load AND again at dispatch (which is what makes a hand-written or
%   scripted spec in the old spelling still run). A value it cannot read falls
%   back to the default and says so in notes, rather than guessing.
%
%   Schema-1 steps are returned untouched.
%
%   See also: toUpstream, specFromSaved, processOneFile, canonicalStepName

notes = {};
if fieldOr(regEntry, 'schema', 1) < 2 || ~isstruct(params), return; end
legacy = fieldOr(regEntry, 'legacy', []);
if ~isempty(legacy), [params, notes] = legacy(params); end
for m = regEntry.params(:)'
    if ~isfield(params, m.key), continue; end
    dflt = [];
    if isfield(regEntry.defaults, m.key), dflt = regEntry.defaults.(m.key); end
    [params.(m.key), note] = typed(m, params.(m.key), dflt);
    if ~isempty(note)
        notes{end+1} = sprintf('%s: %s', m.friendlyName, note); %#ok<AGROW>
    end
end
end

% ---------------------------------------------------------------------------

function [v, note] = typed(m, v, dflt)
note = '';
if isstring(v), v = char(v); end
if iscell(v) && isscalar(v) && ischar(v{1}) && ~strcmp(m.type, 'stringlist'), v = v{1}; end

if ~isempty(m.modes)
    if ischar(v)
        ix = find(arrayfun(@(c) matchesChoice(v, c.key), m.modes), 1);
        if ~isempty(ix), v = m.modes(ix).key; return; end
    end
    if ~paramHasValue(v)
        ix = find(arrayfun(@(c) isempty(c.emit), m.modes), 1);
        if isempty(ix), v = dflt; else, v = m.modes(ix).key; end
        return
    end
    v = asType(m, v);
    return
end

if ~isempty(m.choices)
    ix = find(arrayfun(@(c) matchesChoice(v, c.key), m.choices), 1);
    if isempty(ix)
        note = sprintf('"%s" is not an option; using "%s".', textOf(v), textOf(dflt));
        v = dflt;
    else
        v = m.choices(ix).key;
    end
    return
end

if strcmp(m.type, 'logical')
    if islogical(v) && isscalar(v), return; end
    if isnumeric(v) && isscalar(v) && any(v == [0 1]), v = logical(v); return; end
    t = lower(strtrim(textOf(v)));
    if any(strcmp(t, {'on', 'yes', 'true', '1'}))
        v = true;
    elseif any(strcmp(t, {'off', 'no', 'false', '0'}))
        v = false;
    else
        note = sprintf('"%s" is not on or off; using the default.', t);
        v = dflt;
    end
    return
end

v = asType(m, v);
end

function v = asType(m, v)
if any(strcmp(m.type, {'scalar', 'integer', 'vector', 'stringlist'}))
    v = convertParam(v, m.type);
end
if strcmp(m.type, 'stringlist') && iscell(v)
    v = v(~cellfun(@(s) isempty(strtrim(char(s))), v));
    v = reshape(cellfun(@char, v, 'UniformOutput', false), 1, []);
end
end

function s = textOf(v)
if ischar(v), s = v;
elseif isstring(v), s = char(v);
elseif isnumeric(v) || islogical(v), s = mat2str(v);
else, s = class(v);
end
end

