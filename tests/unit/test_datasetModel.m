% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_datasetModel
% TEST_DATASETMODEL  Subject inference, filter grouping, and the counts.
%
%   These three functions decide which recordings belong to whom and to which
%   condition, which fixes n for every estimate downstream. The failures that
%   matter here are the silent ones: a subject id that merges two people, a
%   filter that sweeps the whole cohort into one group, or a count that reports
%   files where it should report subjects.
%
%   Fixtures use the cohort's real naming
%   (rtmsct001_1_pre_SPL_tesa_pipeline4th.set) so the tests fail if the
%   heuristics stop working on the data they were written for.
%
%   Run: runtests('tests/unit/test_datasetModel')
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

function e = makeEntries(paths, subjects, groups)
e = struct('path', paths, 'subject', subjects, 'group', groups);
end

% ── inferSubjectIds ───────────────────────────────────────────────────────

function test_realCohortNamingYieldsSubjectToken(testCase)
paths = {'C:/data/rtmsct001_1_pre_SPL_tesa_pipeline4th.set', ...
         'C:/data/rtmsct003_1_post_SPL_tesa_pipeline4th.set'};
[ids, confident] = inferSubjectIds(paths);
testCase.verifyEqual(ids, {'rtmsct001', 'rtmsct003'});
testCase.verifyTrue(all(confident), ...
    'letters+digits is an identifier, not a condition word');
end

function test_folderAgreementIsConfident(testCase)
% Folder and filename agreeing is the strongest signal available.
[ids, confident] = inferSubjectIds({'C:/study/S01/S01_pre_TEP.set'});
testCase.verifyEqual(ids{1}, 'S01');
testCase.verifyTrue(confident);
end

function test_digitlessTokenIsNotTrusted(testCase)
% "pre" is a condition, not a person. Guess it, but flag it for review -
% silently trusting this would split one subject across many "subjects".
[ids, confident] = inferSubjectIds({'C:/data/pre_run_TEP.set'});
testCase.verifyEqual(ids{1}, 'pre');
testCase.verifyFalse(confident, 'a digitless token must be flagged');
end

function test_acceptsCharAndEmpty(testCase)
testCase.verifyEqual(inferSubjectIds('C:/d/S09_a.set'), {'S09'});
testCase.verifyEmpty(inferSubjectIds({}));
end

% ── assignGroupByFilter ───────────────────────────────────────────────────

function test_filterAssignsOnlyMatchingEntries(testCase)
e = makeEntries({'C:/d/rtmsct001_1_pre_SPL.set', 'C:/d/rtmsct001_1_post_SPL.set'}, ...
                {'rtmsct001', 'rtmsct001'}, {'', ''});
[e, n] = assignGroupByFilter(e, '_pre_', 'pre');
testCase.verifyEqual(n, 1);
testCase.verifyEqual(e(1).group, 'pre');
testCase.verifyEmpty(e(2).group);
end

function test_matchingIsCaseInsensitive(testCase)
% selectDataTree lowercases both sides; this must agree or the filter that
% found the files would not group them.
e = makeEntries({'C:/d/RTMSCT001_1_PRE.set'}, {'rtmsct001'}, {''});
[~, n] = assignGroupByFilter(e, 'pre', 'pre');
testCase.verifyEqual(n, 1);
end

function test_emptyPatternMatchesNothing(testCase)
% Not-yet-typed must not sweep the whole cohort into one group.
e = makeEntries({'C:/d/a.set', 'C:/d/b.set'}, {'a', 'b'}, {'', ''});
[e, n] = assignGroupByFilter(e, '   ', 'everything');
testCase.verifyEqual(n, 0);
testCase.verifyEmpty(e(1).group);
end

function test_rootFolderKeepsPatternOffTheParentDirs(testCase)
% The cohort living under a folder containing the word must not make every
% file match it.
e = makeEntries({'C:/preprocessed/rtmsct001_post.set'}, {'rtmsct001'}, {''});
[~, nAbs] = assignGroupByFilter(e, 'pre', 'pre');
testCase.verifyEqual(nAbs, 1, 'absolute match sees the parent folder');
[~, nRel] = assignGroupByFilter(e, 'pre', 'pre', 'C:/preprocessed');
testCase.verifyEqual(nRel, 0, 'relative match must ignore the parent folder');
end

function test_backslashPathsMatchForwardSlashPatterns(testCase)
e = makeEntries({'C:\d\sub\rtmsct001_pre.set'}, {'rtmsct001'}, {''});
[~, n] = assignGroupByFilter(e, 'sub/rtmsct001', 'pre');
testCase.verifyEqual(n, 1, 'separators must be normalised before matching');
end

% ── datasetSummary ────────────────────────────────────────────────────────

function test_countsSubjectsNotFiles(testCase)
% The defect this whole layer exists to prevent: 4 recordings from 2 people
% is n=2, not n=4.
e = makeEntries({'a','b','c','d'}, {'s1','s1','s2','s2'}, {'pre','pre','pre','pre'});
g = datasetSummary(e);
testCase.verifyEqual(g.nFiles, 4);
testCase.verifyEqual(g.nSubjects, 2, 'n is subjects, not recordings');
end

function test_groupsAreReportedInFirstSeenOrder(testCase)
e = makeEntries({'a','b'}, {'s1','s1'}, {'post','pre'});
g = datasetSummary(e);
testCase.verifyEqual({g.name}, {'post', 'pre'});
end

function test_completeCasesAreTheIntersection(testCase)
% s2 has no post session, so a paired contrast is defined on s1 alone.
e = makeEntries({'a','b','c'}, {'s1','s1','s2'}, {'pre','post','pre'});
[~, overall] = datasetSummary(e);
testCase.verifyEqual(overall.nSubjects, 2);
testCase.verifyEqual(overall.completeSubjects, {'s1'});
testCase.verifyEqual(overall.nComplete, 1, ...
    'a figure must be able to say "1 of 2 complete pairs"');
end

function test_scalesBeyondTwoGroups(testCase)
% Three groups is the case in the motivating figure (HC / NSI / SI).
e = makeEntries({'a','b','c','d'}, {'s1','s1','s1','s2'}, ...
                {'HC','NSI','SI','HC'});
[g, overall] = datasetSummary(e);
testCase.verifyEqual(overall.nGroups, 3);
testCase.verifyEqual(numel(g), 3);
testCase.verifyEqual(overall.completeSubjects, {'s1'});
end

function test_ungroupedEntriesAreCountedNotSilentlyDropped(testCase)
e = makeEntries({'a','b'}, {'s1','s2'}, {'pre',''});
[g, overall] = datasetSummary(e);
testCase.verifyEqual(overall.nUngrouped, 1);
testCase.verifyEqual(overall.nFiles, 1, 'ungrouped files are not in the dataset');
testCase.verifyEqual(numel(g), 1);
end

function test_filesPresentButNoneGroupedIsSafe(testCase)
% Distinct from empty input, and the normal state while the user is still
% defining groups. A preallocation added to silence a lint warning turned this
% into groups(0) = ..., which errors.
e = makeEntries({'a','b'}, {'s1','s2'}, {'',''});
[g, overall] = datasetSummary(e);
testCase.verifyEmpty(g);
testCase.verifyEqual(overall.nGroups, 0);
testCase.verifyEqual(overall.nUngrouped, 2);
testCase.verifyEqual(overall.nFiles, 0, 'ungrouped files are not in the dataset');
end

function test_emptyInputIsSafe(testCase)
[g, overall] = datasetSummary(struct('path', {}, 'subject', {}, 'group', {}));
testCase.verifyEmpty(g);
testCase.verifyEqual(overall.nGroups, 0);
end
