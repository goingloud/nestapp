% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_roiPicker
% TEST_ROIPICKER  What the ROI dialog can only be checked by opening.
%
%   Kept deliberately small. An earlier version drove the dialog for every rule
%   it could reach, and wedged MATLAB: the picker is modal and blocks on uiwait,
%   so an error anywhere in the driving code leaves the window open forever and
%   the session has to be rescued by hand. Everything that is a rule about sets
%   of labels now lives in tests/unit/test_roiSelectionState, which opens
%   nothing.
%
%   What is left is the one thing that genuinely needs the window: the return
%   contract. Cancel yields [] and a deliberately emptied selection yields {},
%   and collapsing those would make cancelling look like "the user chose no
%   electrodes" and silently clear a good ROI. That distinction only exists on
%   the way out of the dialog.
%
%   Every test drives it through driveModalDialog, which closes the dialog
%   unconditionally - including when the driving code throws - so a failure here
%   fails the test instead of stopping the machine.
%
%   Run: runtests('tests/ui/test_roiPicker')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
addpath(fullfile(r, 'tests', 'helpers'));
assumeDesktop(testCase);
end

function setup(testCase)
isolateRoiPresets(testCase);
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function fig = pickerFigure()
fig = findall(0, 'Type', 'figure', 'Name', 'Select ROI electrodes');
if numel(fig) > 1; fig = fig(1); end   % newest only; never aggregate
end

function pressLater(testCase, texts)
driveModalDialog(testCase, @pickerFigure, @() press(texts));
end

function press(texts)
fig = pickerFigure();
h      = findall(fig, 'Type', 'uibutton', '-or', 'Type', 'uistatebutton');
labels = get(h, 'Text');
for k = 1:numel(texts)
    hit = h(strcmp(labels, texts{k}));
    if isempty(hit)
        error('test:controlNotFound', 'no control labelled "%s"', texts{k});
    end
    hit = hit(1);
    if isa(hit, 'matlab.ui.control.StateButton')
        hit.Value = ~hit.Value;
        feval(hit.ValueChangedFcn, hit, []);
    else
        feval(hit.ButtonPushedFcn, hit, []);
    end
end
end

function checkNoDialogError(testCase)
% driveModalDialog swallows errors so the dialog always closes; surface them.
testCase.verifyEmpty(testCase.TestData.dialogError, ...
    'the driving code threw - see the captured MException');
end

% ── the return contract ───────────────────────────────────────────────────

function test_cancelReturnsEmptyNumeric(testCase)
pressLater(testCase, {'Cancel'});
sel = roiPicker({'Cz', 'Pz'});
checkNoDialogError(testCase);
testCase.verifyTrue(isnumeric(sel) && isempty(sel), ...
    'cancel must be distinguishable from choosing no electrodes');
end

function test_acceptReturnsACellstrOfCanonicalNames(testCase)
pressLater(testCase, {'Use these electrodes'});
sel = roiPicker({'cz', 'PZ'});
checkNoDialogError(testCase);
testCase.verifyEqual(sort(sel), {'Cz', 'Pz'});
end

function test_clearAllThenAcceptReturnsAnEmptyCell(testCase)
pressLater(testCase, {'Clear all', 'Use these electrodes'});
sel = roiPicker({'Cz'});
checkNoDialogError(testCase);
testCase.verifyTrue(iscell(sel) && isempty(sel), ...
    'a deliberately emptied selection is {} - not []');
end

function test_closingTheWindowCountsAsCancel(testCase)
% The X button and Cancel must agree; otherwise closing the dialog would look
% like an empty ROI was chosen.
driveModalDialog(testCase, @pickerFigure, @() closeIt());
sel = roiPicker({'Cz'});
checkNoDialogError(testCase);
testCase.verifyTrue(isnumeric(sel) && isempty(sel));
end

function closeIt()
fig = pickerFigure();
feval(fig.CloseRequestFcn, fig, []);
end

% ── the harness itself ────────────────────────────────────────────────────

function test_aThrowingDriverStillClosesTheDialog(testCase)
% The regression for the hang. If the driving code errors, the dialog must
% still close and the error must be reported - not left blocking uiwait.
driveModalDialog(testCase, @pickerFigure, @() error('test:boom', 'deliberate'));
sel = roiPicker({'Cz'});
testCase.verifyNotEmpty(testCase.TestData.dialogError, ...
    'the error must be captured');
testCase.verifyEqual(testCase.TestData.dialogError.identifier, 'test:boom');
testCase.verifyTrue(isnumeric(sel) && isempty(sel), ...
    'and the dialog must have closed, returning a cancel');
testCase.verifyEmpty(pickerFigure(), 'no window may be left standing');
end

function test_anOffDiagramElectrodeSurvivesOpeningTheDialog(testCase)
% THE REGRESSION. The accepted ROI used to be rebuilt from the diagram's 69
% labels alone, so opening the picker on an ROI holding FT9 and pressing
% "Use these electrodes" without touching anything DELETED FT9 - silently,
% because the "Not on this diagram" line was computed from what the data
% offered, never from what the ROI already held.
isolateRoiPresets(testCase);
pressLater(testCase, {'Use these electrodes'});
got = roiPicker({'Cz', 'FT9'}, {'Cz', 'FT9'});

testCase.verifyTrue(iscell(got), 'accept must return a cellstr');
testCase.verifyEqual(sort(got), {'Cz', 'FT9'}, ...
    'an electrode the diagram cannot draw is still part of the ROI');
end

function test_anOffDiagramElectrodeCanBeTurnedOff(testCase)
% The other half: it is a real control, not a passenger the dialog carries
% through regardless.
isolateRoiPresets(testCase);
driveModalDialog(testCase, @pickerFigure, @() uncheckThenAccept('FT9'));
got = roiPicker({'Cz', 'FT9'}, {'Cz', 'FT9'});
testCase.verifyEqual(got, {'Cz'});
end

function uncheckThenAccept(name)
fig = pickerFigure();
cb  = findall(fig, 'Type', 'uicheckbox');
hit = cb(strcmp(get(cb, 'Text'), name));
if isempty(hit)
    error('test:controlNotFound', 'no checkbox labelled "%s"', name);
end
hit(1).Value = false;
feval(hit(1).ValueChangedFcn, hit(1), []);
press({'Use these electrodes'});
end
