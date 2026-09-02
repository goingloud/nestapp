% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_pickOne
% TEST_PICKONE  Cancel must be distinguishable from a choice.
%
%   The dialog returns an index or []. The caller opens a file on an index,
%   so a cancel that came back as 1 would open a recording nobody asked for.
%   That is the one failure worth a test, and it has three doors: Cancel, the
%   window's X, and an empty list.
%
%   The dialog blocks in waitfor, so these drive it the way the other modal
%   tests do: build it on a timer-free path by invoking the callbacks the
%   controls carry, rather than by clicking.
%
%   Run: runtests('tests/unit/test_pickOne')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('pickOne'));
end

function test_anEmptyListReturnsEmptyWithoutOpeningAWindow(testCase)
% No window means no waitfor, so this one can be called directly.
before = numel(findall(0, 'Type', 'figure'));
testCase.verifyEmpty(pickOne('t', 'p', {}, []));
testCase.verifyEqual(numel(findall(0, 'Type', 'figure')), before, ...
    'an empty list should not leave a window behind');
end

function test_openReturnsTheSelectedIndexAndCancelReturnsEmpty(testCase)
% Drive the dialog from a timer, because pickOne blocks in waitfor.
labels = {'sub-01_t1.vhdr', 'sub-02_t1.vhdr', 'sub-03_t1.vhdr'};

got = driveDialog(testCase, labels, @(fig) chooseAndConfirm(fig, 2, 'Open'));
testCase.verifyEqual(got, 2, 'Open should hand back the highlighted row');

got = driveDialog(testCase, labels, @(fig) chooseAndConfirm(fig, 2, 'Cancel'));
testCase.verifyEmpty(got, 'Cancel must not look like a choice');

got = driveDialog(testCase, labels, @(fig) delete(fig));
testCase.verifyEmpty(got, 'the window X must not look like a choice');
end

% -- helpers --------------------------------------------------------------

function out = driveDialog(testCase, labels, action)
t = timer('StartDelay', 1.5, 'ExecutionMode', 'singleShot', ...
          'TimerFcn', @(~,~) actOnDialog(action));
% A net, so a failure to find the dialog cannot wedge the test session.
net = timer('StartDelay', 20, 'ExecutionMode', 'singleShot', ...
            'TimerFcn', @(~,~) delete(findall(0, 'Type', 'figure', 'Name', 'Browse Raw EEG')));
testCase.addTeardown(@() stopTimer(t));
testCase.addTeardown(@() stopTimer(net));
start(t); start(net);
out = pickOne('Browse Raw EEG', 'Which recording?', labels, []);
stopTimer(t); stopTimer(net);
end

function actOnDialog(action)
fig = findall(0, 'Type', 'figure', 'Name', 'Browse Raw EEG');
if isempty(fig); return; end
action(fig(1));
end

function chooseAndConfirm(fig, row, buttonText)
list = findall(fig, 'Type', 'uilistbox');
list.Value = row;
btn = findall(fig, 'Type', 'uibutton');
hit = btn(strcmp(arrayfun(@(b) string(b.Text), btn), buttonText));
feval(hit(1).ButtonPushedFcn, hit(1), []);
end

function stopTimer(t)
if isa(t, 'timer') && isvalid(t); stop(t); delete(t); end
end
