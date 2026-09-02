% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_exploreTab
% TEST_EXPLORETAB  The Explore tab's wiring, kept deliberately thin.
%
%   Only what needs the app: that the tab exists, that its plot picker is built
%   from the registry rather than a hand-written list, and that the exits are
%   gated until there is something to export. The layer underneath - grouping,
%   curves, measures, results - is covered without a window in
%   tests/unit/test_exploreLayer.
%
%   Run: runtests('tests/ui/test_exploreTab')
tests = functiontests(localfunctions);
end

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

function test_thePlotPickerComesFromTheRegistry(testCase)
% Adding a plot must not need a change here, so the picker has to be generated.
app = launchApp(testCase);
testCase.verifyEqual(sort(app.ExplorePlotDropDown.ItemsData(:)'), ...
    sort({plotRegistry().name}), ...
    'every registry entry must be offered, and nothing else');
end

function test_unavailablePlotsAreListedWithTheirReason(testCase)
% With no groups nothing can render; the entries must still be visible, with
% the reason, rather than disappearing.
app = launchApp(testCase);
testCase.verifyTrue(all(contains(app.ExplorePlotDropDown.Items, 'Needs')), ...
    'with no data every plot should say what it needs');
end

function test_theExitsAreGatedUntilThereIsAResult(testCase)
app = launchApp(testCase);
for h = [app.ExploreFigureButton, app.ExploreCsvButton, app.ExploreResultsButton]
    testCase.verifyEqual(char(h.Enable), 'off', ...
        sprintf('"%s" must be off with nothing loaded', h.Text));
end
end

function test_theRailStartsOnADefaultRoiAndTheStandardWindows(testCase)
app = launchApp(testCase);
testCase.verifyTrue(contains(app.ExploreRoiSummaryLabel.Text, 'electrodes'));
testCase.verifyEqual(size(app.ExploreWindowsTable.Data, 1), ...
    numel(defaultTEPComponentDefs()), ...
    'the windows the TEP-topo maps and the measures share');
end

function test_windowPolarityIsSettableAndNotGuessedForNewWindows(testCase)
% The peak polarity decides which way a window's peak is read, and it used to
% be unreachable: the define table had three columns, and every user-added
% window was born 'pos'. A user adding an N70 got its peak measured as the
% largest POSITIVE deflection, silently, with no control to correct it.
app = launchApp(testCase);
t   = app.ExploreWindowsTable;

testCase.assertEqual(numel(t.ColumnName), 4, 'the define view must offer polarity');
testCase.verifyEqual(char(t.ColumnName{4}), 'Peak');
testCase.verifyEqual(t.ColumnFormat{4}, {'auto', 'pos', 'neg'}, ...
    'polarity is a closed choice, not free text');

% Editing the cell must reach the window the measures actually read.
feval(t.CellEditCallback, t, struct('Indices', [1 4], 'NewData', 'pos'));
testCase.verifyEqual(windowPolarity(app.exploreWindows(1)), 'pos');

% A new window must not be born with a guessed sign.
feval(app.ExploreWindowsAddButton.ButtonPushedFcn, ...
      app.ExploreWindowsAddButton, []);
n = numel(app.exploreWindows);
testCase.verifyEqual(windowPolarity(app.exploreWindows(n)), 'auto', ...
    'a window nobody has classified must measure the largest absolute peak');
end

function test_bothWindowViewsFitTheRailWithoutScrollingSideways(testCase)
% The rail was 197px and the results view needed 194 of it plus a scrollbar,
% so Peak uV sat behind a horizontal scroll. Both views must now fit.
app = launchApp(testCase);
t   = app.ExploreWindowsTable;
SCROLLBAR = 18;

for mode = {'define', 'results'}
    app.ExploreWindowsModeDropDown.Value = mode{1};
    feval(app.ExploreWindowsModeDropDown.ValueChangedFcn, ...
          app.ExploreWindowsModeDropDown, []);
    testCase.verifyLessThanOrEqual( ...
        sum(cell2mat(t.ColumnWidth)), t.Position(3) - SCROLLBAR, ...
        sprintf('%s view must fit the rail beside a vertical scrollbar', mode{1}));
end
end
