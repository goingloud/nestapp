% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_exploreLayer
% TEST_EXPLORELAYER  The headless Explore flow, end to end.
%
%   exploreDataset -> loadReducedSets -> groupCurves -> exploreMeasures /
%   exploreResults, with no app and no EEGLAB (a synthetic loader is injected).
%
%   That the whole flow runs without the GUI is the design commitment, not a
%   convenience: a script has to be able to reproduce any figure the app draws,
%   and a saved result has to be consumable by the same functions that made it.
%   If these tests ever need a window, that promise has been broken.
%
%   Run: runtests('tests/unit/test_exploreLayer')
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

% ── fixtures ──────────────────────────────────────────────────────────────

function EEG = fakeEEG(labels, time, nTrials, level)
EEG = struct('data', repmat(level, numel(labels), numel(time), nTrials), ...
             'times', time, 'chanlocs', struct('labels', labels));
end

function [paths, map] = cohort()
% Two subjects, pre and post, on the cohort's real naming shape.
time   = -100:2:200;
labels = {'AF3', 'F3', 'FC3', 'Cz'};
spec = { ...
    'rtmsct001_1_pre_SPL.set',  1; ...
    'rtmsct001_1_post_SPL.set', 3; ...
    'rtmsct003_1_pre_SPL.set',  2; ...
    'rtmsct003_1_post_SPL.set', 5};
paths = spec(:, 1)';
map   = containers.Map();
for i = 1:size(spec, 1)
    map(spec{i, 1}) = fakeEEG(labels, time, 100, spec{i, 2});
end
end

function [res, entries] = runFlow(design)
[paths, map] = cohort();
entries = exploreDataset(paths, {'_pre_', 'pre'; '_post_', 'post'});
cache   = loadReducedSets(paths, struct('loadFcn', @(p) map(p)));
res     = groupCurves(cache, entries, struct( ...
    'roi', {{'AF3', 'F3', 'FC3'}}, 'mode', 'TEP', ...
    'design', design, 'smoothWin', 0));
end

function w = twoWindows()
w = struct('name', {'early', 'late'}, 'polarity', {'pos', 'neg'}, ...
           'winStart', {0, 100}, 'winEnd', {50, 200});
end

% ── exploreDataset ────────────────────────────────────────────────────────

function test_filterRulesBuildTheGroups(testCase)
[paths, ~] = cohort();
[entries, summary] = exploreDataset(paths, {'_pre_', 'pre'; '_post_', 'post'});
testCase.verifyEqual({entries.group}, {'pre', 'post', 'pre', 'post'});
testCase.verifyEqual(summary.nGroups, 2);
testCase.verifyEqual(summary.nSubjects, 2, 'four files, two people');
testCase.verifyEqual(summary.nComplete, 2, 'both have a pre and a post');
end

function test_subjectsAreInferredFromTheRealNamingShape(testCase)
[paths, ~] = cohort();
entries = exploreDataset(paths, {});
testCase.verifyEqual(unique({entries.subject}), {'rtmsct001', 'rtmsct003'});
testCase.verifyTrue(all([entries.subjectConfident]), ...
    'letters-and-digits ids are trustworthy and reported as such');
end

function test_theFirstMatchingRuleWins(testCase)
% Overlapping patterns must degrade to "first match", not silently reassign.
[paths, ~] = cohort();
entries = exploreDataset(paths, {'rtmsct001', 'bySubject'; '_pre_', 'pre'});
testCase.verifyEqual({entries.group}, ...
    {'bySubject', 'bySubject', 'pre', ''}, ...
    'rule 1 claims both of subject 001; rule 2 gets only the remaining pre');
end

function test_unmatchedFilesStayUngrouped(testCase)
[paths, ~] = cohort();
[entries, summary] = exploreDataset(paths, {'_pre_', 'pre'});
testCase.verifyEqual(summary.nUngrouped, 2);
testCase.verifyEqual(summary.nGroups, 1);
end

function test_givenSubjectIdsOverrideInference(testCase)
[paths, ~] = cohort();
entries = exploreDataset(paths, {}, struct('subjects', {{'a','a','b','b'}}));
testCase.verifyEqual({entries.subject}, {'a','a','b','b'});
end

function test_aWrongSubjectCountIsAnError(testCase)
[paths, ~] = cohort();
testCase.verifyError(@() exploreDataset(paths, {}, ...
    struct('subjects', {{'only-one'}})), 'nestapp:subjectCountMismatch');
end

function test_malformedRulesAreRejected(testCase)
[paths, ~] = cohort();
testCase.verifyError(@() exploreDataset(paths, {'onlyOneColumn'}), ...
    'nestapp:badGroupRules');
end

% ── the flow ──────────────────────────────────────────────────────────────

function test_theWholeFlowRunsWithNoAppAndNoEeglab(testCase)
[res, ~] = runFlow('paired');
testCase.verifyEqual(numel(res.groups), 2);
testCase.verifyEqual({res.groups.name}, {'pre', 'post'});
testCase.verifyEqual([res.groups.nSubjects], [2 2]);
testCase.verifyNumElements(res.est, 2);
testCase.verifyNotEmpty(res.contrast, ...
    'two groups means a contrast is available');
end

% ── exploreMeasures ───────────────────────────────────────────────────────

function test_measuresAreOneRowPerGroupSubjectWindow(testCase)
[res, ~] = runFlow('unpaired');
T = exploreMeasures(res, twoWindows());
testCase.verifyEqual(height(T), 2 * 2 * 2, ...
    '2 groups x 2 subjects x 2 windows');
testCase.verifyTrue(all(ismember({'group', 'subject', 'window', 'mean_uV'}, ...
                                 T.Properties.VariableNames)));
end

function test_measuresCarryGroupAndSubjectNotFile(testCase)
% Rows are subjects: groupCurves has already collapsed files, so a 'file'
% column would be a lie about what the number describes.
[res, ~] = runFlow('unpaired');
T = exploreMeasures(res, twoWindows());
testCase.verifyFalse(ismember('file', T.Properties.VariableNames));
testCase.verifyEqual(sort(unique(T.group)), {'post'; 'pre'});
testCase.verifyEqual(sort(unique(T.subject)), {'rtmsct001'; 'rtmsct003'});
end

function test_measureValuesMatchTepWindowTable(testCase)
% The arithmetic must be the shared one, not a reimplementation.
[res, ~] = runFlow('unpaired');
w   = twoWindows();
T   = exploreMeasures(res, w);
pre = res.groups(strcmp({res.groups.name}, 'pre'));
ref = tepWindowTable(pre.subjects, pre.curves, res.time, w, 'TEP');
mine = T(strcmp(T.group, 'pre'), :);
testCase.verifyEqual(mine.mean_uV, ref.mean_uV, 'AbsTol', 1e-12);
end

function test_measuresDefaultToTheStandardWindows(testCase)
[res, ~] = runFlow('unpaired');
T = exploreMeasures(res);
testCase.verifyEqual(numel(unique(T.window)), ...
    numel(defaultTEPComponentDefs()), ...
    'the same windows the TEP-topo maps are placed at');
end

function test_measuresOfAnEmptyResultAreAnEmptyTable(testCase)
T = exploreMeasures(struct('groups', struct('name', {}), 'time', []), twoWindows());
testCase.verifyEqual(height(T), 0);
end

% ── exploreResults ────────────────────────────────────────────────────────

function test_resultsCarryTheCurvesAndTheMeasures(testCase)
[res, entries] = runFlow('paired');
out = exploreResults(res, entries, struct('roi', {{'AF3','F3','FC3'}}, ...
                                          'windows', twoWindows()));
testCase.verifyEqual(out.time, res.time);
testCase.verifyEqual(size(out.groups(1).curves), size(res.groups(1).curves));
testCase.verifyEqual(height(out.measures), 8, ...
    'the small tabular form travels with the curves it came from');
testCase.verifyEqual(out.roi, {'AF3','F3','FC3'});
testCase.verifyEqual(out.design, 'paired');
end

function test_resultsRecordEveryInputFileWithItsGroup(testCase)
[res, entries] = runFlow('paired');
out = exploreResults(res, entries);
testCase.verifyNumElements(out.files, 4);
testCase.verifyEqual({out.files.group}, {'pre','post','pre','post'});
end

function test_provenanceIsEmbeddedNotASidecar(testCase)
[res, entries] = runFlow('unpaired');
out = exploreResults(res, entries, struct('plot', 'TEP (ROI mean)'));
p = out.provenance;
testCase.verifyNotEmpty(p.nestapp);
testCase.verifyNotEmpty(p.created);
testCase.verifyEqual(p.plot, 'TEP (ROI mean)');
testCase.verifyTrue(isfield(p, 'montage'), ...
    'the montage report must travel with the result');
end

function test_exclusionsAreReported(testCase)
% What was left out is part of what the result means.
[res, entries] = runFlow('paired');
out = exploreResults(res, entries);
testCase.verifyTrue(isfield(out.excluded, 'montageFiles'));
testCase.verifyTrue(isfield(out.excluded, 'unpairedSubjects'));
end

function test_resultsSurviveASaveAndLoadRoundTrip(testCase)
% The Results exit is a .mat; it has to come back as what went in.
[res, entries] = runFlow('paired');
out = exploreResults(res, entries, struct('roi', {{'AF3'}}));
f = [tempname '.mat'];
testCase.addTeardown(@() deleteIfPresent(f));
save(f, 'out');
loaded = load(f, 'out');
testCase.verifyEqual(loaded.out.time, out.time);
testCase.verifyEqual(loaded.out.roi, {'AF3'});
testCase.verifyEqual(height(loaded.out.measures), height(out.measures));
end

function deleteIfPresent(f)
if isfile(f); delete(f); end
end
