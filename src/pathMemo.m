% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [value, refreshed] = pathMemo(sentinel, computeFcn)
% PATHMEMO  Cache an answer about the MATLAB path, keyed on a sentinel function.
%   [value, refreshed] = PATHMEMO(sentinel, computeFcn)
%
%   sentinel    name of a function whose resolution stands for "the thing this
%               answer is about is still installed and reachable"
%   computeFcn  @() -> value, run when the memo is cold or stale
%   value       computeFcn's result, possibly from the cache
%   refreshed   true when computeFcn actually ran
%
%   PATHMEMO('reset')            drops every entry
%   PATHMEMO('reset', sentinel)  drops one entry
%
%   THE POLICY, IN ONE PLACE: a cached answer is valid only while its sentinel
%   still resolves to the SAME FILE it resolved to when the answer was computed.
%
%   That rule exists because three functions each invented their own and two got
%   it wrong the same way. `ensureEeglabReady` returned early on a non-empty
%   `global PLUGINLIST`, which the plugin scan writes and nothing ever clears -
%   so a `restoredefaultpath`, a test using hideFromPath, or a pathdef reset left
%   it reporting "ready" with pop_loadset gone, and the next load died with a
%   bare "Undefined function". `tesaVersion` cached a version behind an opt-in
%   forceRefresh flag callers had to remember. `ensureAaratepOnPath` had the same
%   bug and was patched in isolation. Remembering that setup RAN is not the same
%   as knowing the result is still REACHABLE.
%
%   Keyed on which() rather than exist(...,'file')==2 because which() returns the
%   resolved path, so a SWAPPED install invalidates too - point Preferences at a
%   different EEGLAB, or install a second TESA, and the old answer is discarded
%   rather than silently kept. None of the three hand-rolled caches did that.
%
%   A sentinel that does not resolve after computeFcn ran is stored as a miss, so
%   the next call retries rather than caching a failure forever. That is what
%   makes "EEGLAB is not installed yet, set it in Preferences" recoverable
%   without restarting MATLAB.
%
%   Reset is per-sentinel so a test can invalidate one toolchain without
%   disturbing the others; `clear pathMemo` would drop all three at once, which
%   is what the old per-function `clear ensureAaratepOnPath` effectively did.
%
%   See also: ensureEeglabReady, ensureAaratepOnPath, tesaVersion

persistent keys locs vals

if isempty(keys); keys = {}; locs = {}; vals = {}; end

if ischar(sentinel) && strcmp(sentinel, 'reset')
    if nargin < 2
        keys = {}; locs = {}; vals = {};
    else
        k = find(strcmp(keys, char(computeFcn)), 1);
        if ~isempty(k)
            keys(k) = []; locs(k) = []; vals(k) = [];
        end
    end
    value = []; refreshed = false;
    return
end

sentinel = char(sentinel);
loc      = which(sentinel);
k        = find(strcmp(keys, sentinel), 1);

% A hit needs three things: an entry, a sentinel that still resolves, and the
% same file behind it. Dropping any one of those is how the old caches went bad.
if ~isempty(k) && ~isempty(loc) && strcmp(locs{k}, loc)
    value     = vals{k};
    refreshed = false;
    return
end

value     = callCompute(computeFcn);
refreshed = true;

% Re-probe: computeFcn is usually what PUTS the sentinel on the path, so the
% location to remember is the one that exists now, not the one from before.
loc = which(sentinel);
if isempty(k)
    keys{end+1} = sentinel; locs{end+1} = loc; vals{end+1} = value;
else
    locs{k} = loc; vals{k} = value;
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function value = callCompute(computeFcn)
% Both shapes of caller are supported deliberately. An "ensure" - putting a
% tree on the path - has no value to return, and forcing one would mean
% inventing a meaningless `true`; a reader like tesaVersion has a real one.
% Ask the handle which it is rather than calling it and interpreting the
% failure, so a genuine TooManyOutputs raised INSIDE compute still surfaces.
try
    n = nargout(computeFcn);
catch
    n = 1;      % anonymous or unresolvable: assume it returns something
end

if n == 0
    computeFcn();
    value = [];
else
    value = computeFcn();
end
end
