% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_sessionSummaryCsv
% TEST_SESSIONSUMMARYCSV  The auto-written batch CSV carries retention counts.
%
%   batch/session_summary.csv used to record only operational columns (steps,
%   duration, verdict, failure), so the numbers a methods table actually needs
%   - channels and trials retained, ICA components removed - were reachable
%   only by pressing Export Metrics Table in the Reports tab. They are now
%   written on every run.
%
%   Needs EEGLAB (runPipelineCore loads a real .set). One batch runs in
%   setupOnce and every test reads it. The NaN-not-zero policy behind the
%   counts is covered separately, without EEGLAB, in tests/unit/test_reportCounts.
%
%   Run: runtests('tests/integration/test_sessionSummaryCsv')
tests = functiontests(localfunctions);
end

% -- fixture --------------------------------------------------------------

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
addpath(fullfile(r, 'tests', 'helpers'));
testCase.assumeNotEmpty(which('pop_saveset'), 'EEGLAB not on path');

tmpDir = fullfile(tempdir, ['nestapp_csv_', char(matlab.lang.internal.uuid())]);
mkdir(tmpDir);
testCase.addTeardown(@() rmdir(tmpDir, 's'));

baseName = 'tiny_csv';
EEG = charFixture('tiny'); %#ok<NASGU> - referenced inside evalc
evalc('pop_saveset(EEG, ''filename'', [baseName, ''.set''], ''filepath'', tmpDir);');

spec(1).name   = 'Load Data';
spec(1).params = struct();
spec(2).name   = 'Quality Gate';
spec(2).params = struct('gateLabel', 'csv-smoke');

opts = struct('uiFigure', [], 'pipelineName', 'csv-test', 'statusBar', [], ...
              'parallel', false, 'chanLocFile', '', 'outputRoot', tmpDir);
allReports = runPipelineCore(spec, {fullfile(tmpDir, [baseName '.set'])}, opts);
testCase.assertNotEmpty(allReports, 'Pipeline produced no reports');

hits = dir(fullfile(tmpDir, '**', 'session_summary.csv'));
testCase.assertNotEmpty(hits, 'session_summary.csv was not written');

testCase.TestData.report = allReports{1};
testCase.TestData.table  = readtable(fullfile(hits(1).folder, hits(1).name));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% -- tests ----------------------------------------------------------------

function test_csvCarriesRetentionColumns(testCase)
names = testCase.TestData.table.Properties.VariableNames;

retention = {'chans_original', 'chans_final', 'chans_interpolated', ...
             'trials_original', 'trials_final', 'ica_removed'};
for k = 1:numel(retention)
    testCase.verifyTrue(ismember(retention{k}, names), ...
        sprintf('session_summary.csv must carry a %s column', retention{k}));
end

% The operational columns must survive alongside them.
operational = {'stem', 'status', 'n_steps', 'duration_s', ...
               'quality_verdict', 'fail_step', 'fail_reason'};
for k = 1:numel(operational)
    testCase.verifyTrue(ismember(operational{k}, names), ...
        sprintf('%s column must be preserved', operational{k}));
end
end

function test_retentionValuesMatchTheReport(testCase)
T      = testCase.TestData.table;
report = testCase.TestData.report;

row = T(strcmp(T.status, 'ok'), :);
testCase.assertEqual(height(row), 1, 'Expected exactly one successful row');
testCase.verifyEqual(row.chans_original(1), double(report.channels.original), ...
    'chans_original must match the report');
testCase.verifyEqual(row.chans_final(1), double(report.channels.final), ...
    'chans_final must match the report');
testCase.verifyEqual(row.trials_original(1), double(report.trials.original), ...
    'trials_original must match the report');
testCase.verifyEqual(row.trials_final(1), double(report.trials.final), ...
    'trials_final must match the report');
end
