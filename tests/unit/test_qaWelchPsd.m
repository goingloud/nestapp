
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_qaWelchPsd
% TEST_QAWELCHPSD  The QA Welch PSD helper is bounded and input-robust.
%
%   qaWelchPsd bounds a per-signal PSD by frequency (decimated bandwidth + fixed
%   resolution) so it never produces the ~10^5-bin spectrum that hung the QA
%   renderer on raw 5 kHz data. These tests pin: high rate is decimated, the bin
%   count is bounded and independent of recording length, low rate is left
%   alone, and short inputs still return a valid averaged estimate.
%
%   Run: runtests('tests/unit/test_qaWelchPsd')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r); addpath(fullfile(r, 'src')); addpath(fullfile(r, 'src', 'qa'));
testCase.assumeNotEmpty(which('pwelch'),   'Signal Processing Toolbox required');
testCase.assumeNotEmpty(which('resample'), 'Signal Processing Toolbox required');
end

function test_decimatesHighRateAndBoundsBins(testCase)
fs = 5000;
[pxx, f, fsEff] = qaWelchPsd(randn(fs * 30, 1), fs);   % 30 s at 5 kHz
testCase.verifyLessThan(fsEff, fs, 'high rate must be decimated');
testCase.verifyLessThanOrEqual(max(f), 320, 'bandwidth bounded to ~F_max');
testCase.verifyLessThan(numel(f), 500, 'frequency-bin count bounded (~F_max/res)');
testCase.verifyEqual(numel(pxx), numel(f));
end

function test_binCountIndependentOfLength(testCase)
fs = 5000;
[~, f1] = qaWelchPsd(randn(fs * 5,   1), fs);
[~, f2] = qaWelchPsd(randn(fs * 300, 1), fs);          % 60x longer recording
testCase.verifyEqual(numel(f1), numel(f2), ...
    'bin count must not scale with recording length (the original bug)');
end

function test_lowRateNotDecimated(testCase)
fs = 1000;
[~, f, fsEff] = qaWelchPsd(randn(fs * 20, 1), fs);
testCase.verifyEqual(fsEff, fs, 'rate <= 2*F_max must not be decimated');
testCase.verifyLessThanOrEqual(max(f), fs / 2);
end

function test_shortSignalStillAverages(testCase)
% A short input must clamp the window to keep several Welch segments (not one),
% so the estimate stays comparable to the previous default.
fs = 1000;
[pxx, f] = qaWelchPsd(randn(1000, 1), fs);
testCase.verifyNotEmpty(pxx);
testCase.verifyEqual(numel(pxx), numel(f));
testCase.verifyLessThan(numel(f), 400, 'short-signal window is capped, not full-length');
end
