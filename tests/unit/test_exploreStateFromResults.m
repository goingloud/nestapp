% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_exploreStateFromResults
% TEST_EXPLORESTATEFROMRESULTS  Reopening a saved analysis.
%
%   The Results .mat is the session format, so this is the read side of an
%   export that already existed. What is worth pinning is the reading of files
%   people actually have: saved under a variable name nobody promised, written
%   by an older version, or naming recordings that have since moved.
%
%   Run: runtests('tests/unit/test_exploreStateFromResults')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('exploreStateFromResults'));
end

% -- fixture --------------------------------------------------------------

function [out, realFile] = savedAnalysis(testCase)
% A results-shaped struct naming one file that exists and one that does not.
realFile = [tempname '.set'];
fid = fopen(realFile, 'w'); fwrite(fid, 'x'); fclose(fid);
testCase.addTeardown(@() delete(realFile));

out = struct();
out.files = struct( ...
    'path',             {realFile, 'C:\gone\missing.set'}, ...
    'subject',          {'s1', 's2'}, ...
    'group',            {'pre', 'post'}, ...
    'subjectConfident', {true, false});
out.roi        = {'F1', 'F3'};
out.windows    = struct('name', 'N100', 'winStart', 70, 'winEnd', 150);
out.design     = 'paired';
out.mode       = 'GMFP';
out.plotParams = struct('name', 'TEP (ROI mean)', 'params', struct('xlim', [-80 260]));
out.provenance = struct('nestapp', nestappVersion(), 'plot', 'Window bars');
end

% -- tests ----------------------------------------------------------------

function test_theVariableNameIsNotPartOfTheFormat(testCase)
% The Results exit saves it as `out` and assigns it as `tepResults`, and a user
% may rename it. Keying on the variable name would open one of those and refuse
% the others for no reason a user could see.
[out, ~] = savedAnalysis(testCase);
for name = {'out', 'o', 'tepResults', 'analysisFromLastYear'}
    loaded = struct(name{1}, out);
    [state, report] = exploreStateFromResults(loaded);
    testCase.verifyTrue(report.ok, ['failed to find the struct under ' name{1}]);
    testCase.verifyEqual(state.roi, {'F1', 'F3'});
end
end

function test_aStructPassedDirectlyAlsoWorks(testCase)
[out, ~] = savedAnalysis(testCase);
[state, report] = exploreStateFromResults(out);
testCase.verifyTrue(report.ok);
testCase.verifyEqual(state.design, 'paired');
testCase.verifyEqual(state.mode, 'GMFP');
testCase.verifyEqual(state.plot, 'Window bars');
testCase.verifyEqual(state.plotParams.params.xlim, [-80 260]);
end

function test_somethingElseEntirelyIsRefusedWithAReason(testCase)
[state, report] = exploreStateFromResults(struct('someMatrix', magic(4)));
testCase.verifyFalse(report.ok);
testCase.verifyNotEmpty(report.notes);
testCase.verifyEmpty(state.entries);
end

function test_movedRecordingsAreReportedAndTheRestStillOpens(testCase)
% The expensive thing in the file is the human judgement - which recordings are
% in which group, which electrodes, which windows. A file whose recordings have
% moved is still worth opening for that, so a missing path drops one row rather
% than refusing the analysis.
[out, realFile] = savedAnalysis(testCase);
[state, report] = exploreStateFromResults(out);

testCase.verifyTrue(report.ok);
testCase.verifyEqual(report.missing, {'C:\gone\missing.set'});
testCase.verifyEqual(numel(state.entries), 1);
testCase.verifyEqual(state.entries.path, realFile);
testCase.verifyEqual(state.roi, {'F1', 'F3'}, ...
    'the ROI must survive a recording having moved');
testCase.verifyEqual(numel(state.windows), 1);
testCase.verifyNotEmpty(report.notes);
end

function test_entriesComeBackInExploreDatasetsShape(testCase)
% The restored table has to be indistinguishable from one built by adding
% folders, or everything downstream of it needs a second code path.
[out, ~] = savedAnalysis(testCase);
state = exploreStateFromResults(out);
testCase.verifyEqual(sort(fieldnames(state.entries)), ...
    sort({'path'; 'subject'; 'group'; 'subjectConfident'}));
testCase.verifyEqual(state.entries(1).subjectConfident, true);
end

function test_aFileWithoutTheConfidentFlagTreatsIdsAsDeliberate(testCase)
% Written before the flag was saved, or assembled by hand. Defaulting to "these
% were guesses" would invent review warnings about ids nobody guessed.
[out, ~] = savedAnalysis(testCase);
out.files = rmfield(out.files, 'subjectConfident');
state = exploreStateFromResults(out);
testCase.verifyTrue(state.entries(1).subjectConfident);
end

function test_aDifferentVersionIsANoteNotARefusal(testCase)
[out, ~] = savedAnalysis(testCase);
out.provenance.nestapp = '0.0.1-ancient';
[~, report] = exploreStateFromResults(out);
testCase.verifyTrue(report.ok, 'an old file is still the analysis someone wants back');
testCase.verifyTrue(any(contains(report.notes, '0.0.1-ancient')));
end
