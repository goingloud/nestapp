
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_interpolateChannelsSkipsIntentional
% TEST_INTERPOLATECHANNELSSKIPSINTENTIONAL  Regression test for interpolation.
%
%   "Interpolate Channels" must restore ONLY channels that were removed as
%   bad, never channels removed on purpose. Both kinds land in
%   EEG.chaninfo.removedchans (pop_select records everything it removes), so
%   the fix tracks bad channels separately in EEG.etc.nestapp.badChannels
%   (written by recordBadChannels after each bad-channel step) and
%   interpolates only those.
%
%   Bug before the fix: an intentionally-dropped channel (e.g. one left out
%   of a keep-list) carried valid coordinates, so the old code happily
%   interpolated it back.
%
%   Run: runtests('tests/integration/test_interpolateChannelsSkipsIntentional')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
if ~exist('eeglab', 'file')
    testCase.assumeFail('EEGLAB not on path — skipping integration test');
end
here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '..', '..', 'src')));
global EEG ALLEEG CURRENTSET ALLCOM  %#ok<GVMIS>
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');
sf = findSampleData();
if isempty(sf)
    testCase.assumeFail('EEGLAB sample data not found — skipping integration test');
end
testCase.TestData.sampleFile = sf;
end

function filePath = findSampleData()
eeglabRoot = fileparts(which('eeglab'));
candidates = {
    fullfile(eeglabRoot, 'sample_data', 'eeglab_data.set'), ...
    fullfile(eeglabRoot, 'sample_data', 'EEG.set')
};
filePath = '';
for i = 1:numel(candidates)
    if exist(candidates{i}, 'file')
        filePath = candidates{i};
        return
    end
end
end

% ── tests ─────────────────────────────────────────────────────────────────

function test_onlyBadChannelIsRestored(testCase)
global EEG  %#ok<GVMIS>

% Load sample data, then remove two real channels: one flagged as bad, one
% removed intentionally. Both keep their coordinates and both are recorded
% in removedchans by pop_select - the exact situation that used to make the
% old code restore both.
[p, n, e] = fileparts(testCase.TestData.sampleFile);
EEG = pop_loadset([n e], p);

badLabel        = EEG.chanlocs(10).labels;   % pretend RANSAC/rejchan killed it
intentionalLabel = EEG.chanlocs(5).labels;   % deliberately left out of montage

EEG = pop_select(EEG, 'nochannel', {badLabel, intentionalLabel});
% Only the bad one is on the bad-channel list (what recordBadChannels writes).
EEG.etc.nestapp.badChannels = {badLabel};

tmpDir = tempname;
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));
fn = 'onebad.set';
EEG = pop_saveset(EEG, 'filename', fn, 'filepath', tmpDir);

% Sanity: both channels are gone and both were recorded as removed.
EEGcheck = pop_loadset(fn, tmpDir);
testCase.assertFalse(ismember(badLabel, {EEGcheck.chanlocs.labels}), ...
    'Setup: bad channel must be absent before interpolation');
testCase.assertFalse(ismember(intentionalLabel, {EEGcheck.chanlocs.labels}), ...
    'Setup: intentional channel must be absent before interpolation');
testCase.assertEqual(EEGcheck.etc.nestapp.badChannels, {badLabel}, ...
    'Setup: only the bad channel must be on the bad-channel list');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), ...
         makePipelineStep('Interpolate Channels', reg) ];

opts = struct('pipelineName', 'skipIntentional', 'fileIndex', 1);
processOneFile(spec, fullfile(tmpDir, fn), opts);

liveLabels = {EEG.chanlocs.labels};
testCase.verifyTrue(ismember(badLabel, liveLabels), ...
    'Bad channel must be interpolated back');
testCase.verifyFalse(ismember(intentionalLabel, liveLabels), ...
    'Intentionally-removed channel must NOT be interpolated back');
end

function test_recordBadChannelsTracksRemovedLabels(testCase)
% Unit test the helper directly: it must append exactly the labels that
% disappeared, de-duplicate across calls, and tolerate a missing etc field.
EEG = struct();
EEG.chanlocs = struct('labels', {'A', 'B', 'C', 'D'});

before = {EEG.chanlocs.labels};
EEG.chanlocs(3) = [];                         % drop 'C'
EEG = recordBadChannels(EEG, before);
testCase.verifyEqual(sort(EEG.etc.nestapp.badChannels), {'C'});

before = {EEG.chanlocs.labels};               % now A B D
EEG.chanlocs(1) = [];                         % drop 'A'
EEG = recordBadChannels(EEG, before);
testCase.verifyEqual(sort(EEG.etc.nestapp.badChannels), {'A', 'C'});

% Re-recording with no change must not grow or duplicate the list.
EEG = recordBadChannels(EEG, {EEG.chanlocs.labels});
testCase.verifyEqual(sort(EEG.etc.nestapp.badChannels), {'A', 'C'});
end
