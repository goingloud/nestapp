% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_findReportMatFiles
% TEST_FINDREPORTMATFILES  Report discovery for the Load from Folder button.
%
%   Three folder shapes must all work: the reports folder itself, a batch root
%   (reports live in its reports/ subfolder), and a parent holding several
%   batch runs. The first two are answered by a single directory listing; only
%   the parent case walks the tree, which is what used to make loading slow
%   over a network share - a batch root also holds data/ and qc/, so recursing
%   it stats hundreds of large files to find the handful that are reports.
%
%   Run: runtests('tests/unit/test_findReportMatFiles')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function root = makeTree(testCase, nReports)
% A batch root shaped like the real thing: reports/ plus the bulky data/ and
% qc/ folders the recursive walk used to trawl through.
root = tmpDir(testCase);
mkdir(fullfile(root, 'reports'));
mkdir(fullfile(root, 'data'));
mkdir(fullfile(root, 'qc', 'subj01'));

pipelineReport = struct('inputFile', 'x.set'); %#ok<NASGU>
for k = 1:nReports
    save(fullfile(root, 'reports', sprintf('subj%02d_report.mat', k)), 'pipelineReport');
end
% Decoys the glob must not pick up.
save(fullfile(root, 'data', 'subj01.mat'), 'pipelineReport');
save(fullfile(root, 'qc', 'subj01', 'notes.mat'), 'pipelineReport');
end

% ── tests ─────────────────────────────────────────────────────────────────

function test_findsReportsInTheReportsFolderItself(testCase)
root = makeTree(testCase, 4);
found = findReportMatFiles(fullfile(root, 'reports'));
testCase.verifyNumElements(found, 4);
end

function test_findsReportsFromTheBatchRoot(testCase)
% The common case: the user picks the timestamped run folder.
root  = makeTree(testCase, 4);
found = findReportMatFiles(root);
testCase.verifyNumElements(found, 4, ...
    'Reports must be found via the reports/ subfolder');
names = {found.name};
testCase.verifyTrue(all(contains(names, '_report')), ...
    'Only report .mat files may be returned');
end

function test_findsReportsFromAParentOfSeveralRuns(testCase)
% Falls through to the recursive walk, which is what makes a parent work.
parent = tmpDir(testCase);
pipelineReport = struct('inputFile', 'x.set'); %#ok<NASGU>
for run = 1:2
    d = fullfile(parent, sprintf('20260101_00000%d_pipeline', run), 'reports');
    mkdir(d);
    for k = 1:3
        save(fullfile(d, sprintf('r%d_subj%02d_report.mat', run, k)), 'pipelineReport');
    end
end
testCase.verifyNumElements(findReportMatFiles(parent), 6);
end

function test_matchesBothArtifactNameForms(testCase)
% reportArtifactName emits "<base>_report.mat" when overwriteReports is on
% and "<base>_report_<timestamp>.mat" when it is off.
root = tmpDir(testCase);
pipelineReport = struct('inputFile', 'x.set'); %#ok<NASGU>
save(fullfile(root, 'subj01_report.mat'), 'pipelineReport');
save(fullfile(root, 'subj02_report_20260417_155758.mat'), 'pipelineReport');

testCase.verifyNumElements(findReportMatFiles(root), 2, ...
    'Both timestamped and overwritten report names must match');
end

function test_emptyWhenNothingToFind(testCase)
root = tmpDir(testCase);
mkdir(fullfile(root, 'data'));
testCase.verifyEmpty(findReportMatFiles(root));
end

function test_doesNotReturnDirectories(testCase)
% A folder literally named "*_report*.mat" must not be returned as a file.
root = tmpDir(testCase);
mkdir(fullfile(root, 'bogus_report.mat'));
testCase.verifyEmpty(findReportMatFiles(root));
end

function d = tmpDir(testCase)
% A scratch folder that cleans itself up. Four tests wanted this.
d = fullfile(tempdir, ['nestapp_find_', char(matlab.lang.internal.uuid())]);
mkdir(d);
testCase.addTeardown(@() rmdir(d, 's'));
end
