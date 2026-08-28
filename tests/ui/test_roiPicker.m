% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_roiPicker
% TEST_ROIPICKER  The ROI dialog's in/out contract.
%
%   roiPicker is modal and blocks on uiwait, so each test arms a timer that
%   presses a button once the dialog is up. Fiddly, but the contract is worth
%   pinning: the picker is now the only way an ROI gets chosen, and the
%   distinction it has to keep is cancel (returns []) versus a deliberately
%   empty selection (returns {}). Collapsing those would make cancelling look
%   like "the user chose no electrodes" and silently clear a good ROI.
%
%   Lives in tests/ui because it opens a window. The montage table and the
%   presets are pure and tested in tests/unit/test_roiMontage.
%
%   Run: runtests('tests/ui/test_roiPicker')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
if ~usejava('desktop')
    testCase.assumeFail('No display - skipping GUI test');
end
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function fig = pickerFigure()
% The newest matching figure only. Returning the whole array would silently
% aggregate across leaked windows, which is how the figure leak this file
% found first showed up: 483 state buttons where there should be 69.
fig = findall(0, 'Type', 'figure', 'Name', 'Select ROI electrodes');
if numel(fig) > 1; fig = fig(1); end
end

function pressLater(testCase, texts)
% Press each named control, in order, once the dialog exists.
t = timer('StartDelay', 0.75, 'ExecutionMode', 'singleShot', ...
          'TimerFcn', @(~, ~) pressNow(texts));
testCase.addTeardown(@() stopAndDelete(t));
start(t);
end

function stopAndDelete(t)
if isvalid(t); stop(t); delete(t); end
end

function pressNow(texts)
fig = pickerFigure();
if isempty(fig); return; end
for k = 1:numel(texts)
    h = findall(fig, 'Type', 'uibutton', '-or', 'Type', 'uistatebutton');
    hit = h(strcmp(get(h, 'Text'), texts{k}));
    if isempty(hit); continue; end
    hit = hit(1);
    if isa(hit, 'matlab.ui.control.StateButton')
        hit.Value = ~hit.Value;
        notifyValueChanged(hit);
    elseif ~isempty(hit.ButtonPushedFcn)
        feval(hit.ButtonPushedFcn, hit, []);
    end
end
end

function notifyValueChanged(h)
if ~isempty(h.ValueChangedFcn)
    feval(h.ValueChangedFcn, h, []);
end
end

% ── the contract ──────────────────────────────────────────────────────────

function test_cancelReturnsEmptyNumericNotEmptyCell(testCase)
pressLater(testCase, {'Cancel'});
sel = roiPicker({'CZ', 'PZ'});
testCase.verifyTrue(isnumeric(sel) && isempty(sel), ...
    'cancel must be distinguishable from choosing no electrodes');
end

function test_acceptReturnsTheIncomingSelectionUnchanged(testCase)
pressLater(testCase, {'Use these electrodes'});
sel = roiPicker({'CZ', 'PZ'});
testCase.verifyTrue(iscell(sel));
testCase.verifyEqual(sort(sel), {'CZ', 'PZ'});
end

function test_clearAllThenAcceptReturnsAnEmptyCell(testCase)
% The other half of the contract: an empty ROI is a legal choice and must come
% back as {}, not as the cancel value.
pressLater(testCase, {'Clear all', 'Use these electrodes'});
sel = roiPicker({'CZ'});
testCase.verifyTrue(iscell(sel) && isempty(sel), ...
    'a deliberately emptied selection is {} - not []');
end

function test_togglingOneElectrodeIsReflected(testCase)
pressLater(testCase, {'CZ', 'Use these electrodes'});
sel = roiPicker({});
testCase.verifyEqual(sel, {'CZ'});
end

function test_applyingAPresetReplacesTheSelection(testCase)
pressLater(testCase, {'Apply preset', 'Use these electrodes'});
sel = roiPicker({'OZ'});
% The dropdown opens on the first preset, the default F3 cluster.
testCase.verifyEqual(sort(sel), sort({'AF3', 'F1', 'F3', 'FC1', 'FC3'}));
end

function test_unavailableElectrodesCannotBeSelectedBySelectAll(testCase)
% "Select all" means all AVAILABLE: an electrode missing from some file must
% not enter the ROI, or it cannot be averaged across the cohort.
pressLater(testCase, {'Select all available', 'Use these electrodes'});
sel = roiPicker({}, {'CZ', 'PZ', 'F3'});
testCase.verifyEqual(sort(sel), {'CZ', 'F3', 'PZ'});
end

function test_availabilityGreysOutTheRest(testCase)
% Missing electrodes stay visible - their absence is information about the
% data - but must not be clickable.
t = timer('StartDelay', 0.75, 'ExecutionMode', 'singleShot', ...
          'TimerFcn', @(~, ~) captureAndClose());
testCase.addTeardown(@() stopAndDelete(t));
start(t);
roiPicker({}, {'CZ'});
enabled = getappdata(groot, 'nestappRoiPickerEnabled');
rmappdata(groot, 'nestappRoiPickerEnabled');
testCase.assertNotEmpty(enabled);
testCase.verifyEqual(enabled.nOn, 1, 'only CZ is available');
testCase.verifyEqual(enabled.nTotal, 69, 'the rest stay on the diagram');
end

function captureAndClose()
fig = pickerFigure();
if isempty(fig); return; end
h = findall(fig, 'Type', 'uistatebutton');
setappdata(groot, 'nestappRoiPickerEnabled', ...
    struct('nOn', sum(strcmp(get(h, 'Enable'), 'on')), 'nTotal', numel(h)));
btn = findall(fig, 'Type', 'uibutton');
hit = btn(strcmp(get(btn, 'Text'), 'Cancel'));
if ~isempty(hit); feval(hit(1).ButtonPushedFcn, hit(1), []); end
end
