
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_dispatchGuards
% TEST_DISPATCHGUARDS  Two dispatch fixes that turn crashes into clear paths.
%
%   Re-Reference / interpchan: pop_reref interpolates removed reference
%   channels when passed [], but the picker offered on|off and 'on' reached
%   isreal('on')==true, indexing urchanlocs('on') - a hard crash. 'on' now maps
%   to [] so the feature works.
%
%   Choose Data Set / dataSetInd: an unset index used to reach pop_newset and
%   die in finputcheck with "argument 'retrieve' must be numeric", naming
%   neither the step nor the fix. It now fails up front with an actionable
%   message.
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

function test_rerefInterpchanOnDoesNotCrash(testCase)
% The regression: interpchan='on' used to crash in pop_reref. It must now
% complete. With no removed channels there is nothing to interpolate, so it
% is a no-op re-reference - the point is that it runs instead of erroring.
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
fx = charFixture('epoched');
nbchanBefore = fx.nbchan;
evalc('pop_saveset(fx, ''filename'', ''rr.set'', ''filepath'', tmpDir);');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), makePipelineStep('Re-Reference', reg) ];
spec(2).params.ref        = '[]';    % average reference
spec(2).params.interpchan = 'on';    % the value that used to crash

opts = struct('pipelineName', 'interpchanGuard', 'fileIndex', 1);
err = [];
try
    evalc('processOneFile(spec, fullfile(tmpDir, ''rr.set''), opts)');
catch err %#ok<CTCH>
end
testCase.verifyEmpty(err, sprintf('interpchan=on must not crash; got: %s', ...
    ternary(isempty(err), '', @() err.message)));
testCase.verifyEqual(EEG.nbchan, nbchanBefore, ...
    'a no-op interpolation should preserve the channel count');
end

function test_chooseDataSetUnsetIndexFailsClearly(testCase)
% An unset index must produce an actionable message, not the raw finputcheck
% "argument 'retrieve' must be numeric".
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

global EEG  %#ok<GVMIS>
fx = charFixture('epoched');
evalc('pop_saveset(fx, ''filename'', ''cds.set'', ''filepath'', tmpDir);');

reg  = stepRegistry();
spec = [ makePipelineStep('Load Data', reg), makePipelineStep('Choose Data Set', reg) ];
% dataSetInd left at its default ([] = unset).

opts = struct('pipelineName', 'chooseDataSetGuard', 'fileIndex', 1);
err = [];
try
    evalc('processOneFile(spec, fullfile(tmpDir, ''cds.set''), opts)');
catch err %#ok<CTCH>
end
testCase.verifyNotEmpty(err, 'an unset dataset index must fail');
testCase.verifyFalse(contains(err.message, 'must be numeric'), ...
    'the guard must pre-empt the raw finputcheck message');
testCase.verifyTrue(contains(err.message, 'Dataset index') || ...
    contains(err.message, 'dataset index'), ...
    'the message must name the "Dataset index" control the user must set');
end

function test_chooseDataSetDefaultIsNumericNotChar(testCase)
% The root cause: a char '' default is what finputcheck rejected. The unset
% value must be numeric-empty.
reg = stepRegistry();
k = find(strcmp({reg.name}, 'Choose Data Set'), 1);
d = reg(k).defaults.dataSetInd;
testCase.verifyTrue(isnumeric(d), 'dataSetInd default must be numeric, not char');
testCase.verifyEmpty(d, 'and empty, meaning unset');
end

function out = ternary(c, a, b)
if c; out = a; else; out = b(); end
end
