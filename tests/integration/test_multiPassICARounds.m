
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_multiPassICARounds
% TEST_MULTIPASSICAROUNDS  Regression: each ICA decomposition opens its own round.
%
%   Bug: processOneFile only opened a report ICA "round" for step names
%   'Run ICA' / 'Run TESA ICA'. The per-engine steps ('Run ICA (Picard)',
%   FastICA, Infomax) were missed, so in a two-pass pipeline the second
%   decomposition never opened a round - addICARemoval folded its removal into
%   the FIRST round and discarded its variance figure. The data was still
%   cleaned, but every report / QC / dashboard surface made the second
%   (e.g. Picard -> ICLabel) pass look like it removed nothing.
%
%   After the fix (icaDecompositionSteps lists every engine) a two-pass
%   pipeline records two rounds, each with its own component count and
%   variance.
%
%   Run: runtests('tests/integration/test_multiPassICARounds')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
if ~exist('eeglab', 'file')
    testCase.assumeFail('EEGLAB not on path — skipping integration test');
end
here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '..', '..', 'src')));
global EEG ALLEEG CURRENTSET ALLCOM  %#ok<GVMIS>
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');

icaSet = fullfile(fileparts(which('eeglab')), 'sample_data', 'eeglab_data_epochs_ica.set');
if ~exist(icaSet, 'file')
    testCase.assumeFail('EEGLAB ICA sample data not found — skipping');
end
testCase.TestData.icaSet = icaSet;
end

function test_twoPassPicardRecordsTwoRounds(testCase)
[p, n, e] = fileparts(testCase.TestData.icaSet);
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

global EEG  %#ok<GVMIS>
EEG = pop_loadset([n e], p);
EEG = pop_saveset(EEG, 'filename', 'twopass.set', 'filepath', tmpDir);

reg = stepRegistry();
mk  = @(name) makePipelineStep(name, reg);
onePass = @() [ mk('Run ICA (Picard)'), mk('Label ICA Components'), ...
                mk('Flag ICA Components for Rejection'), ...
                mk('Remove Flagged ICA Components') ];
spec = [ mk('Load Data'), onePass(), onePass() ];

% Aggressive thresholds (flag steps at indices 4 and 8) so each pass removes
% something; keep Picard iterations modest for test speed.
for fi = [4 8]
    spec(fi).params.Brain  = [0 0.3];
    spec(fi).params.Muscle = [0.2 1];
    spec(fi).params.Eye    = [0.4 1];
end
for pi = [2 6]
    spec(pi).params.maxiter = 150;
    spec(pi).params.pca     = 0.999;
end

opts = struct('pipelineName', 'twoPassICARegression', 'fileIndex', 1);
report = processOneFile(spec, fullfile(tmpDir, 'twopass.set'), opts);

% Two decompositions -> two rounds (the crux of the bug).
testCase.verifyEqual(numel(report.ica.rounds), 2, ...
    'Each ICA decomposition must open its own report round');

% The second pass's variance must be recorded, not dropped.
r2 = report.ica.rounds{2};
testCase.verifyGreaterThan(r2.nRejected, 0, ...
    'Second pass should have removed at least one component');
testCase.verifyFalse(isnan(r2.varRemoved), ...
    'Second pass variance must be recorded, not discarded into round 1');
end
