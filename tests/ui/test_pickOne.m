% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_pickOne
% TEST_PICKONE  Cancel must be distinguishable from a choice.
%
%   The dialog returns an index or []. The caller opens a file on that index,
%   so a cancel that came back as 1 would open a recording nobody asked for.
%   That is the failure worth a test, and it has three doors: Cancel, the
%   window's X, and an empty list.
%
%   Driven through driveModalDialog, which waits for the dialog's readiness
%   flag rather than sleeping and hoping - and force-closes anything left
%   standing if an action throws, so a broken test cannot wedge the machine
%   behind a modal window.
%
%   Run: runtests('tests/ui/test_pickOne')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
addpath(fullfile(r, 'tests', 'helpers'));
assumeDesktop(testCase);
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function fig = dialogFigure()
fig = findall(0, 'Type', 'figure', 'Name', 'Browse EEG');
if numel(fig) > 1; fig = fig(1); end   % newest only; never aggregate
end

function ask(testCase, act)
driveModalDialog(testCase, @dialogFigure, act);
end

function chooseAndPress(row, buttonText)
fig  = dialogFigure();
list = findall(fig, 'Type', 'uilistbox');
list.Value = row;
btn = findall(fig, 'Type', 'uibutton');
hit = btn(strcmp(arrayfun(@(b) string(b.Text), btn), buttonText));
if isempty(hit)
    error('test:controlNotFound', 'no button labelled "%s"', buttonText);
end
feval(hit(1).ButtonPushedFcn, hit(1), []);
end

% -- tests ----------------------------------------------------------------

function test_anEmptyListReturnsEmptyWithoutOpeningAWindow(testCase)
% No window means nothing to block on, so this one needs no driver.
before = numel(findall(0, 'Type', 'figure'));
testCase.verifyEmpty(pickOne('t', 'p', {}, []));
testCase.verifyEqual(numel(findall(0, 'Type', 'figure')), before, ...
    'an empty list should not leave a window behind');
end

function test_openReturnsTheHighlightedRow(testCase)
labels = {'sub-01_t1.vhdr', 'sub-02_t1.vhdr', 'sub-03_t1.vhdr'};
ask(testCase, @() chooseAndPress(2, 'Open'));
got = pickOne('Browse EEG', 'Which recording?', labels, []);
testCase.verifyEqual(got, 2);
end

function test_cancelDoesNotLookLikeAChoice(testCase)
labels = {'sub-01_t1.vhdr', 'sub-02_t1.vhdr', 'sub-03_t1.vhdr'};
ask(testCase, @() chooseAndPress(2, 'Cancel'));
got = pickOne('Browse EEG', 'Which recording?', labels, []);
testCase.verifyEmpty(got, ...
    'a cancel returning 1 would open a recording nobody asked for');
end

function test_theWindowXDoesNotLookLikeAChoice(testCase)
labels = {'sub-01_t1.vhdr', 'sub-02_t1.vhdr'};
ask(testCase, @() delete(dialogFigure()));
got = pickOne('Browse EEG', 'Which recording?', labels, []);
testCase.verifyEmpty(got);
end
