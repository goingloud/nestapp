
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_flagICAThreshold
% TEST_FLAGICATHRESHOLD  A malformed flag threshold fails loudly, not silently.
%
%   pop_icflag expects a [min max] pair per class and tests
%   prob > min & prob < max. A single number scalar-expands to [x x], so the
%   test becomes prob > x & prob < x - never true - and the class is silently
%   NOT flagged. The dispatch now rejects a non-pair threshold with a clear
%   error; a proper [min max] pair still works.
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

function test_scalarThresholdIsRejected(testCase)
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>
global EEG  %#ok<GVMIS>
fx = charFixture('epochedICA');
evalc('pop_saveset(fx, ''filename'', ''ic.set'', ''filepath'', tmpDir);');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), ...
         makePipelineStep('Label ICA Components', reg), ...
         makePipelineStep('Flag ICA Components for Rejection', reg) ];
spec(3).params.Muscle = 0.9;   % a scalar - used to silently flag nothing

opts = struct('pipelineName', 'flagIcaGuard', 'fileIndex', 1);
err = [];
try
    evalc('processOneFile(spec, fullfile(tmpDir, ''ic.set''), opts)');
catch err %#ok<CTCH>
end
testCase.verifyNotEmpty(err, 'a scalar flag threshold must be rejected');
testCase.verifyTrue(contains(err.message, '[min max]'), sprintf( ...
    'the message must ask for a [min max] pair; got: %s', ...
    ternary(isempty(err), '', @() err.message)));
testCase.verifyTrue(contains(err.message, 'Muscle'), ...
    'the message must name the offending class');
end

function test_properPairIsAccepted(testCase)
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>
global EEG  %#ok<GVMIS>
fx = charFixture('epochedICA');
evalc('pop_saveset(fx, ''filename'', ''ic2.set'', ''filepath'', tmpDir);');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), ...
         makePipelineStep('Label ICA Components', reg), ...
         makePipelineStep('Flag ICA Components for Rejection', reg) ];
spec(3).params.Muscle = [0.9 1];   % a proper pair

opts = struct('pipelineName', 'flagIcaOk', 'fileIndex', 1);
report = []; %#ok<NASGU>
evalc('report = processOneFile(spec, fullfile(tmpDir, ''ic2.set''), opts);');
% It ran without error and left an ICA reject mask in place.
testCase.verifyTrue(isfield(EEG.reject, 'gcompreject'), ...
    'a valid pair must run pop_icflag and populate the reject mask');
end

function out = ternary(c, a, b)
if c; out = a; else; out = b(); end
end
