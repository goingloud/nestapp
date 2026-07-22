
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_detrendToolboxGuard
% TEST_DETRENDTOOLBOXGUARD  Exponential detrend fails with a clear message.
%
%   TESA De-Trend now offers linear|exponential|double. The exponential and
%   double fits need the Curve Fitting Toolbox, and tesa_detrend detects that
%   toolbox using extractfield (Mapping Toolbox) - so without either, it
%   crashes with a message naming neither the dependency nor the step. nestapp
%   guards both up front and raises a nestapp:detrend* error the user can act
%   on. Linear needs no toolbox and always runs.
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

function test_exponentialErrorsClearlyWhenAToolboxIsMissing(testCase)
% Only meaningful when a required toolbox is actually absent. When both are
% present the step genuinely runs, so there is nothing to assert here.
[fitOk, ~] = ensureCurveFittingFit();
haveExtractfield = ~isempty(which('extractfield'));
if fitOk && haveExtractfield
    testCase.assumeFail(['Both Curve Fitting and Mapping toolboxes present - ' ...
        'exponential detrend runs, no guard to exercise']);
end

tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
fx = charFixture('epoched');
evalc('pop_saveset(fx, ''filename'', ''dt.set'', ''filepath'', tmpDir);');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), makePipelineStep('TESA De-Trend', reg) ];
spec(2).params.detrend = 'exponential';
spec(2).params.timeWin = [11 380];

opts = struct('pipelineName', 'detrendGuard', 'fileIndex', 1);
% The error must be one of nestapp's own, actionable ones - NOT a raw
% "Undefined function 'extractfield'" or "Undefined function 'fit'".
err = [];
try
    evalc('processOneFile(spec, fullfile(tmpDir, ''dt.set''), opts)');
catch err %#ok<CTCH>
end
% processOneFile wraps a failing step as nestapp:stepFailed, keeping the
% underlying message. What matters is that the user sees an actionable
% message - naming the toolbox and pointing at "linear" - and NOT the raw
% "Undefined function 'extractfield'"/'fit' crash the guard exists to pre-empt.
testCase.verifyNotEmpty(err, 'exponential detrend must fail when its toolbox is missing');
testCase.verifyFalse(contains(err.message, 'Undefined function'), sprintf( ...
    'The guard must pre-empt the cryptic crash; got: %s', err.message));
testCase.verifyTrue(contains(err.message, 'linear'), ...
    'The message must point the user at the linear alternative');
testCase.verifyTrue(contains(err.message, 'Toolbox'), ...
    'The message must name the missing toolbox');
end

function test_linearNeedsNoToolboxAndRuns(testCase)
% The control: linear detrend uses only polyfit, so it must run regardless of
% toolbox state and must NOT hit the guard.
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
fx = charFixture('epoched');
evalc('pop_saveset(fx, ''filename'', ''dtlin.set'', ''filepath'', tmpDir);');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), makePipelineStep('TESA De-Trend', reg) ];
spec(2).params.detrend = 'linear';
spec(2).params.timeWin = [11 380];

opts = struct('pipelineName', 'detrendGuardLinear', 'fileIndex', 1);
report = []; %#ok<NASGU>
evalc('report = processOneFile(spec, fullfile(tmpDir, ''dtlin.set''), opts);');
testCase.verifyNotEmpty(EEG.data, 'linear detrend should complete and leave data');
end
