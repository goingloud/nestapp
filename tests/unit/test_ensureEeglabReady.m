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
%   What is pinned here is the DECISION: the verdict when EEGLAB cannot be
%   found, and - the regression this file exists for - that readiness is judged
%   by probing the function we need rather than by a flag that nothing clears.
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

function setup(testCase) %#ok<INUSD>
% Every test here starts from a cold memo, and leaves one behind, so no test
% inherits a decision another made.
pathMemo('reset', 'pop_loadset');
end

function teardown(testCase) %#ok<INUSD>
pathMemo('reset', 'pop_loadset');
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function restorePref(name, had, saved)
if had
    setpref('nestapp', name, saved);
elseif ispref('nestapp', name)
    rmpref('nestapp', name);
end
end

% ── the regression ────────────────────────────────────────────────────────

function test_aPathResetIsNoticedRatherThanReportedReady(testCase)
% THE BUG THIS FILE EXISTS FOR. Readiness used to be "global PLUGINLIST is
% non-empty". PLUGINLIST is written by the plugin scan and cleared by nothing,
% so a restoredefaultpath - or this very helper - left EEGLAB reporting ready
% with pop_loadset gone, and the next load died with a bare "Undefined
% function". Adding a group in Explore is how the user hit it.
testCase.assumeNotEmpty(which('eeglab'), 'needs EEGLAB installed');

[ok, ~] = ensureEeglabReady();
testCase.assumeTrue(ok, 'needs EEGLAB to come up');
testCase.assumeNotEmpty(which('pop_loadset'));

hidden = hideFromPath('pop_loadset'); %#ok<NASGU> restored on teardown
testCase.assertEmpty(which('pop_loadset'), 'could not hide pop_loadset');

[ok, msg] = ensureEeglabReady();

testCase.verifyTrue(ok, msg);
testCase.verifyNotEmpty(which('pop_loadset'), ...
    ['ensureEeglabReady returned ok while pop_loadset was still gone - ' ...
     'it is trusting a flag instead of probing the path']);
end

% ── already up ────────────────────────────────────────────────────────────

function test_aSecondCallIsFreeWhileTheSentinelStillResolves(testCase)
% Re-running the plugin scan on every call would add seconds to a button
% press, so a warm memo must not touch the path.
testCase.assumeNotEmpty(which('eeglab'), 'needs EEGLAB installed');
[ok, ~] = ensureEeglabReady();
testCase.assumeTrue(ok, 'needs EEGLAB to come up');

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
hadPref   = ispref('nestapp', 'eeglabPath');
savedPref = getpref('nestapp', 'eeglabPath', '');
testCase.addTeardown(@() restorePref('eeglabPath', hadPref, savedPref));
% Point the pref somewhere that cannot rescue the lookup, so the test does
% not depend on whether this machine has EEGLAB installed.
setpref('nestapp', 'eeglabPath', fullfile(tempdir, 'nestapp-no-such-eeglab'));

hidden  = hideFromPath('eeglab');      %#ok<NASGU> restored on teardown
hidden2 = hideFromPath('pop_loadset'); %#ok<NASGU> restored on teardown
testCase.assertEmpty(which('eeglab'), 'could not hide eeglab');

[ok, msg] = ensureEeglabReady();

testCase.verifyFalse(ok);
testCase.verifyNotEmpty(msg);
testCase.verifyTrue(contains(msg, 'Preferences'), ...
    'The message must say where to point nestapp at EEGLAB');
end

function test_aFailureIsRetriedRatherThanRemembered(testCase)
% "EEGLAB is not installed yet" must be recoverable by setting the preference,
% without restarting MATLAB - so a failed attempt may not be cached as an
% answer. Assert the second call re-runs rather than replaying the failure.
hadPref   = ispref('nestapp', 'eeglabPath');
savedPref = getpref('nestapp', 'eeglabPath', '');
testCase.addTeardown(@() restorePref('eeglabPath', hadPref, savedPref));
setpref('nestapp', 'eeglabPath', fullfile(tempdir, 'nestapp-no-such-eeglab'));

hidden  = hideFromPath('eeglab');      %#ok<NASGU>
hidden2 = hideFromPath('pop_loadset'); %#ok<NASGU>
testCase.assertEmpty(which('eeglab'));

testCase.verifyFalse(ensureEeglabReady());
clear hidden   % eeglab is reachable again, as if the user had fixed the pref

[ok, ~] = ensureEeglabReady();
testCase.verifyTrue(ok, ...
    'a cached failure would make a fixed preference need a MATLAB restart');
end
