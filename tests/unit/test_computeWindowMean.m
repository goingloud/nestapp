
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_computeWindowMean
% TEST_COMPUTEWINDOWMEAN  Unit tests for the windowed-average measurement core.
%
%   computeWindowMean backs the Explore windows table's mean readout that
%   reports the average amplitude of the displayed TEP/GMFP/LMFP curve over a
%   user-adjustable [start end] ms window.
%
%   Run: runtests('tests/unit/test_computeWindowMean')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
end

function test_meanOverInclusiveWindow(testCase)
times = 0:10:100;          % 0,10,...,100
curve = times;             % value == time for an easy mean
% Window [20 40] -> samples 20,30,40 -> mean 30
testCase.verifyEqual(computeWindowMean(curve, times, 20, 40), 30);
end

function test_boundsOrderIndependent(testCase)
times = 0:10:100;
curve = times;
testCase.verifyEqual(computeWindowMean(curve, times, 40, 20), 30);
end

function test_singleSampleWindow(testCase)
times = 0:10:100;
curve = 2 * times;
% Window [50 50] -> only the 50 ms sample -> 100
testCase.verifyEqual(computeWindowMean(curve, times, 50, 50), 100);
end

function test_emptyWindowReturnsNaN(testCase)
times = 0:10:100;
curve = times;
% Window between samples (no time falls in [11 19])
testCase.verifyTrue(isnan(computeWindowMean(curve, times, 11, 19)));
end

function test_windowBeyondDataReturnsNaN(testCase)
times = 0:10:100;
curve = times;
testCase.verifyTrue(isnan(computeWindowMean(curve, times, 200, 300)));
end

function test_ignoresNaNSamples(testCase)
times = 0:10:50;
curve = [0 10 NaN 30 40 50];
% Window [0 30] -> values 0,10,NaN,30 -> mean of {0,10,30} = 13.333..
testCase.verifyEqual(computeWindowMean(curve, times, 0, 30), (0+10+30)/3, ...
    'AbsTol', 1e-12);
end
