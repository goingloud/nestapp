% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function a = toUpstream(regEntry, params)
% TOUPSTREAM  A schema-2 step's typed settings, as the upstream function wants them.
%   a = TOUPSTREAM(regEntry, params) returns a struct with one field per
%   setting that applies, in registry order:
%     - a disabled setting (disabledParamKeys) is left out entirely;
%     - a mode key becomes the value that mode passes (its 'emit', default []);
%     - a logical becomes 'on'/'off', 'yes'/'no' or 1/0 per its 'upstream';
%     - everything else passes as stored.
%
%   The step's dispatch then names the fields it passes - never positions,
%   never a test against the text '[]' - so what reaches EEGLAB or TESA is
%   decided here and in one readable call, not by field order.
%
%   See also: migrateStepParams, disabledParamKeys, makeParam, processOneFile

a   = struct();
off = disabledParamKeys(regEntry, params);
for m = regEntry.params(:)'
    if ~isfield(params, m.key) || any(strcmp(m.key, off)), continue; end
    v = params.(m.key);
    if ~isempty(m.modes) && ischar(v)
        ix = find(strcmp(v, {m.modes.key}), 1);
        if ~isempty(ix), v = m.modes(ix).emit; end
    elseif strcmp(m.type, 'logical') && islogical(v)
        switch m.upstream
            case 'yesno', v = char(string(ternary(v, 'yes', 'no')));
            case '01',    v = double(v);
            case 'logical'
            otherwise,    v = char(string(ternary(v, 'on', 'off')));
        end
    end
    a.(m.key) = v;
end
end

function out = ternary(c, x, y)
if c, out = x; else, out = y; end
end
