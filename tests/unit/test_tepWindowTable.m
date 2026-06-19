
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_tepWindowTable
% TEST_TEPWINDOWTABLE  Unit tests for the per-file x per-window results table.
%   Shared schema for the Analysis-tab workspace export and the batch CSV.
%   Run: runtests('tests/unit/test_tepWindowTable')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r); addpath(fullfile(r, 'src'));
end

function w = windows()
w = struct('name', {'A','B'}, 'winStart', {10,50}, 'winEnd', {30,90}, ...
           'polarity', {'neg','pos'});
end

function test_rowCountIsFilesTimesWindows(testCase)
time   = 0:10:100;
curves = [time; 2*time];                 % 2 files
T = tepWindowTable({'f1','f2'}, curves, time, windows(), 'GMFP');
testCase.verifyEqual(height(T), 4);      % 2 files x 2 windows
end

function test_tepHasPeakColumns_othersDoNot(testCase)
time   = 0:10:100;
curves = time;
Ttep = tepWindowTable({'f1'}, curves, time, windows(), 'TEP');
Tgmfp = tepWindowTable({'f1'}, curves, time, windows(), 'GMFP');
testCase.verifyTrue(all(ismember({'peak_ms','peak_uV'}, Ttep.Properties.VariableNames)));
testCase.verifyFalse(any(ismember({'peak_ms','peak_uV'}, Tgmfp.Properties.VariableNames)));
end

function test_gmfpHasAreaColumn_tepDoesNot(testCase)
% AUC is the GMFP/LMFP extra measure; TEP carries peaks instead.
time  = 0:10:100;
curve = time;
Tg = tepWindowTable({'f1'}, curve, time, windows(), 'GMFP');
Tt = tepWindowTable({'f1'}, curve, time, windows(), 'TEP');
testCase.verifyTrue(ismember('area_uV_ms', Tg.Properties.VariableNames));
testCase.verifyFalse(ismember('area_uV_ms', Tt.Properties.VariableNames));
% Value matches the trapezoidal integral over the first window [10 30].
m = computeWindowMeasures(curve, time, 10, 30, 'neg');
testCase.verifyEqual(Tg.area_uV_ms(1), m.area, 'AbsTol', 1e-12);
end

function test_meanMatchesComputeWindowMeasures(testCase)
time   = 0:10:100;
curve  = sin(time/20);
T = tepWindowTable({'f1'}, curve, time, windows(), 'TEP');
m = computeWindowMeasures(curve, time, 10, 30, 'neg');
testCase.verifyEqual(T.mean_uV(1), m.mean, 'AbsTol', 1e-12);
testCase.verifyEqual(T.peak_uV(1), m.peakAmp, 'AbsTol', 1e-12);
end

function test_t1t2AndModeColumns(testCase)
time = 0:10:100;
T = tepWindowTable({'f1'}, time, time, windows(), 'LMFP');
testCase.verifyEqual(T.t1_ms', [10 50]);
testCase.verifyEqual(T.t2_ms', [30 90]);
testCase.verifyEqual(T.mode{1}, 'LMFP');
end
