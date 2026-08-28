% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_ensureEeglabReady
% TEST_ENSUREEEGLABREADY  The one place EEGLAB is brought up.
%
%   Adding the EEGLAB root to the path does not make EEGLAB usable: its own
%   functions live in subfolders and its plugins in plugins/<name>, and none
%   of it resolves until eeglab() has run the path setup and the plugin scan.
%   Anything that probes which() before that - the step picker above all -
%   sees a machine with nothing installed.
%
%   What is pinned here is the decision, not the scan: the fast path when
%   EEGLAB is already up, and the verdict when it cannot be found at all.
%   Actually running eeglab('nogui') is left to the integration suite; a unit
%   test that tore down a live session's path to force it would be worse than
%   the coverage is worth.
%
%   Run: runtests('tests/unit/test_ensureEeglabReady')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
addpath(fullfile(r, 'tests', 'helpers'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function restorePluginList(saved)
global PLUGINLIST %#ok<GVMIS>
PLUGINLIST = saved;
end

function restorePref(name, had, saved)
if had
    setpref('nestapp', name, saved);
elseif ispref('nestapp', name)
    rmpref('nestapp', name);
end
end

% ── already up ────────────────────────────────────────────────────────────

function test_noOpWhenPluginScanHasRun(testCase)
% PLUGINLIST is written by the plugin scan, so a non-empty one means EEGLAB
% is up - however it got that way. Re-running the scan on every call would
% add seconds to a button press.
global PLUGINLIST %#ok<GVMIS>
saved = PLUGINLIST;
testCase.addTeardown(@() restorePluginList(saved));
PLUGINLIST = struct('plugin', {'stub'}, 'version', {'0.0'});

pathBefore = path;
[ok, msg]  = ensureEeglabReady();

testCase.verifyTrue(ok);
testCase.verifyEmpty(msg);
testCase.verifyEqual(path, pathBefore, ...
    'An already-initialised EEGLAB must not be re-scanned or re-added');
end

% ── not installed ─────────────────────────────────────────────────────────

function test_reportsFailureWhenEeglabIsNotFound(testCase)
% The failure has to name Preferences: this is the message the user gets when
% the picker comes up nearly empty, and it is the only pointer to the fix.
global PLUGINLIST %#ok<GVMIS>
savedList = PLUGINLIST;
testCase.addTeardown(@() restorePluginList(savedList));
PLUGINLIST = [];

hadPref   = ispref('nestapp', 'eeglabPath');
savedPref = getpref('nestapp', 'eeglabPath', '');
testCase.addTeardown(@() restorePref('eeglabPath', hadPref, savedPref));
% Point the pref somewhere that cannot rescue the lookup, so the test does
% not depend on whether this machine has EEGLAB installed.
setpref('nestapp', 'eeglabPath', fullfile(tempdir, 'nestapp-no-such-eeglab'));

hidden = hideFromPath('eeglab'); %#ok<NASGU> restored on teardown
testCase.assertEmpty(which('eeglab'), 'could not hide eeglab');

[ok, msg] = ensureEeglabReady();

testCase.verifyFalse(ok);
testCase.verifyNotEmpty(msg);
testCase.verifyTrue(contains(msg, 'Preferences'), ...
    'The message must say where to point nestapp at EEGLAB');
testCase.verifyEmpty(PLUGINLIST, ...
    'A failed init must not leave the session looking initialised');
end
