% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_singleFileSessionSummary
% TEST_SINGLEFILESESSIONSUMMARY  Regression: a one-file run gets a summary.
%
%   runPipelineCore and the Reports tab used to gate the session summary on
%   numel(reports) > 1, so a single-file batch silently got per-file reports
%   and no overall report. summarizeReports itself has always been safe for
%   N == 1 (fmtStat renders a lone value without a spread); these tests lock
%   that in so the guard cannot creep back.
%
%   Run: runtests('tests/unit/test_singleFileSessionSummary')
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

% ── tests ─────────────────────────────────────────────────────────────────

function test_singleReportProducesSummary(testCase)
txt = summarizeReports({oneReport()});
testCase.verifyNotEmpty(txt, 'A one-file run must still produce summary text');
testCase.verifyTrue(contains(txt, '(1 files)'),  'Header must state the file count');
testCase.verifyTrue(contains(txt, 'CHANNELS'),   'Summary must include CHANNELS');
testCase.verifyTrue(contains(txt, 'METHODS'),    'Summary must include METHODS');
testCase.verifyTrue(contains(txt, 'CITATION'),   'Summary must include CITATION');
end

function test_singleReportStatsHaveNoSpread(testCase)
% With one file there is no spread to report, so the stats must render as a
% bare value rather than "x +/- NaN".
txt = summarizeReports({oneReport()});
testCase.verifyTrue(contains(txt, 'Original:     64.0'), 'Lone value rendered plainly');
testCase.verifyFalse(contains(txt, 'NaN'), 'A single file must not produce NaN spreads');
end

function test_singleReportWithFailureStillSummarises(testCase)
% The realistic one-success case: a batch where every other file died. The
% summary must still be produced AND surface the failures.
failed = struct('fi', 2, 'name', 'b.set', 'path', 'b.set', 'step', 3, ...
                'stepName', 'Run ICA', 'message', 'not enough rank', ...
                'kind', 'errored');
txt = summarizeReports({oneReport()}, failed);
testCase.verifyTrue(contains(txt, 'FILES THAT DID NOT COMPLETE (1)'), ...
    'Failures must be listed');
testCase.verifyTrue(contains(txt, 'Run ICA'), 'Failing step must be named');
testCase.verifyTrue(contains(txt, 'METHODS'), 'Summary body must still be built');
end

% ── helpers ───────────────────────────────────────────────────────────────

function r = oneReport()
% Minimal but realistic single-file report, mirroring the fixtures in
% test_pipelineReport.
r = initPipelineReport('a.set');
r.steps = {struct('name', 'Remove TMS Artifacts (TESA)', ...
                  'params', struct('cutTimesTMS', [-2 10]), ...
                  'chansBefore', 64, 'chansAfter', 64, ...
                  'trialsBefore', 100, 'trialsAfter', 100, 'duration', 0)};
r.channels.original  = 64;
r.channels.nRejected = 2;
r.channels.final     = 62;
r.trials.original    = 100;
r.trials.rejected    = 10;
r.trials.final       = 90;
end
