
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_tepPeakOutputCaptured
% TEST_TEPPEAKOUTPUTCAPTURED  TEP Peak Output keeps the table it computes.
%
%   Regression: the dispatch called pop_tesa_peakoutput without capturing its
%   return value, so the peak table the step exists to produce was discarded
%   and the step had no observable effect. With averageWin set, the amplitude
%   is a windowed measure not present anywhere on EEG.ROI, so it was lost
%   outright. The result is now stored on EEG.etc.nestapp.tepPeakOutput.
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
end

function test_peakTableIsStoredOnTheDataset(testCase)
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
fx = charFixture('epochedPulses');
evalc('pop_saveset(fx, ''filename'', ''tep.set'', ''filepath'', tmpDir);');

reg = stepRegistry();
mk  = @(name) makePipelineStep(name, reg);
spec = [ mk('Load Data'), mk('Extract TEP (TESA)'), ...
         mk('Find TEP Peaks (TESA)'), mk('TEP Peak Output') ];
% averageWin makes the amplitude a windowed measure absent from EEG.ROI, so
% it can ONLY survive if the output is captured. tablePlot off keeps the
% step headless.
spec(4).params.averageWin = 5;
spec(4).params.tablePlot  = 'off';

opts = struct('pipelineName', 'tepPeakOutputCapture', 'fileIndex', 1);
evalc('processOneFile(spec, fullfile(tmpDir, ''tep.set''), opts);');

testCase.verifyTrue(isfield(EEG.etc, 'nestapp') && ...
    isfield(EEG.etc.nestapp, 'tepPeakOutput'), ...
    'TEP Peak Output must store its table on EEG.etc.nestapp');
out = EEG.etc.nestapp.tepPeakOutput;
testCase.verifyNotEmpty(out, 'the captured peak table must not be empty');
testCase.verifyTrue(all(isfield(out, {'peak', 'lat', 'amp', 'found'})), ...
    'the stored table must carry the peak measurements');
end
