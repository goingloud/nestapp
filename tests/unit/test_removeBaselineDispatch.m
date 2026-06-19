
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_removeBaselineDispatch
% TEST_REMOVEBASELINEDISPATCH  Remove Baseline honours pointrange (and chanlist).
%
%   The step exposes "Time range" (ms) and "Point range" (samples) as mutually
%   exclusive ways to specify the baseline window, plus "Channels". Previously
%   the dispatch only passed timerange to pop_rmbase, silently ignoring the
%   others. These tests pin the wiring (source) and the point-based behaviour.
%
%   Run: runtests('tests/unit/test_removeBaselineDispatch')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r); addpath(fullfile(r, 'src'));
end

function test_dispatchPassesPointrangeAndChanlist(testCase)
% Guard: the Remove Baseline case must forward pointrange and chanlist to
% pop_rmbase, not just timerange.
r   = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
src = fileread(fullfile(r, 'src', 'processOneFile.m'));
i0  = strfind(src, "case 'Remove Baseline'");
testCase.assertNotEmpty(i0);
window = src(i0(1) : min(i0(1)+900, numel(src)));
testCase.verifyTrue(contains(window, 'pop_rmbase(EEG, timerange, pointrange, chanlist)'), ...
    'Remove Baseline must call pop_rmbase(EEG, timerange, pointrange, chanlist).');
end

function test_pointrangeProducesPointBasedBaseline(testCase)
% Behaviour: a point range removes the mean over those samples - the capability
% the dispatch now wires (pop_rmbase(EEG, [], pointrange)).
if isempty(which('pop_rmbase')); evalc('eeglab(''nogui'')'); end
testCase.assumeNotEmpty(which('pop_rmbase'), 'EEGLAB pop_rmbase not on path.');

EEG = eeg_emptyset();
EEG.nbchan = 2; EEG.trials = 1; EEG.srate = 1000;
EEG.pnts = 200; EEG.xmin = 0; EEG.xmax = 0.199;
EEG.times = 0:199;
EEG.data = 5 + zeros(2, 200);          % constant +5 offset
EEG.data(:, 60:end) = EEG.data(:, 60:end) + 3;   % a later "response"
EEG.chanlocs = struct('labels', {'C1','C2'});
EEG = eeg_checkset(EEG);

out = pop_rmbase(EEG, [], [1 50]);     % baseline by SAMPLES 1..50
baselineMean = mean(out.data(:, 1:50), 2);
testCase.verifyLessThan(max(abs(baselineMean)), 1e-6, ...
    'Point-range baseline should zero the mean over the specified samples.');
end
