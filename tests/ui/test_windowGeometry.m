% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_windowGeometry
% TEST_WINDOWGEOMETRY  What the resize handler can only show in a real window.
%
%   Deliberately small: it launches the app, which takes the mouse, so it holds
%   only assertions that need a live figure. Two of its former tests did not -
%   the minimum-size arithmetic and the re-entrancy source check - and they now
%   live in tests/regression/test_windowClamp, where they run in milliseconds
%   and cover far more cases than a handful of drag sizes.
%
%   What remains needs the app:
%
%   1. The window does not drift while idle - only a live figure can show that
%      nothing moves when nothing happens.
%
%   2. The Plot Type radio group clears the topoplot at every size. Its base
%      geometry ran to x=335 while UIAxes2 starts at x=340, and since every
%      component scales by the same factor the base overlap scaled with it. This
%      needs the app because the positions come from createComponents literals
%      and rescaleComponents applies them to real components; there is no data
%      source for them yet to check against.
%
%   Builds the real app, so it needs a display.
%
%   Run: runtests('tests/ui/test_windowGeometry')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
addpath(fullfile(r, 'tests', 'helpers'));
if ~usejava('desktop')
    testCase.assumeFail('No display - skipping GUI geometry test');
end
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── the window must not walk up the screen ────────────────────────────────

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
