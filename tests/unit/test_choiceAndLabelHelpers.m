% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_choiceAndLabelHelpers
% TEST_CHOICEANDLABELHELPERS  matchesChoice, ciLabel and fieldOr.
%
%   Three small shared helpers, each extracted from copies that had started to
%   drift. What is worth pinning is the drift itself:
%
%   matchesChoice replaced three hand-rolled enum comparisons in three draw
%   functions. Two stripped only spaces and one stripped spaces and hyphens,
%   so 'per-map' matched in one and silently fell back to the default in the
%   others. The test therefore checks the spellings that differed.
%
%   ciLabel replaced three independent sprintf('%g%% CI') calls that reach a
%   plot title, a status line and an exported figure's footer. Two of them
%   showing different coverages for one band is the failure it prevents.
%
%   fieldOr was written out identically in two files with a third copy
%   starting. Its one real decision is that EMPTY COUNTS AS ABSENT.
%
%   Run: runtests('tests/unit/test_choiceAndLabelHelpers')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('matchesChoice'));
end

% -- matchesChoice --------------------------------------------------------

function test_theSpellingsThatUsedToDisagreeAllMatch(testCase)
% Exactly the drift: a hyphen matched in drawDifferenceWave's copy and not in
% drawGroupTopo's, for the same conceptual value.
for v = {'per map', 'per-map', 'PerMap', '  Per Map  ', 'per_map', 'PER MAP'}
    testCase.verifyTrue(matchesChoice(v{1}, 'per map'), v{1});
end
end

function test_theRegistrySpellingIsWhatCallersCompareAgainst(testCase)
% The choice as written in validRange, hyphens and spaces and all.
testCase.verifyTrue(matchesChoice('first-second', 'first - second'));
testCase.verifyTrue(matchesChoice('first - second', 'first - second'));
end

function test_adifferentChoiceDoesNotMatch(testCase)
testCase.verifyFalse(matchesChoice('per map', 'per window'));
testCase.verifyFalse(matchesChoice('shared', 'per map'));
end

function test_unsetMatchesNothing(testCase)
% An absent param must not accidentally select a non-default branch.
testCase.verifyFalse(matchesChoice([], 'per map'));
testCase.verifyFalse(matchesChoice('', 'per map'));
testCase.verifyFalse(matchesChoice('  ', 'per map'));
end

function test_aNonTextValueIsNotAChoiceName(testCase)
testCase.verifyFalse(matchesChoice(7, 'per map'));
testCase.verifyFalse(matchesChoice(true, 'per map'));
end

function test_aStringOrWrappedCellIsAcceptedLikeChar(testCase)
testCase.verifyTrue(matchesChoice("per map", 'per map'));
testCase.verifyTrue(matchesChoice({'per map'}, 'per map'));
end

% -- ciLabel -------------------------------------------------------------

function test_theCoverageIsRenderedAsAPercentage(testCase)
testCase.verifyEqual(ciLabel(0.95), '95% CI');
testCase.verifyEqual(ciLabel(0.9),  '90% CI');
testCase.verifyEqual(ciLabel(0.995), '99.5% CI');
end

function test_theStoredNoteAndTheStatusLineAgreeByConstruction(testCase)
% The point of sharing it: differenceInterval's note and the phrase the app
% builds for the footer must be the same string for the same level.
est = differenceInterval(rand(5, 20), rand(5, 20), 'unpaired', 0.9);
testCase.verifyTrue(endsWith(est.note, ciLabel(0.9)));
end

function test_noDefaultLevelIsInvented(testCase)
% Defaulting here would put a fourth copy of 0.95 in the codebase; the default
% belongs to curveInterval and groupCurves, which apply it.
testCase.verifyError(@() ciLabel([]), 'nestapp:badLevel');
testCase.verifyError(@() ciLabel('0.95'), 'nestapp:badLevel');
end

% -- fieldOr -------------------------------------------------------------

function test_aPresentFieldWins(testCase)
testCase.verifyEqual(fieldOr(struct('level', 0.9), 'level', 0.5), 0.9);
end

function test_anAbsentFieldFallsBack(testCase)
testCase.verifyEqual(fieldOr(struct('other', 1), 'level', 0.5), 0.5);
end

function test_emptyCountsAsAbsent(testCase)
% The one real decision, and the same convention fillDefaults uses: callers
% leave a field as [] to mean "you choose", so struct('level', []) must behave
% like omitting level entirely.
testCase.verifyEqual(fieldOr(struct('level', []), 'level', 0.5), 0.5);
end

function test_aNonStructFallsBackRatherThanErroring(testCase)
% Readers hand it whatever a saved .mat contained.
testCase.verifyEqual(fieldOr([], 'level', 0.5), 0.5);
testCase.verifyEqual(fieldOr(struct([]), 'level', 0.5), 0.5);
end
