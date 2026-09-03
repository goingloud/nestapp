% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [ok, reason] = plotAvailability(entry, ctx)
% PLOTAVAILABILITY  Can this plot be drawn with what is currently loaded?
%   [ok, reason] = PLOTAVAILABILITY(entry, ctx) evaluates one plotRegistry
%   entry against the current state and returns whether it can render, plus a
%   sentence saying what is missing when it cannot.
%
%   ctx fields (all optional, all defaulting to "not available"):
%     .nGroups     number of groups currently defined
%     .hasWindows  true when at least one window of interest exists
%     .hasChanlocs true when the montage carries electrode positions
%
%   reason is written for the user, not the log: it names the shortfall and the
%   remedy in one line ("Needs exactly 2 groups; there are 3"), because it is
%   shown next to the greyed-out entry in the picker. A plot that cannot run is
%   greyed WITH this reason rather than hidden, for the same reason
%   availableSteps withholds steps loudly: a feature that vanishes silently
%   looks like a missing feature, and the user has no way to discover that two
%   groups would bring it back.
%
%   The draw function is probed with exist() as well. That is the direct
%   analogue of stepAvailability's which() check on a plugin function, and it
%   means a registry entry whose implementation has not landed yet degrades to
%   "unavailable" rather than erroring when clicked.
%
%   See also: plotRegistry, availablePlots, stepAvailability

if nargin < 2; ctx = struct(); end
ctx = fillDefaults(ctx, ...
    struct('nGroups', 0, 'hasWindows', false, 'hasChanlocs', false));

req = entry.requires;

% The drawing function must actually exist on the path.
if isempty(entry.draw) || exist(entry.draw, 'file') ~= 2
    ok     = false;
    reason = sprintf('Not implemented in this build (%s is missing).', entry.draw);
    return
end

% Group arity.
[ok, reason] = groupsSatisfied(req.groups, ctx.nGroups);
if ~ok; return; end

if req.windows && ~ctx.hasWindows
    ok     = false;
    reason = 'Needs at least one window of interest; add one in the Windows list.';
    return
end

if req.chanlocs && ~ctx.hasChanlocs
    ok     = false;
    reason = ['Needs electrode positions, which the loaded files do not ' ...
              'carry. Add a channel location file when cleaning.'];
    return
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function [ok, reason] = groupsSatisfied(rule, n)
ok = true; reason = '';
if ischar(rule) || isstring(rule)
    switch lower(char(rule))
        case 'any'
            need = 1; kind = 'atleast';
        case '2+'
            need = 2; kind = 'atleast';
        otherwise
            error('nestapp:badGroupRule', ...
                  'Unknown group requirement ''%s''.', char(rule));
    end
else
    need = rule; kind = 'exact';
end

switch kind
    case 'exact'
        if n ~= need
            ok     = false;
            reason = sprintf('Needs exactly %d group%s; there %s %d.', ...
                             need, plural(need), isAre(n), n);
        end
    case 'atleast'
        if n < need
            ok     = false;
            reason = sprintf('Needs at least %d group%s; there %s %d.', ...
                             need, plural(need), isAre(n), n);
        end
end
end
