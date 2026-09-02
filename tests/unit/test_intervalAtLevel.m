% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_intervalAtLevel
% TEST_INTERVALATLEVEL  Re-expressing a stored estimate at another level.
%
%   Two claims, and the second is the one that matters:
%
%   1. Re-deriving from .sem and .df gives EXACTLY what computing at that level
%      from the curves gives. If it did not, the confidence level could not be
%      a draw option and would have to trigger a recompute.
%   2. The bounds and the .note move together. differenceInterval stores a
%      pre-formatted 'unpaired, 95% CI' that ends up in a plot title and in an
%      exported figure's footer, so a 90% band labelled 95% is a wrong number
%      on a figure that outlives the session - the one failure here that does
%      real damage, because both halves look right on their own.
%
%   Run: runtests('tests/unit/test_intervalAtLevel')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('intervalAtLevel'));
end

function c = curvesOf(n, offset)
t = linspace(0, pi, 60);
c = sin(t) .* (1:n)' + offset;
end

% -- the equivalence that makes it a draw option -------------------------

function test_reDerivingMatchesComputingAtThatLevel(testCase)
A = curvesOf(6, 0);
for lvl = [0.80 0.90 0.99]
    stored = intervalAtLevel(curveInterval({A}, 'unpaired'), lvl);
    fresh  = curveInterval({A}, 'unpaired', lvl);
    testCase.verifyEqual(stored.lo, fresh.lo, 'AbsTol', 1e-12, ...
        sprintf('level %g', lvl));
    testCase.verifyEqual(stored.hi, fresh.hi, 'AbsTol', 1e-12);
end
end

function test_theEquivalenceHoldsForThePairedNormalisationToo(testCase)
% The Cousineau-Morey normalisation and Morey's correction are inside .sem and
% do not depend on the level. If that were wrong, a paired band would be
% subtly off at any level but 0.95 and nothing would say so.
A = curvesOf(5, 0);
B = curvesOf(5, 1.5);
stored = intervalAtLevel(curveInterval({A, B}, 'paired'), 0.9);
fresh  = curveInterval({A, B}, 'paired', 0.9);
for g = 1:2
    testCase.verifyEqual(stored(g).lo, fresh(g).lo, 'AbsTol', 1e-12);
    testCase.verifyEqual(stored(g).hi, fresh(g).hi, 'AbsTol', 1e-12);
end
end

function test_aDifferenceIntervalReDerivesTheSameWay(testCase)
A = curvesOf(5, 0);
B = curvesOf(5, 1.5);
stored = intervalAtLevel(differenceInterval(A, B, 'paired'), 0.9);
fresh  = differenceInterval(A, B, 'paired', 0.9);
testCase.verifyEqual(stored.lo, fresh.lo, 'AbsTol', 1e-12);
testCase.verifyEqual(stored.hi, fresh.hi, 'AbsTol', 1e-12);
end

% -- the label moves with the bounds -------------------------------------

function test_theNoteIsRelabelledWithTheNewLevel(testCase)
est = differenceInterval(curvesOf(5, 0), curvesOf(5, 1), 'paired');
testCase.assertTrue(contains(est.note, '95% CI'));
out = intervalAtLevel(est, 0.9);
testCase.verifyEqual(out.note, 'paired, 90% CI', ...
    'a band and its label cannot be allowed to disagree');
end

function test_theNoteKeepsWhateverTheSourceCalledTheDesign(testCase)
% Only the level is replaced. Rebuilding the whole string here would make this
% function the second place the design wording lived.
est = differenceInterval(curvesOf(5, 0), curvesOf(5, 1), 'unpaired');
out = intervalAtLevel(est, 0.8);
testCase.verifyEqual(out.note, 'unpaired, 80% CI');
end

% -- the untouched cases -------------------------------------------------

function test_anEmptyLevelChangesNothing(testCase)
est = curveInterval({curvesOf(5, 0)}, 'unpaired');
testCase.verifyEqual(intervalAtLevel(est, []), est);
testCase.verifyEqual(intervalAtLevel(est), est);
end

function test_aDegenerateEstimateIsLeftAloneRatherThanErroring(testCase)
% One subject has no interval to rescale. curveInterval reports NaN bounds for
% it, and those must survive - inventing a band for n=1 would be worse than
% showing none.
est = curveInterval({curvesOf(1, 0)}, 'unpaired');
out = intervalAtLevel(est, 0.9);
testCase.verifyTrue(all(isnan(out.lo)));
testCase.verifyEqual(out.mean, est.mean);
end

function test_anImpossibleLevelIsAnErrorNotASilentBand(testCase)
% A level of 0, 1 or 95 (someone typing per cent) has no interval. Drawing
% something anyway would put an unlabelled and meaningless band on a figure.
est = curveInterval({curvesOf(5, 0)}, 'unpaired');
for bad = [0 1 95 -0.5 Inf]
    testCase.verifyError(@() intervalAtLevel(est, bad), 'nestapp:badLevel', ...
        sprintf('level %g', bad));
end
end
