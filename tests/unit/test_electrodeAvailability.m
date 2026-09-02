
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_electrodeAvailability
% TEST_ELECTRODEAVAILABILITY  Unit tests for the LoadLabels greying core.
%
%   electrodeAvailability is the pure function behind the ROI picker's
%   electrode-button enable/disable logic. These tests pin the regression
%   where buttons greyed out for a previous file selection stayed disabled
%   even after loading a dataset that contains those electrodes again.
%
%   Run: runtests('tests/unit/test_electrodeAvailability')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
end

function test_allPresent_allAvailable(testCase)
elecList  = {'Cz','Fz','Pz'};
labelSets = {{'Cz','Fz','Pz'}, {'Fz','Cz','Pz'}};
got = electrodeAvailability(elecList, labelSets);
testCase.verifyEqual(got, [true true true]);
end

function test_missingFromOneFile_unavailable(testCase)
% Fz is absent from the second file -> not common -> unavailable.
elecList  = {'Cz','Fz','Pz'};
labelSets = {{'Cz','Fz','Pz'}, {'Cz','Pz'}};
got = electrodeAvailability(elecList, labelSets);
testCase.verifyEqual(got, [true false true]);
end

function test_noFilesSelected_allAvailable(testCase)
elecList = {'Cz','Fz','Pz'};
got = electrodeAvailability(elecList, {});
testCase.verifyEqual(got, [true true true]);
end

function test_regression_reinterpolatedFileReenablesElectrode(testCase)
% Regression: a first selection missing Fz makes it unavailable; loading a
% later, fully re-interpolated file that contains Fz again must report it as
% available. Because the function is stateless and exhaustive, the second
% call is unaffected by the first - which is exactly what the GUI relies on
% to re-enable a previously greyed-out button.
elecList = {'Cz','Fz','Pz'};

first  = electrodeAvailability(elecList, {{'Cz','Pz'}});          % Fz missing
testCase.verifyFalse(first(2));

second = electrodeAvailability(elecList, {{'Cz','Fz','Pz'}});     % Fz back
testCase.verifyTrue(second(2));
end

function test_caseInsensitiveMatching(testCase)
% Regression: a button labelled 'FP1' must count as available when the file
% spells the channel 'Fp1' (EEG montages vary in case). A case-sensitive
% match wrongly greyed Fp1/Fp2 even though they were present in every file.
elecList  = {'FP1','FP2','Cz'};
labelSets = {{'Fp1','Fp2','Cz'}, {'FP1','fp2','CZ'}};
got = electrodeAvailability(elecList, labelSets);
testCase.verifyEqual(got, [true true true]);
end

function test_outputIsRowLogicalRegardlessOfInputShape(testCase)
elecList  = {'Cz';'Fz'};                 % column input
labelSets = {{'Cz','Fz'}};
got = electrodeAvailability(elecList, labelSets);
testCase.verifyEqual(size(got), [1 2]);
testCase.verifyTrue(islogical(got));
end
