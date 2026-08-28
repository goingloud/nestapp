% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_windowGeometry
% TEST_WINDOWGEOMETRY  Regression tests for the resize handler's geometry.
%
%   Two confirmed bugs are pinned here.
%
%   1. The window walked up the screen. UIFigureSizeChanged enforced a minimum
%      size by assigning UIFigure.Position(3:4), which anchors [left bottom],
%      so restoring a height from a raised bottom lifted the whole window.
%      Repeated over a stream of resize events it marched off the top of the
%      monitor at a constant size. The minimum is now applied by writing the
%      full Position with the top edge pinned.
%
%   2. The Plot Type radio group overlapped the topoplot axes. Its base
%      geometry ran to x=335 while UIAxes2 starts at x=340; since every
%      component scales by the same factor, the base overlap scaled with it.
%      The group is 185 px wide (was 195) so the gap is positive at any size.
%
%   Builds the real app, so it needs a display.
%
%   Run: runtests('tests/regression/test_windowGeometry')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
if ~usejava('desktop')
    testCase.assumeFail('No display - skipping GUI geometry test');
end
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function app = launchApp(testCase)
app = nestapp;
testCase.addTeardown(@() delete(app));
drawnow;
end

% ── the window must not walk up the screen ────────────────────────────────

function test_clampDoesNotMoveTheWindow(testCase)
% Shrink from the bottom edge (bottom rises, height falls) past the minimum.
% The clamp must restore the height downward, holding the top edge, not push
% the window up the screen.
app = launchApp(testCase);
app.UIFigure.Position = [100 100 867 500];
drawnow; drawnow;
topBefore = sum(app.UIFigure.Position([2 4]));

for k = 1:6
    p = app.UIFigure.Position;
    app.UIFigure.Position = [p(1), p(2) + 40, p(3), p(4) - 40];
    drawnow; drawnow;
end

pos = app.UIFigure.Position;
testCase.verifyEqual(sum(pos([2 4])), topBefore, 'AbsTol', 1, ...
    'The window top edge must not climb when the minimum size is enforced');
testCase.verifyGreaterThanOrEqual(pos(4), 420, 'Minimum height must hold');
end

function test_idleWindowDoesNotDrift(testCase)
% Nothing may move the window when no resize is happening. A resize handler
% that re-enters itself would show up here as steady drift.
app = launchApp(testCase);
before = app.UIFigure.Position;
for k = 1:10
    drawnow;
end
testCase.verifyEqual(app.UIFigure.Position, before, ...
    'The window must not move on its own');
end

function test_resizeHandlerGuardsReentry(testCase) %#ok<INUSD>
% Source check: the clamp writes Position, which re-fires the callback, and
% the drawnow inside lets that re-entry run. The guard is what stops the two
% feeding each other.
src = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m'));
assert(contains(src, 'if app.isResizing; return; end'), ...
    'UIFigureSizeChanged must refuse to re-enter itself');
assert(~contains(src, 'app.UIFigure.Position(3:4) = newSize'), ...
    'The minimum size must not be applied by assigning Position(3:4) alone');
end

% ── the Plot Type group must clear the topoplot at every size ─────────────

function test_plotTypeGroupNeverOverlapsTopoplot(testCase)
app = launchApp(testCase);
sizes = [867 549; 650 420; 1700 900; 1900 560; 2400 700];
for k = 1:size(sizes, 1)
    app.UIFigure.Position(3:4) = sizes(k, :);
    drawnow; drawnow;
    groupRight = app.PlotTypeButtonGroup.Position(1) + app.PlotTypeButtonGroup.Position(3);
    axesLeft   = app.UIAxes2.Position(1);
    testCase.verifyLessThan(groupRight, axesLeft, sprintf( ...
        'Plot Type group must clear the topoplot at %dx%d', sizes(k,1), sizes(k,2)));

    modeRight = app.PlottingModeButtonGroup.Position(1) + app.PlottingModeButtonGroup.Position(3);
    testCase.verifyLessThan(modeRight, axesLeft, sprintf( ...
        'Plotting Mode group must clear the topoplot at %dx%d', sizes(k,1), sizes(k,2)));
end
end

function test_selectedStepsButtonsSpanTheirColumn(testCase)
% The four buttons under Selected Steps must stay flush with the listbox
% column at any size, not huddle on its left.
app = launchApp(testCase);
sizes = [867 549; 650 420; 1700 900];
for k = 1:size(sizes, 1)
    app.UIFigure.Position(3:4) = sizes(k, :);
    drawnow; drawnow;
    lb = app.SelectedListBox.Position;
    leftMost  = min(app.AddButton.Position(1), app.RemoveButton.Position(1));
    rightMost = max(app.MoveUpButton.Position(1)   + app.MoveUpButton.Position(3), ...
                    app.MoveDownButton.Position(1) + app.MoveDownButton.Position(3));
    testCase.verifyEqual(leftMost, lb(1), 'AbsTol', 2, sprintf( ...
        'Buttons must be flush with the listbox left at %dx%d', sizes(k,1), sizes(k,2)));
    testCase.verifyEqual(rightMost, lb(1) + lb(3), 'AbsTol', 2, sprintf( ...
        'Buttons must be flush with the listbox right at %dx%d', sizes(k,1), sizes(k,2)));
end
end
