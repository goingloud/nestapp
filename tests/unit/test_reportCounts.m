% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_reportCounts
% TEST_REPORTCOUNTS  Unit tests for the batch CSV's count extractor.
%
%   The NaN-not-zero policy is the point of this helper: the batch
%   session_summary.csv now records channels/trials/ICA retained, and a
%   legacy or partial report that never recorded a count must come out as
%   NaN. A 0 would be averaged in downstream as though it were a real
%   measurement of "no channels retained".
%
%   Run: runtests('tests/unit/test_reportCounts')
tests = functiontests(localfunctions);
end

% -- fixture --------------------------------------------------------------

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% -- tests ----------------------------------------------------------------

function test_readsPresentCounts(testCase)
r = initPipelineReport('a.set');
r.channels.original      = 64;
r.channels.final         = 61;
r.channels.nInterpolated = 2;

v = reportCounts(r, 'channels', {'original', 'final', 'nInterpolated'});
testCase.verifyEqual(v, [64 61 2]);
testCase.verifyClass(v, 'double', 'Counts must come back as double for the table');
end

function test_missingFieldIsNaNNotZero(testCase)
r = initPipelineReport('a.set');
r.channels = rmfield(r.channels, 'nInterpolated');

v = reportCounts(r, 'channels', {'original', 'nInterpolated'});
testCase.verifyTrue(isnan(v(2)), 'A missing count must be NaN, never 0');
end

function test_missingGroupIsAllNaN(testCase)
r = initPipelineReport('a.set');
r = rmfield(r, 'ica');

v = reportCounts(r, 'ica', {'nRejected'});
testCase.verifyTrue(all(isnan(v)), 'A missing sub-struct must give all NaN');
end

function test_nonScalarOrNonNumericIsNaN(testCase)
% Defensive: a report that stored something odd must not poison the table.
r = initPipelineReport('a.set');
r.channels.original = [64 64];
r.channels.final    = 'sixty';

v = reportCounts(r, 'channels', {'original', 'final'});
testCase.verifyTrue(all(isnan(v)), 'Non-scalar / non-numeric values must be NaN');
end

function test_sizeAlwaysMatchesRequest(testCase)
% The CSV writer indexes the result positionally, so the width must never
% depend on what the report happens to carry.
r = initPipelineReport('a.set');
names = {'original', 'final', 'nInterpolated', 'notAField'};
testCase.verifySize(reportCounts(r, 'channels', names), [1 numel(names)]);
testCase.verifySize(reportCounts(struct(), 'channels', names), [1 numel(names)]);
end
