% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_reportOutputFile
% TEST_REPORTOUTPUTFILE  A report has to name the file it describes.
%
%   Save New Set composed its destination from outputPaths and the savenew
%   name and then discarded it, so the report recorded which file went IN and
%   nothing about what came out. That made the batch's own output
%   undiscoverable from the report - the Reports tab could describe a
%   recording it had no way to point at.
%
%   Run: runtests('tests/unit/test_reportOutputFile')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('initPipelineReport'));
end

function test_theSchemaDeclaresTheFieldSoOldCodeCanAsk(testCase)
% Declared empty rather than absent: every consumer can ask isfield once and
% then read it, instead of each inventing its own "might not be there" guard.
r = initPipelineReport('C:\data\sub-01.vhdr');
testCase.verifyTrue(isfield(r, 'outputFile'));
testCase.verifyEmpty(r.outputFile);
testCase.verifyEqual(r.inputFile, 'C:\data\sub-01.vhdr', ...
    'the input must still be recorded separately - they are different files');
end

function test_theSaveStepRecordsWhereItWrote(testCase)
% Pins the wiring, not the filesystem: the Save New Set case must assign
% fileReport.outputFile. Without this the field stays '' forever and the
% Reports Open... button is dead on every run.
src = fileread(which('processOneFile'));
saveCase = extractBetween(src, "case 'Save New Set'", "case 'Find TMS Pulses (AARATEP)'");
testCase.assertNotEmpty(saveCase, 'could not find the Save New Set case');
testCase.verifySubstring(saveCase{1}, 'fileReport.outputFile', ...
    'Save New Set must record its destination on the report');
end

function test_theSavedPathPrefersWhatEeglabStamped(testCase)
% pop_saveset writes EEG.filename/.filepath, which reflect the .set extension
% it appended and any normalisation it applied - so that is the file that
% exists, and the composed name is only a fallback.
src = fileread(which('processOneFile'));
helper = extractBetween(src, 'function p = savedSetPath', 'function labels = channelLabelsOf');
testCase.assertNotEmpty(helper, 'savedSetPath helper missing');
h = helper{1};
testCase.verifySubstring(h, 'EEG.filepath');
testCase.verifySubstring(h, 'savenew', ...
    'the composed savenew value is the documented fallback');
end
