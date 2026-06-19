
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_batchWindowExtract
% TEST_BATCHWINDOWEXTRACT  Tests for the mode-aware batch window extractor.
%   Uses a loadFcn override so no .set files or TESA are required.
%   Run: runtests('tests/integration/test_batchWindowExtract')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r); addpath(fullfile(r, 'src'));
end

function EEG = fakeEEG()
% Minimal epoched EEG: 4 channels, 101 samples (-100..900 ms-ish), 5 trials.
nchan = 4; npnts = 101; ntrials = 5;
EEG.nbchan = nchan;
EEG.trials = ntrials;
EEG.times  = linspace(0, 200, npnts);
EEG.data   = randn(nchan, npnts, ntrials);
labels = {'FC1','FC3','C1','C3'};
for i = 1:nchan; EEG.chanlocs(i).labels = labels{i}; end
end

function w = wins()
w = struct('name', {'early','late'}, 'winStart', {20,100}, 'winEnd', {60,160}, ...
           'polarity', {'neg','pos'});
end

function ld = constLoader(EEG)
ld = @(~) EEG;
end

function test_rowsPerFileTimesWindows_TEP(testCase)
EEG = fakeEEG();
[T, warns] = batchWindowExtract({'a.set','b.set'}, {'FC1','C1'}, 'TEP', wins(), ...
    'loadFcn', constLoader(EEG));
testCase.verifyEqual(height(T), 4);                       % 2 files x 2 windows
testCase.verifyTrue(all(ismember({'peak_ms','peak_uV'}, T.Properties.VariableNames)));
testCase.verifyEmpty(warns);
end

function test_gmfpNeedsNoROI(testCase)
EEG = fakeEEG();
% ROI electrodes that do NOT exist - GMFP spans all channels, so no skip.
[T, warns] = batchWindowExtract({'a.set'}, {'Xz'}, 'GMFP', wins(), ...
    'loadFcn', constLoader(EEG));
testCase.verifyEqual(height(T), 2);
testCase.verifyTrue(all(T.mean_uV >= 0));                 % GMFP is non-negative
testCase.verifyFalse(any(ismember({'peak_ms'}, T.Properties.VariableNames)));
testCase.verifyEmpty(warns);
end

function test_lmfpMissingROISkipsWithWarning(testCase)
EEG = fakeEEG();
[T, warns] = batchWindowExtract({'a.set'}, {'Xz'}, 'LMFP', wins(), ...
    'loadFcn', constLoader(EEG));
testCase.verifyEqual(height(T), 2);                       % NaN rows still emitted
testCase.verifyTrue(all(isnan(T.mean_uV)));
testCase.verifyNotEmpty(warns);
end

function test_loadErrorYieldsNaNRows(testCase)
bad = @(~) error('boom');
[T, warns] = batchWindowExtract({'bad.set'}, {'FC1'}, 'TEP', wins(), 'loadFcn', bad);
testCase.verifyEqual(height(T), 2);
testCase.verifyTrue(all(isnan(T.mean_uV)));
testCase.verifyNotEmpty(warns);
end

function test_csvRoundTrip(testCase)
EEG = fakeEEG();
tmp = [tempname '.csv'];
c = onCleanup(@() delete(tmp));
T = batchWindowExtract({'a.set'}, {'FC1','C1'}, 'TEP', wins(), ...
    'loadFcn', constLoader(EEG), 'csvPath', tmp);
testCase.verifyTrue(isfile(tmp));
Tback = readtable(tmp);
testCase.verifyEqual(height(Tback), height(T));
end
