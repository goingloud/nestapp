% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_roiSelectionState
% TEST_ROISELECTIONSTATE  The ROI picker's decisions, without the picker.
%
%   These rules used to be asserted by driving the modal dialog, which is how a
%   test run ended up wedged behind a window that had to be closed by hand: the
%   dialog blocks on uiwait, so an error anywhere in the driving code leaves it
%   open forever. They are all rules about sets of labels, so they belong here.
%   tests/ui/test_roiPicker keeps only what genuinely needs a window.
%
%   Run: runtests('tests/unit/test_roiSelectionState')
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

function names = on(s)
names = s.labels(s.selected);
end

% ── incoming selection ────────────────────────────────────────────────────

function test_currentSelectionIsMatchedCaseInsensitively(testCase)
% An ROI arriving in a file's own spelling must still light up its button.
s = roiSelectionState({'cz', 'PZ', 'fPz'});
testCase.verifyEqual(sort(on(s)), {'Cz', 'FPz', 'Pz'}, ...
    'and it comes back in electrodeList spelling');
end

function test_anEmptyCurrentSelectsNothing(testCase)
s = roiSelectionState({});
testCase.verifyFalse(any(s.selected));
testCase.verifyNumElements(s.labels, 69);
end

function test_anUnknownNameInCurrentIsSimplyNotSelected(testCase)
% Not an error: a saved session may name an electrode this diagram lacks.
s = roiSelectionState({'Cz', 'FT9'});
testCase.verifyEqual(on(s), {'Cz'});
end

% ── availability ──────────────────────────────────────────────────────────

function test_noDataOffersEveryElectrode(testCase)
s = roiSelectionState({}, {});
testCase.verifyTrue(all(s.enabled), ...
    'with nothing loaded the whole diagram is selectable');
end

function test_availabilityRestrictsTheEnabledSet(testCase)
s = roiSelectionState({}, {'Cz', 'Pz', 'F3'});
testCase.verifyEqual(sort(s.labels(s.enabled)), {'Cz', 'F3', 'Pz'});
testCase.verifyEqual(sum(~s.enabled), 66, ...
    'the rest stay on the diagram, greyed');
end

function test_availabilityIsCaseInsensitive(testCase)
s = roiSelectionState({}, {'cz'});
testCase.verifyEqual(s.labels(s.enabled), {'Cz'});
end

% ── partial availability ──────────────────────────────────────────────────

function test_partialMarksWhatSomeFilesHaveAndOthersDoNot(testCase)
% "in every file" and "in no file" are different answers. An electrode in
% some files is a real methodological choice, so it is marked rather than
% lumped in with the genuinely absent.
s = roiSelectionState({}, {'Cz'}, {'Pz'});
testCase.verifyEqual(s.labels(s.enabled),  {'Cz'});
testCase.verifyEqual(s.labels(s.partial),  {'Pz'});
testCase.verifyFalse(any(s.enabled & s.partial), ...
    'an electrode cannot be both in every file and only in some');
end

function test_noOptionalSetMeansNothingIsPartial(testCase)
s = roiSelectionState({}, {'Cz', 'Pz'});
testCase.verifyFalse(any(s.partial));
end

% ── off-diagram channels ──────────────────────────────────────────────────

function test_channelsWithNoDiagramPositionAreOffered(testCase)
% FT9/FT10 are in 32 of this project's 35 recordings and Iz in the other 3;
% none has a spot on the head image. They are legal ROI members, so they are
% OFFERED, not merely named.
s = roiSelectionState({}, {'Cz', 'FT9', 'FT10', 'Iz'});
testCase.verifyEqual(sort(s.offLabels), {'FT10', 'FT9', 'Iz'});
testCase.verifyTrue(all(s.offEnabled), 'the data carries all three');
testCase.verifyFalse(any(s.offSelected), 'none was in the incoming ROI');
end

function test_aFullyPlaceableMontageOffersNothingExtra(testCase)
s = roiSelectionState({}, {'Cz', 'Pz'});
testCase.verifyEmpty(s.offLabels);
end

function test_anIncomingOffDiagramRoiIsCarriedAndPreselected(testCase)
% THE BUG. The off-diagram list is built from `available` UNION `current`, so
% an ROI already holding FT9 keeps it even when nothing is loaded - which is
% what stops the dialog deleting it on accept.
s = roiSelectionState({'Cz', 'FT9'}, {});
testCase.verifyTrue(ismember('FT9', s.offLabels));
testCase.verifyTrue(s.offSelected(strcmp(s.offLabels, 'FT9')));
end

function test_offDiagramChannelsAreNotSilentlyEnabledOnTheDiagram(testCase)
s = roiSelectionState({}, {'FT9'});
testCase.verifyFalse(any(s.enabled), ...
    'nothing on the diagram is available, and FT9 is not on it');
testCase.verifyEqual(s.offLabels, {'FT9'});
end

% ── applyRoiPreset ────────────────────────────────────────────────────────

function test_presetSelectsExactlyItsElectrodes(testCase)
s = roiSelectionState({}, {});
[sel, missing] = applyRoiPreset(s.labels, s.enabled, {'AF3', 'F3', 'FC3'});
testCase.verifyEqual(sort(s.labels(sel)), {'AF3', 'F3', 'FC3'});
testCase.verifyEmpty(missing);
end

function test_presetReplacesRatherThanAddsToTheSelection(testCase)
s = roiSelectionState({'Oz'}, {});
[sel, ~] = applyRoiPreset(s.labels, s.enabled, {'Cz'});
testCase.verifyEqual(s.labels(sel), {'Cz'}, ...
    'applying a named ROI must not leave the previous one switched on');
end

function test_presetReportsWhatItCouldNotApply(testCase)
% The near-coil cluster minus F5 is a different measurement, not a smaller one.
s = roiSelectionState({}, {'AF3', 'F3', 'FC3'});
[sel, missing] = applyRoiPreset(s.labels, s.enabled, ...
                                {'AF3', 'F5', 'F3', 'FC5', 'FC3'});
testCase.verifyEqual(sort(s.labels(sel)), {'AF3', 'F3', 'FC3'});
testCase.verifyEqual(sort(missing), {'F5', 'FC5'});
end

function test_presetCannotSelectAnUnavailableElectrode(testCase)
s = roiSelectionState({}, {'Cz'});
[sel, missing] = applyRoiPreset(s.labels, s.enabled, {'Cz', 'Pz'});
testCase.verifyEqual(s.labels(sel), {'Cz'});
testCase.verifyEqual(missing, {'Pz'});
end

function test_presetMatchingIsCaseInsensitive(testCase)
s = roiSelectionState({}, {});
[sel, missing] = applyRoiPreset(s.labels, s.enabled, {'cz', 'pz'});
testCase.verifyEqual(sort(s.labels(sel)), {'Cz', 'Pz'});
testCase.verifyEmpty(missing);
end

% ── select-all semantics ──────────────────────────────────────────────────

function test_selectAllMeansAllAvailable(testCase)
% The rule the dialog's "Select all available" implements: an electrode the
% data lacks must not enter the ROI, or it cannot be averaged.
s   = roiSelectionState({}, {'Cz', 'F3'});
all = true & s.enabled;
testCase.verifyEqual(sort(s.labels(all)), {'Cz', 'F3'});
end
