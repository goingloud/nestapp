
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_tesa12Wrappers
% TEST_TESA12WRAPPERS  The TESA 1.2 wrapper steps run end-to-end.
%
%   These six steps were version-gated and could not be executed until TESA
%   1.2 was installed. This exercises the four non-interactive ones through the
%   real dispatch on a wide (+/-1200 ms) synthetic epoch that fits their
%   shipped default windows, so a regression that mis-wires an argument (units,
%   name, positional vs named) is caught. Interactive Channel Reject is a
%   blocking GUI and cannot run headless, so it is out of scope here.
%
%   Also pins the one nestapp-side correctness fix found during verification:
%   Modified Bandpass Filter's order must be even, guarded with a clear message.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
if ~exist('eeglab', 'file')
    testCase.assumeFail('EEGLAB not on path - skipping integration test');
end
here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '..', '..', 'src')));
addpath(fullfile(here, '..', 'helpers'));
global EEG ALLEEG CURRENTSET ALLCOM  %#ok<GVMIS>
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');
if tesaVersion(true) * [100;10;1] < 120
    testCase.assumeFail('TESA 1.2 not installed - these steps are version-gated off');
end
end

function EEG = wideEpochSet(tmpDir, fname)
% +/-1200 ms epochs at 1000 Hz, wide enough for the default detrend/demean
% (+/-1000) and modified-bandpass (extend 500) windows.
rng(42);
srate = 1000; t = -1.2:1/srate:1.2; nch = 16; ntr = 20;
EEG = eeg_emptyset();
EEG.data   = single(randn(nch, numel(t), ntr) * 5);
EEG.srate  = srate; EEG.nbchan = nch; EEG.trials = ntr; EEG.pnts = numel(t);
EEG.xmin   = t(1); EEG.xmax = t(end); EEG.times = t * 1000;
cl = struct('labels', {});
for c = 1:nch; cl(c).labels = sprintf('E%d', c); end
EEG.chanlocs = cl;
EEG = eeg_checkset(EEG);
evalc('pop_saveset(EEG, ''filename'', fname, ''filepath'', tmpDir);');
end

function runStep(testCase, stepName, tweak)
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>
wideEpochSet(tmpDir, 'w.set');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), makePipelineStep(stepName, reg) ];
if nargin > 2 && ~isempty(tweak)
    spec(2).params = tweak(spec(2).params);
end
opts = struct('pipelineName', 'tesa12', 'fileIndex', 1);
evalc('processOneFile(spec, fullfile(tmpDir, ''w.set''), opts);');
end

function test_robust_detrend_runs(testCase)
runStep(testCase, 'Robust Detrend (TESA)');
end

function test_robust_demean_runs(testCase)
runStep(testCase, 'Robust Demean (TESA)');
end

function test_modified_bandpass_runs(testCase)
runStep(testCase, 'Modified Bandpass Filter (TESA)');
end

function test_fit_artifact_model_runs(testCase)
runStep(testCase, 'Fit Artifact Model (TESA)');
end

function test_modified_bandpass_rejects_odd_order_clearly(testCase)
% An odd order fails deep in the Butterworth design with a cryptic inputParser
% message. The dispatch must catch it first with a nestapp error naming the
% step and the even-order requirement.
err = [];
try
    runStep(testCase, 'Modified Bandpass Filter (TESA)', ...
        @(p) setfield(p, 'filtOrder', 5)); %#ok<SFLD>
catch err %#ok<CTCH>
end
testCase.assertNotEmpty(err, 'an odd filter order must be rejected');
testCase.verifyEmpty(regexp(err.message, 'inputParser|@\(x\)', 'once'), ...
    'the cryptic inputParser message must be pre-empted');
testCase.verifyTrue(contains(err.message, 'even'), ...
    'the message must state the order has to be even');
end
