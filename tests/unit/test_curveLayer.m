% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_curveLayer
% TEST_CURVELAYER  Time-base alignment and confidence intervals.
%
%   Both functions here replace something that used to be silently wrong: the
%   app's time axis was whatever the last-loaded file had, and its shaded band
%   was half a standard error with no label. The tests pin the behaviour that
%   makes those failures loud - a mismatched sample rate must error rather than
%   plot, and a paired interval must differ from an unpaired one on the same
%   data.
%
%   Run: runtests('tests/unit/test_curveLayer')
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

% ── tCritical ─────────────────────────────────────────────────────────────

function test_tCriticalMatchesKnownValues(testCase)
% Textbook two-sided 95% values; independent of any toolbox being installed.
testCase.verifyEqual(tCritical(1,  0.05), 12.7062047362, 'AbsTol', 1e-8);
testCase.verifyEqual(tCritical(10, 0.05),  2.2281388520, 'AbsTol', 1e-8);
testCase.verifyEqual(tCritical(30, 0.05),  2.0422724563, 'AbsTol', 1e-8);
end

function test_tCriticalIsVectorisedAndGuardsTinyDf(testCase)
t = tCritical([1 10 30], 0.05);
testCase.verifyNumElements(t, 3);
testCase.verifyEqual(tCritical(0, 0.05), Inf, ...
    'no spread can be estimated from one observation');
end

% ── commonTimeBase ────────────────────────────────────────────────────────

function test_identicalTimeBasesPassThrough(testCase)
v = -100:2:300;
[t, idx, info] = commonTimeBase({v, v, v});
testCase.verifyEqual(t, v);
testCase.verifyEqual(idx{2}, 1:numel(v));
testCase.verifyFalse(info.cropped);
testCase.verifyEqual(info.fs, 500, 'AbsTol', 1e-9);
end

function test_sampleRateMismatchErrorsAndNamesTheFile(testCase)
% The bug this replaces: the app took the last file's time base and plotted
% incomparable data against it without a word.
try
    commonTimeBase({-100:1:300, -100:2:300}, {'fileA.set', 'fileB.set'});
    testCase.verifyFail('a sample rate mismatch must not be silently accepted');
catch ME
    testCase.verifyEqual(ME.identifier, 'nestapp:sampleRateMismatch');
    testCase.verifyTrue(contains(ME.message, 'fileB.set'), ...
        'the message must name which file disagrees');
end
end

function test_differentExtentsCropToTheOverlap(testCase)
[t, idx, info] = commonTimeBase({-1000:2:1000, -500:2:500});
testCase.verifyEqual(t(1),   -500);
testCase.verifyEqual(t(end),  500);
testCase.verifyTrue(info.cropped);
testCase.verifyNumElements(idx{1}, numel(t));
testCase.verifyNumElements(idx{2}, numel(t));
end

function test_croppingIndicesActuallyAlignTheData(testCase)
% The indices are the contract: curve(idx) must line up with t.
a = -1000:2:1000;
b = -500:2:500;
[t, idx] = commonTimeBase({a, b});
testCase.verifyEqual(a(idx{1}), t, 'AbsTol', 1e-9);
testCase.verifyEqual(b(idx{2}), t, 'AbsTol', 1e-9);
end

function test_noOverlapErrors(testCase)
testCase.verifyError(@() commonTimeBase({-1000:2:-600, 0:2:500}), ...
    'nestapp:noTimeOverlap');
end

% ── curveInterval ─────────────────────────────────────────────────────────

function X = rampSubjects(n, nT, offsets)
% n subjects x nT samples; each subject offset by a constant so that between-
% subject variance is large and within-subject differences are tiny.
X = repmat(sin(linspace(0, pi, nT)), n, 1) + offsets(:);
end

function test_unpairedIntervalIsMeanPlusMinusTTimesSem(testCase)
X = [1 2; 3 4; 5 6; 7 8];
est = curveInterval({X}, 'unpaired');
n   = 4;
sem = std(X, 0, 1) / sqrt(n);
t   = tCritical(n - 1, 0.05);
testCase.verifyEqual(est.mean, mean(X, 1), 'AbsTol', 1e-12);
testCase.verifyEqual(est.hi, mean(X, 1) + t * sem, 'AbsTol', 1e-12);
testCase.verifyEqual(est.n, 4, 'n is subjects');
end

function test_pairedIntervalIsNarrowerWhenSubjectsDifferInOffset(testCase)
% The point of the paired interval: a subject who is high in every condition
% says nothing about the difference between conditions, so removing that
% between-subject spread must tighten the band substantially.
offsets = [0; 10; 20; 30];
A = rampSubjects(4, 8, offsets);
B = A + 0.5;                       % identical within-subject shift

unp = curveInterval({A, B}, 'unpaired');
par = curveInterval({A, B}, 'paired');

testCase.verifyEqual(par(1).mean, unp(1).mean, 'AbsTol', 1e-12, ...
    'the mean must not move; only the interval changes');
testCase.verifyLessThan(mean(par(1).hi - par(1).lo), ...
                        mean(unp(1).hi - unp(1).lo), ...
    'paired interval must exclude between-subject offset');
end

function test_pairedRequiresMatchedRows(testCase)
% Complete cases are the caller's job; silently truncating would pair the
% wrong people together.
testCase.verifyError( ...
    @() curveInterval({zeros(4, 5), zeros(3, 5)}, 'paired'), ...
    'nestapp:pairedGroupsUnequal');
end

function test_moreyCorrectionIsApplied(testCase)
% With J groups the normalised SD is scaled by sqrt(J/(J-1)); without it the
% interval is known to be too narrow.
A = rampSubjects(5, 4, [0; 1; 2; 3; 4]);
B = A + 0.25;
par = curveInterval({A, B}, 'paired');

stacked   = cat(3, A, B);
subjMean  = mean(stacked, 3);
grandMean = mean(subjMean, 1);
normA     = A - subjMean + grandMean;
expected  = std(normA, 0, 1) / sqrt(5) * sqrt(2 / 1);
testCase.verifyEqual(par(1).sem, expected, 'AbsTol', 1e-12);
end

function test_singleSubjectGivesNaNBoundsNotZeroWidth(testCase)
est = curveInterval({[1 2 3]}, 'unpaired');
testCase.verifyEqual(est.n, 1);
testCase.verifyTrue(all(isnan(est.lo)), ...
    'a zero-width band would imply certainty that is not there');
end

function test_scalesToThreeGroups(testCase)
A = rampSubjects(6, 5, (1:6)');
est = curveInterval({A, A + 1, A + 2}, 'paired');
testCase.verifyNumElements(est, 3);
testCase.verifyEqual([est.n], [6 6 6]);
end

function test_unknownDesignErrors(testCase)
testCase.verifyError(@() curveInterval({zeros(3,3)}, 'mixed'), ...
    'nestapp:unknownDesign');
end
