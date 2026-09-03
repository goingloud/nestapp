% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [value, refreshed] = pathMemo(sentinel, computeFcn)
% PATHMEMO  Cache an answer about the MATLAB path, keyed on a sentinel function.
%   [value, refreshed] = PATHMEMO(sentinel, computeFcn)
%   PATHMEMO(sentinel, [])                       drop the entry
%
%   sentinel    name of a function whose resolution stands for "the thing this
%               answer is about is still installed and reachable"
%   computeFcn  @() -> value, run when the memo is cold or stale. [] instead
%               invalidates the entry and computes nothing.
%   value       computeFcn's result, possibly from the cache
%   refreshed   true when computeFcn actually ran
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
%   Invalidation is per-sentinel and is meant to be reached through the function
%   that owns the sentinel (ensureAaratepOnPath('reset'), tesaVersion(true)),
%   not by callers naming it themselves.
%
%   See also: ensureEeglabReady, ensureAaratepOnPath, tesaVersion

persistent memo
if isempty(memo)
    memo = struct('key', {}, 'loc', {}, 'val', {});
end

sentinel = char(sentinel);
k        = find(strcmp({memo.key}, sentinel), 1);

if isempty(computeFcn)
    if ~isempty(k); memo(k) = []; end
    value = []; refreshed = false;
    return
end

% A hit needs three things: an entry, a sentinel that still resolves, and the
% same file behind it. Dropping any one of those is how the old caches went bad.
loc = which(sentinel);
if ~isempty(k) && ~isempty(loc) && strcmp(memo(k).loc, loc)
    value     = memo(k).val;
    refreshed = false;
    return
end

value     = computeFcn();
refreshed = true;

% Re-probe: computeFcn is usually what PUTS the sentinel on the path, so the
% location to remember is the one that exists now, not the one from before.
entry = struct('key', sentinel, 'loc', which(sentinel), 'val', {value});
if isempty(k)
    memo(end+1) = entry;
else
    memo(k) = entry;
end
end
