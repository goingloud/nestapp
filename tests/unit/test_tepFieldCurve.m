
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_tepFieldCurve
% TEST_TEPFIELDCURVE  Unit tests for the TEP/GMFP/LMFP per-file reduction.
%
%   tepFieldCurve backs the Visualizing-tab Plot Type toggle. GMFP must match
%   TESA's GMFA definition exactly (std(mean(EEG.data,3))); LMFP is the same
%   measure restricted to the ROI; TEP is the signed ROI mean.
%
%   Run: runtests('tests/unit/test_tepFieldCurve')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
end

function test_gmfpMatchesTesaFormula(testCase)
% GMFP must equal TESA's tesa_tepextract definition: std(mean(EEG.data,3)).
rng(7);
data = randn(20, 50, 8);
got  = tepFieldCurve(data, [], 'GMFP');
want = std(mean(data, 3));      % exactly TESA's GMFA line
testCase.verifyEqual(got, want, 'AbsTol', 1e-12);
testCase.verifyEqual(size(got), [1 50]);
end

function test_lmfpIsGmfpOverRoiSubset(testCase)
rng(8);
data = randn(20, 50, 8);
roi  = [3 7 11 15];
got  = tepFieldCurve(data, roi, 'LMFP');
want = std(mean(data(roi,:,:), 3));
testCase.verifyEqual(got, want, 'AbsTol', 1e-12);
end

function test_lmfpOverAllChannelsEqualsGmfp(testCase)
rng(9);
data = randn(16, 40, 5);
gmfp = tepFieldCurve(data, [], 'GMFP');
lmfp = tepFieldCurve(data, 1:16, 'LMFP');
testCase.verifyEqual(lmfp, gmfp, 'AbsTol', 1e-12);
end

function test_tepIsSignedRoiMean(testCase)
rng(10);
data = randn(12, 30, 6);
roi  = [2 4 6];
got  = tepFieldCurve(data, roi, 'TEP');
want = mean(mean(data(roi,:,:), 3), 1);
testCase.verifyEqual(got, want, 'AbsTol', 1e-12);
end

function test_gmfpAndLmfpNonNegative(testCase)
rng(11);
data = randn(10, 25, 4);
testCase.verifyTrue(all(tepFieldCurve(data, [], 'GMFP') >= 0));
testCase.verifyTrue(all(tepFieldCurve(data, 1:5, 'LMFP') >= 0));
end

function test_caseInsensitivePlotType(testCase)
rng(12);
data = randn(10, 20, 3);
testCase.verifyEqual(tepFieldCurve(data, [], 'gmfp'), ...
                     tepFieldCurve(data, [], 'GMFP'), 'AbsTol', 1e-12);
end
