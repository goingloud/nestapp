
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_detectBadChannelsRansac
% TEST_DETECTBADCHANNELSRANSAC  The RANSAC bad-channel step wraps clean_channels.
%
%   A first-tier RANSAC bad-channel detector (EEGLAB clean_rawdata's
%   clean_channels), replacing the retired ARTIST/AARATEP detectors. This
%   exercises it through the real dispatch on continuous data with channel
%   coordinates, confirms removed channels are recorded as bad (so Interpolate
%   Channels can restore them), and that it refuses epoched data.
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
if isempty(which('clean_channels'))
    testCase.assumeFail('clean_rawdata not installed - step is gated off');
end
sampleSet = fullfile(fileparts(which('eeglab')), 'sample_data', 'eeglab_data.set');
if ~exist(sampleSet, 'file')
    testCase.assumeFail('EEGLAB continuous sample dataset not found');
end
testCase.TestData.sampleSet = sampleSet;
end

function runRansac(tmpDir, baseName)
% Save the already-injected global EEG, then run Load Data -> RANSAC on it.
% (The per-test data injection is what differs; this shared tail does not.)
global EEG  %#ok<GVMIS>
EEG = pop_saveset(EEG, 'filename', [baseName '.set'], 'filepath', tmpDir);
reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), ...
         makePipelineStep('Detect Bad Channels (RANSAC)', reg) ];
opts = struct('pipelineName', baseName, 'fileIndex', 1);
setPath = fullfile(tmpDir, [baseName '.set']); %#ok<NASGU> used inside evalc
evalc('processOneFile(spec, setPath, opts);');
end

function test_removes_and_records_bad_channels(testCase)
[p, n, e] = fileparts(testCase.TestData.sampleSet);
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
EEG = pop_loadset([n e], p);
% Inject an obviously-bad channel so RANSAC has a clear target.
EEG.data(5, :) = single(randn(1, EEG.pnts) * 500);
nbBefore = EEG.nbchan;
origData   = EEG.data;
origLabels = {EEG.chanlocs.labels};
runRansac(tmpDir, 'ransac');

testCase.verifyLessThan(EEG.nbchan, nbBefore, ...
    'RANSAC should remove at least one bad channel from this data');
testCase.verifyTrue(isfield(EEG.etc, 'nestapp') && ...
    isfield(EEG.etc.nestapp, 'badChannels') && ...
    ~isempty(EEG.etc.nestapp.badChannels), ...
    'removed channels must be recorded as bad for Interpolate Channels to restore them');

% B1's defining property: the kept signal is NEVER filtered. Detection runs
% on a high-passed copy, but a surviving channel's samples must be bit-for-bit
% the original data - only channels are dropped, not filtered.
keptLbl = EEG.chanlocs(1).labels;
origRow = origData(strcmp(origLabels, keptLbl), :);
keptRow = EEG.data(1, :);
testCase.verifyEqual(keptRow, origRow, ...
    'the kept signal must be the untouched (unfiltered) data');
end

function test_drift_does_not_cause_mass_removal(testCase)
% The point of B1: on drifty (un-high-passed) data a bare clean_channels
% over-removes wildly (drift decorrelates good channels). The internal
% detection high-pass must keep removal sane while still catching a genuinely
% decorrelated channel.
[p, n, e] = fileparts(testCase.TestData.sampleSet);
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
EEG = pop_loadset([n e], p);
rng(42);
d = double(EEG.data);
typ = median(std(d, 0, 2));
% One genuinely bad (decorrelated, normal-amplitude) channel.
badRow = 22; badLbl = EEG.chanlocs(badRow).labels;
d(badRow, :) = typ * randn(1, EEG.pnts);
% Strong shared low-frequency drift across ALL channels (the no-high-pass case).
t = (0:EEG.pnts-1) / EEG.srate;
for c = 1:EEG.nbchan
    d(c, :) = d(c, :) + 3 * typ * sin(2*pi*(0.05 + 0.2*rand)*t + 2*pi*rand);
end
EEG.data = single(d);
nbBefore = EEG.nbchan;
runRansac(tmpDir, 'ransacDrift');

removed = {};
if isfield(EEG.etc, 'nestapp') && isfield(EEG.etc.nestapp, 'badChannels')
    removed = EEG.etc.nestapp.badChannels;
end
testCase.verifyTrue(ismember(badLbl, removed), ...
    'the genuinely decorrelated channel must still be caught through the drift');
% A bare wrapper on this data removes ~half the montage; the detection
% high-pass must keep it far below that.
testCase.verifyLessThan(nbBefore - EEG.nbchan, nbBefore * 0.25, ...
    'the detection high-pass must prevent drift-driven mass removal');
end

function test_refuses_epoched_data(testCase)
[p, n, e] = fileparts(testCase.TestData.sampleSet);
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
EEG = pop_loadset([n e], p);
% Make it epoched so the continuous-only guard should fire.
EEG = eeg_regepochs(EEG, 'recurrence', 1, 'limits', [0 1]);
err = [];
try
    runRansac(tmpDir, 'ransacEp');
catch err %#ok<CTCH>
end
testCase.assertNotEmpty(err, 'epoched data must be refused');
testCase.verifyTrue(contains(err.message, 'CONTINUOUS') || ...
    contains(err.message, 'continuous') || contains(err.message, 'Epoching'), ...
    'the message must say the step needs continuous data');
end

function test_step_is_available_and_offered(testCase)
reg = stepRegistry();
k = find(strcmp({reg.name}, 'Detect Bad Channels (RANSAC)'), 1);
testCase.assertNotEmpty(k, 'the step must be registered');
[ok, unmet] = stepAvailability(reg(k));
testCase.verifyTrue(ok, sprintf('step should be available; unmet: %s', ...
    strjoin({unmet.fn}, ', ')));
testCase.verifyTrue(ismember('Detect Bad Channels (RANSAC)', ...
    {availableSteps(reg).name}), 'the step must appear in the picker');
end
