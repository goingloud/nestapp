
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_computeWindowMeasures
% TEST_COMPUTEWINDOWMEASURES  Unit tests for the per-window mean+peak measure.
%
%   Backs the Analysis-tab windows-of-interest table: a window reports its
%   mean (all modes) and, for TEP, a peak latency/amplitude chosen by polarity.
%
%   Run: runtests('tests/unit/test_computeWindowMeasures')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
end

function test_meanMatchesComputeWindowMean(testCase)
times = 0:10:200;
curve = sin(times/30);
m = computeWindowMeasures(curve, times, 40, 100, 'auto');
testCase.verifyEqual(m.mean, computeWindowMean(curve, times, 40, 100), 'AbsTol', 1e-12);
testCase.verifyTrue(m.found);
end

function test_negPolarityPicksMinimum(testCase)
times = 0:10:100;
curve = [0 -1 -5 -2 0 1 2 1 0 -1 0];   % min -5 at t=20
m = computeWindowMeasures(curve, times, 0, 100, 'neg');
testCase.verifyEqual(m.peakAmp, -5);
testCase.verifyEqual(m.peakLatency, 20);
end

function test_posPolarityPicksMaximum(testCase)
times = 0:10:100;
curve = [0 -1 -5 -2 0 1 2 1 0 -1 0];   % max 2 at t=60
m = computeWindowMeasures(curve, times, 0, 100, 'pos');
testCase.verifyEqual(m.peakAmp, 2);
testCase.verifyEqual(m.peakLatency, 60);
end

function test_autoPicksLargestAbsoluteSigned(testCase)
times = 0:10:100;
curve = [0 -1 -5 -2 0 1 2 1 0 -1 0];   % |max| is 5 (negative) at t=20
m = computeWindowMeasures(curve, times, 0, 100, 'auto');
testCase.verifyEqual(m.peakAmp, -5);
testCase.verifyEqual(m.peakLatency, 20);
end

function test_emptyWindowReturnsNotFoundNaN(testCase)
times = 0:10:100;
curve = times;
m = computeWindowMeasures(curve, times, 11, 19, 'auto');
testCase.verifyFalse(m.found);
testCase.verifyTrue(isnan(m.mean));
testCase.verifyTrue(isnan(m.peakAmp));
end

function test_defaultPolarityIsAuto(testCase)
times = 0:10:100;
curve = [0 -1 -5 -2 0 1 2 1 0 -1 0];
m1 = computeWindowMeasures(curve, times, 0, 100);
m2 = computeWindowMeasures(curve, times, 0, 100, 'auto');
testCase.verifyEqual(m1.peakAmp, m2.peakAmp);
end
