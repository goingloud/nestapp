% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_windowClamp
% TEST_WINDOWCLAMP  The minimum-size clamp must not move the window.
%
%   The bug: the app window crept upward across the monitor until it left the
%   screen, at a constant size. Position measures `bottom` from the bottom of
%   the screen, so restoring width and height alone anchors the bottom-left
%   corner and grows the window UPWARD; over a stream of resize events that
%   ratchets.
%
%   These were tests that never needed a window. The rule is arithmetic on four
%   numbers, so it is checked here - which also means every interesting case can
%   be covered, instead of the handful of sizes someone thought to drag to in a
%   live app. tests/ui keeps one wiring check that the handler actually calls it.
%
%   Also here, and equally window-free: the re-entrancy guard, a source check
%   that had been filed under tests/ui despite opening nothing.
%
%   Run: runtests('tests/regression/test_windowClamp')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function top = topEdge(pos)
top = pos(2) + pos(4);
end

% ── the clamp ─────────────────────────────────────────────────────────────

function test_aWindowAlreadyBigEnoughIsUntouched(testCase)
% The important half: an ordinary resize must not write Position at all, or the
% write re-fires the size-changed callback.
pos = [100 200 900 600];
[newPos, changed] = clampWindowPosition(pos, [650 420]);
testCase.verifyEqual(newPos, pos);
testCase.verifyFalse(changed, 'no write means no re-entry');
end

function test_exactlyAtTheMinimumIsUntouched(testCase)
pos = [10 20 650 420];
[newPos, changed] = clampWindowPosition(pos, [650 420]);
testCase.verifyEqual(newPos, pos);
testCase.verifyFalse(changed);
end

function test_clampingHeightPinsTheTopEdge(testCase)
% The regression. Growing the height back must push the bottom DOWN, not lift
% the window.
pos = [100 500 900 300];
[newPos, changed] = clampWindowPosition(pos, [650 420]);
testCase.verifyTrue(changed);
testCase.verifyEqual(topEdge(newPos), topEdge(pos), ...
    'the top edge must not move');
testCase.verifyEqual(newPos(4), 420);
testCase.verifyEqual(newPos(2), 380, 'bottom = top - newHeight');
end

function test_clampingWidthDoesNotMoveTheWindow(testCase)
pos = [100 200 400 600];
newPos = clampWindowPosition(pos, [650 420]);
testCase.verifyEqual(newPos(1), pos(1), 'left is never touched');
testCase.verifyEqual(newPos(2), pos(2), ...
    'a width-only clamp must leave bottom alone');
testCase.verifyEqual(newPos(3), 650);
end

function test_clampingBothDimensionsStillPinsTheTop(testCase)
pos = [100 500 300 200];
newPos = clampWindowPosition(pos, [650 420]);
testCase.verifyEqual(topEdge(newPos), topEdge(pos));
testCase.verifyEqual(newPos(3:4), [650 420]);
end

function test_repeatedClampingIsAFixedPoint(testCase)
% This is what "creeping" was: each event moved the window a little. Applying
% the clamp to its own output must change nothing further, however many times.
pos = [100 500 300 200];
first = clampWindowPosition(pos, [650 420]);
p = first;
for k = 1:50
    [p, changed] = clampWindowPosition(p, [650 420]);
    testCase.assertFalse(changed, 'the clamp must settle after one application');
end
testCase.verifyEqual(p, first, 'and never drift');
end

function test_aStreamOfShrinksNeverLiftsTheWindow(testCase)
% The exact shape of the original bug: drag the bottom edge up repeatedly, and
% the clamp restores the height each time. The top must stay put throughout.
pos = [100 600 900 600];
top0 = topEdge(pos);
for k = 1:25
    pos = [pos(1), pos(2) + 40, pos(3), pos(4) - 40];   % drag bottom up
    pos = clampWindowPosition(pos, [650 420]);
    testCase.assertLessThanOrEqual(topEdge(pos), top0 + 1, ...
        sprintf('window rose above its starting top edge on event %d', k));
end
end

function test_minSizeIsRespectedAsGiven(testCase)
% The minimum is the caller's, not baked in here.
newPos = clampWindowPosition([0 0 10 10], [200 100]);
testCase.verifyEqual(newPos(3:4), [200 100]);
end

% ── the handler wiring, still checkable from source ───────────────────────

function test_resizeHandlerGuardsReentry(testCase) %#ok<INUSD>
% The clamp writes Position, which re-fires the callback, and the drawnow
% inside lets that re-entry run. The guard is what stops the two feeding each
% other. Moved here from tests/ui, where it had been filed despite opening
% nothing.
src = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m'));
assert(contains(src, 'if app.isResizing; return; end'), ...
    'UIFigureSizeChanged must refuse to re-enter itself');
assert(~contains(src, 'app.UIFigure.Position(3:4) = newSize'), ...
    'The minimum size must not be applied by assigning Position(3:4) alone');
end

function test_tabsAreExcludedFromRescaleByTypeNotByName(testCase) %#ok<INUSD>
% A Tab's Position is read-only, so including one makes the next resize throw.
% The exclusion used to be a hardcoded list of the four tabs that existed, and
% adding a fifth broke resizing until someone dragged the window.
src = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'captureBaseLayout.m'));
assert(contains(src, "isa(h, 'matlab.ui.container.Tab')"), ...
    'tabs must be excluded from the rescale snapshot by type');
assert(~contains(src, "'CleaningTab'"), ...
    'the per-tab name list must be gone, or the next tab breaks resizing again');
end

function test_theAppDelegatesToTheClamp(testCase) %#ok<INUSD>
% Cheap guard against the arithmetic being reinlined into the app, where it
% would stop being testable without a window.
src = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m'));
assert(contains(src, 'clampWindowPosition(app.UIFigure.Position'), ...
    'enforceMinWindowSize must delegate to clampWindowPosition');
end
