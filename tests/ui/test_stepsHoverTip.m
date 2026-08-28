% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_stepsHoverTip
% TEST_STEPSHOVERTIP  The Steps tree's dwell-delayed legend.
%
%   The legend appears only after the pointer has rested on the tree, and any
%   movement hides it and restarts the clock. That is driven by a singleShot
%   timer restarted from WindowButtonMotionFcn, not by the native Tooltip -
%   MATLAB's own tooltip fires on a schedule that cannot be delayed.
%
%   The show/hide path is exercised here by calling the handlers directly.
%   The full gesture needs the real cursor moved across the screen, which
%   would yank the mouse out from under whoever is running the suite, so that
%   is left to manual checking; what is pinned here is everything that can
%   break silently - the delay, the wiring, and the timer's lifetime.
%
%   Run: runtests('tests/ui/test_stepsHoverTip')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
addpath(fullfile(r, 'tests', 'helpers'));
assumeDesktop(testCase);
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── configuration ─────────────────────────────────────────────────────────

function test_dwellIsThreeSecondsAndSingleShot(testCase)
app = launchApp(testCase);
testCase.assertNotEmpty(app.hoverTimer, 'The dwell timer must exist');
testCase.verifyEqual(app.hoverTimer.StartDelay, 3, ...
    'The tip must wait three seconds of stillness');
testCase.verifyEqual(char(app.hoverTimer.ExecutionMode), 'singleShot', ...
    'A repeating timer would re-show the tip without a new dwell');
end

function test_motionCallbackIsWired(testCase)
% Without this the clock never restarts and the tip never appears.
app = launchApp(testCase);
testCase.verifyNotEmpty(app.UIFigure.WindowButtonMotionFcn, ...
    'WindowButtonMotionFcn drives the dwell timer');
end

function test_nativeTooltipIsNotUsed(testCase)
% Both at once would mean two tips with different delays, and the native one
% cannot be delayed - which is the whole reason for the custom tip.
app = launchApp(testCase);
testCase.verifyEmpty(app.StepsTree.Tooltip, ...
    'The native tooltip must stay empty; the dwell timer owns the legend');
end

function test_tipStartsHidden(testCase)
app = launchApp(testCase);
testCase.verifyEqual(app.StepsTipPanel.Visible, matlab.lang.OnOffSwitchState('off'));
end

% ── content and placement ─────────────────────────────────────────────────

function test_legendNamesTheDotAndCountsIt(testCase)
app = launchApp(testCase);
txt = app.StepsTipLabel.Text;
testCase.verifyTrue(contains(txt, 'amber dot', 'IgnoreCase', true), ...
    'The legend must explain the dot');
testCase.verifyTrue(contains(txt, 'Parallel Processing'), ...
    'The legend must say why a waiting step matters');
testCase.verifyTrue(contains(txt, '6'), ...
    'The legend states how many steps carry the dot');
end

function test_tipFitsItsText(testCase)
% A box too short silently clips the last line, which is how the first
% version shipped-and-was-caught.
app = launchApp(testCase);
panel = app.StepsTipPanel.Position;
label = app.StepsTipLabel.Position;
testCase.verifyLessThanOrEqual(label(1) + label(3), panel(3), ...
    'The label must fit inside the panel horizontally');
testCase.verifyLessThanOrEqual(label(2) + label(4), panel(4), ...
    'The label must fit inside the panel vertically');
testCase.verifyGreaterThanOrEqual(panel(4), 78, ...
    'The wrapped legend needs roughly this much height at this width');
end

% ── lifetime ──────────────────────────────────────────────────────────────

function test_timerIsDestroyedWithTheApp(testCase) %#ok<INUSD>
% A surviving timer would fire against a deleted app.
before = numel(timerfind('Name', 'nestappStepsHover'));
app = nestapp;
drawnow;
during = numel(timerfind('Name', 'nestappStepsHover'));
delete(app);
after = numel(timerfind('Name', 'nestappStepsHover'));

assert(during == before + 1, 'The app should own exactly one dwell timer');
assert(after == before, 'The dwell timer must be deleted with the app');
end
