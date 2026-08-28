% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_differenceInterval
% TEST_DIFFERENCEINTERVAL  The contrast estimator, extracted from the plot.
%
%   This was a local helper inside drawDifferenceWave. It is an estimator, the
%   window-bars view and the exported measures need the same numbers, and a
%   statistic computed inside a drawing function gets reimplemented the moment
%   a second view wants it - so it now lives beside curveInterval and is
%   tested directly rather than through a figure.
%
%   Run: runtests('tests/unit/test_differenceInterval')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── the estimate itself ───────────────────────────────────────────────────

function test_meanIsBMinusA(testCase)
A = [1 1; 3 3];
B = [2 2; 6 6];
est = differenceInterval(A, B, 'unpaired');
testCase.verifyEqual(est.mean, [2 2], 'AbsTol', 1e-12);
end

function test_pairedUsesPerSubjectDifferences(testCase)
% Subjects differ wildly in level but each shifts by exactly +2, so the paired
% difference is certain: a zero-width interval, not a wide one.
A = [1; 50; 100];
B = A + 2;
est = differenceInterval(A, B, 'paired');
testCase.verifyEqual(est.mean, 2, 'AbsTol', 1e-12);
testCase.verifyEqual(est.sem, 0, 'AbsTol', 1e-12, ...
    'between-subject spread is irrelevant to a within-subject contrast');
testCase.verifyEqual(est.n, 3);
end

function test_unpairedIsWiderThanPairedOnTheSameData(testCase)
% The reason both exist: treating a paired contrast as unpaired throws away
% the pairing and inflates the interval.
A = [1; 50; 100];
B = A + 2;
p = differenceInterval(A, B, 'paired');
u = differenceInterval(A, B, 'unpaired');
testCase.verifyLessThan(p.hi - p.lo, u.hi - u.lo);
end

function test_unpairedUsesWelchDfForUnequalGroups(testCase)
A = [1; 2; 3; 4];
B = [10; 20];
est = differenceInterval(A, B, 'unpaired');
v1 = var(A) / 4;
v2 = var(B) / 2;
expected = (v1 + v2)^2 / (v1^2 / 3 + v2^2 / 1);
testCase.verifyEqual(est.df, expected, 'RelTol', 1e-12, ...
    'a pooled df would paper over unequal n and unequal variance');
testCase.verifyEqual(est.sem, sqrt(v1 + v2), 'RelTol', 1e-12);
end

function test_pairedRequiresMatchedRows(testCase)
testCase.verifyError(@() differenceInterval(zeros(4,3), zeros(3,3), 'paired'), ...
    'nestapp:pairedGroupsUnequal');
end

function test_singleSubjectGivesNaNBounds(testCase)
est = differenceInterval([1 2], [3 4], 'paired');
testCase.verifyEqual(est.mean, [2 2], 'AbsTol', 1e-12);
testCase.verifyTrue(all(isnan(est.lo)), ...
    'one subject cannot support an interval');
end

function test_noteStatesDesignAndLevel(testCase)
% The note is printed on the figure; it is how a reader knows what the band is.
testCase.verifyEqual(differenceInterval([1;2], [3;4], 'paired').note, ...
    'paired, 95% CI');
testCase.verifyEqual(differenceInterval([1;2], [3;4], 'unpaired', 0.99).note, ...
    'unpaired, 99% CI');
end

function test_levelWidensTheInterval(testCase)
A = [1; 2; 3; 4];
B = [2; 4; 5; 9];
w95 = diff([differenceInterval(A,B,'paired',0.95).lo, ...
            differenceInterval(A,B,'paired',0.95).hi]);
w99 = diff([differenceInterval(A,B,'paired',0.99).lo, ...
            differenceInterval(A,B,'paired',0.99).hi]);
testCase.verifyGreaterThan(w99, w95);
end
