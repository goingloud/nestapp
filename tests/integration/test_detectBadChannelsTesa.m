
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_detectBadChannelsTesa
% TEST_DETECTBADCHANNELSTESA  The TESA 1.2 bad-channel step runs every method.
%
%   Regression for the threshold handling. The dispatch used to hardcode
%   threshold = 9 and always pass it, which:
%     - made fromASR throw (it asserts the threshold is empty), and
%     - forced 9 onto the DDWiener family instead of their default of 20.
%   The step now passes threshold only when the user sets one, so every method
%   runs on its own default. Needs TESA 1.2 (the step is version-gated) and a
%   real montage with channel coordinates.
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
    testCase.assumeFail('TESA 1.2 not installed - Detect Bad Channels (TESA) is gated off');
end
icaSet = fullfile(fileparts(which('eeglab')), 'sample_data', 'eeglab_data_epochs_ica.set');
if ~exist(icaSet, 'file')
    testCase.assumeFail('EEGLAB sample dataset not found');
end
testCase.TestData.icaSet = icaSet;
end

function runMethod(testCase, method)
[p, n, e] = fileparts(testCase.TestData.icaSet);
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
EEG = pop_loadset([n e], p);
EEG = pop_saveset(EEG, 'filename', 'dbc.set', 'filepath', tmpDir);

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), ...
         makePipelineStep('Detect Bad Channels (TESA)', reg) ];
spec(2).params.detectionMethod = method;
spec(2).params.replaceMethod   = 'NaN';   % non-destructive, no montage math

opts = struct('pipelineName', 'dbcTesa', 'fileIndex', 1);
evalc('processOneFile(spec, fullfile(tmpDir, ''dbc.set''), opts);');
end

function test_prep_deviation_runs(testCase)
runMethod(testCase, 'PREP_deviation');   % default threshold 9
end

function test_ddwiener_runs_on_its_own_default(testCase)
% Used to run at 9 (nestapp-forced); must now run at the upstream default 20.
runMethod(testCase, 'TESA_DDWiener');
end

function test_ddwiener_pertrial_runs(testCase)
runMethod(testCase, 'TESA_DDWiener_PerTrial');
end

function test_fromASR_no_longer_throws_on_the_threshold_assert(testCase)
% This used to fail with "Threshold not used for channels previously marked
% for rejection by ASR". fromASR without ASR having run may still error for a
% DIFFERENT, legitimate reason - what must NOT happen is the threshold assert.
global EEG  %#ok<GVMIS>
[p, n, e] = fileparts(testCase.TestData.icaSet);
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>
EEG = pop_loadset([n e], p);
EEG = pop_saveset(EEG, 'filename', 'asr.set', 'filepath', tmpDir);

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), ...
         makePipelineStep('Detect Bad Channels (TESA)', reg) ];
spec(2).params.detectionMethod = 'fromASR';
spec(2).params.replaceMethod   = 'NaN';

opts = struct('pipelineName', 'dbcAsr', 'fileIndex', 1);
err = [];
try
    evalc('processOneFile(spec, fullfile(tmpDir, ''asr.set''), opts);');
catch err %#ok<CTCH>
end
if ~isempty(err)
    testCase.verifyEmpty(regexp(err.message, 'Threshold not used', 'once'), ...
        'The threshold assert must not fire - the step must stop forcing a threshold onto fromASR');
end
end
