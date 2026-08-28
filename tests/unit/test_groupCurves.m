% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_groupCurves
% TEST_GROUPCURVES  Reduction at load time, and subject-first aggregation.
%
%   These two functions carry the corrections that motivated the redesign:
%   trials are discarded at load (so a cohort costs MB, not GB, and re-rendering
%   needs no I/O), files are averaged within subject before across subjects (so
%   n is people), electrodes are intersected across all groups (so conditions
%   are not compared over different montages), and paired designs are restricted
%   to complete cases with the exclusions named.
%
%   A synthetic loader is injected, so nothing here needs EEGLAB or real data.
%
%   Run: runtests('tests/unit/test_groupCurves')
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
% A dataset whose trial average is exactly `level` everywhere, so any weighted
% mean downstream has an arithmetically predictable value.
nCh = numel(labels);
nT  = numel(time);
EEG = struct();
EEG.data     = repmat(level, nCh, nT, nTrials);
EEG.times    = time;
EEG.chanlocs = struct('labels', labels);
end

function fcn = loaderFor(map)
% map: containers.Map path -> EEG struct
fcn = @(p) map(p);
end

function [cache, entries] = twoGroupFixture(~)
time   = -100:2:200;
labels = {'F3', 'FC3', 'CZ'};
specs = { ...
    'A_pre.set',  's1', 'pre',  100, 1; ...
    'B_pre.set',  's2', 'pre',  100, 3; ...
    'A_post.set', 's1', 'post', 100, 2; ...
    'B_post.set', 's2', 'post', 100, 4};
map = containers.Map();
for i = 1:size(specs, 1)
    map(specs{i,1}) = fakeEEG(labels, time, specs{i,4}, specs{i,5});
end
cache   = loadReducedSets(specs(:,1)', struct('loadFcn', loaderFor(map)));
entries = struct('path', specs(:,1)', 'subject', specs(:,2)', 'group', specs(:,3)');
end

function o = optsTEP(varargin)
o = struct('roi', {{'F3', 'FC3'}}, 'mode', 'TEP', 'smoothWin', 0);
for k = 1:2:numel(varargin); o.(varargin{k}) = varargin{k+1}; end
end

% ── loadReducedSets ───────────────────────────────────────────────────────

function test_keepsTrialAverageAndDiscardsTrials(testCase)
map = containers.Map({'x.set'}, {fakeEEG({'A','B'}, 0:4, 50, 7)});
cache = loadReducedSets({'x.set'}, struct('loadFcn', loaderFor(map)));
testCase.verifyTrue(cache.ok);
testCase.verifyEqual(size(cache.trialAvg), [2 5], ...
    'the cache holds channels x time, not the epochs');
testCase.verifyEqual(cache.nTrials, 50, 'trial count survives for weighting');
testCase.verifyEqual(cache.trialAvg, repmat(7, 2, 5), 'AbsTol', 1e-12);
end

function test_aFailedFileIsReportedNotFatal(testCase)
map = containers.Map({'good.set'}, {fakeEEG({'A'}, 0:3, 10, 1)});
[cache, warns] = loadReducedSets({'good.set', 'missing.set'}, ...
    struct('loadFcn', @(p) map(p)));
testCase.verifyTrue(cache(1).ok);
testCase.verifyFalse(cache(2).ok);
testCase.verifyNumElements(warns, 1);
testCase.verifyTrue(contains(warns{1}, 'missing.set'));
end

% ── groupCurves: the aggregation contract ─────────────────────────────────

function test_nIsSubjectsNotFiles(testCase)
% The defect that motivated the redesign: two people with two sessions each is
% n=2, not n=4.
[cache, entries] = twoGroupFixture();
res = groupCurves(cache, entries, optsTEP());
pre = res.groups(strcmp({res.groups.name}, 'pre'));
testCase.verifyEqual(pre.nFiles, 2);
testCase.verifyEqual(pre.nSubjects, 2);
testCase.verifyEqual(size(pre.curves, 1), 2, 'one row per subject');
testCase.verifyEqual(res.est(1).n, 2);
end

function test_repeatSessionsAreWeightedByTrialCount(testCase)
% One subject, two sessions of unequal length: the subject's curve must be the
% trial-weighted mean, not the plain mean of the two sessions.
time = 0:4; labels = {'F3'};
map = containers.Map( ...
    {'s1_a.set', 's1_b.set'}, ...
    {fakeEEG(labels, time, 30, 1), fakeEEG(labels, time, 90, 5)});
cache   = loadReducedSets({'s1_a.set','s1_b.set'}, struct('loadFcn', loaderFor(map)));
entries = struct('path', {'s1_a.set','s1_b.set'}, ...
                 'subject', {'s1','s1'}, 'group', {'g','g'});
res = groupCurves(cache, entries, optsTEP('roi', {'F3'}));
expected = (30 * 1 + 90 * 5) / 120;      % = 4, not the unweighted 3
testCase.verifyEqual(res.groups.curves(1,1), expected, 'AbsTol', 1e-12);
end

function test_channelsAreIntersectedAcrossAllGroups(testCase)
% A channel missing from one group must not be used in another, or the two
% conditions are averaged over different montages.
time = 0:3;
map = containers.Map( ...
    {'a.set', 'b.set'}, ...
    {fakeEEG({'F3','FC3','CZ'}, time, 10, 1), fakeEEG({'F3','CZ'}, time, 10, 1)});
cache   = loadReducedSets({'a.set','b.set'}, struct('loadFcn', loaderFor(map)));
entries = struct('path', {'a.set','b.set'}, 'subject', {'s1','s2'}, ...
                 'group', {'pre','post'});
res = groupCurves(cache, entries, optsTEP('roi', {'F3','CZ'}));
testCase.verifyEqual(sort(res.channelLabels), {'CZ','F3'}, ...
    'FC3 exists in only one group and must be excluded everywhere');
end

function test_roiChangeNeedsNoReloadAndMovesTheCurve(testCase)
% The user-visible promise: re-rendering with a different ROI is arithmetic on
% the cache. The loader is booby-trapped to fail if called again.
time = 0:3;
map = containers.Map({'a.set'}, {fakeEEG({'F3','CZ'}, time, 10, 1)});
cache = loadReducedSets({'a.set'}, struct('loadFcn', loaderFor(map)));
cache(1).trialAvg = [ones(1,4); 5*ones(1,4)];    % F3 = 1, CZ = 5
entries = struct('path', {'a.set'}, 'subject', {'s1'}, 'group', {'g'});

r1 = groupCurves(cache, entries, optsTEP('roi', {'F3'}));
r2 = groupCurves(cache, entries, optsTEP('roi', {'CZ'}));
r3 = groupCurves(cache, entries, optsTEP('roi', {'F3','CZ'}));
testCase.verifyEqual(r1.groups.curves(1,1), 1, 'AbsTol', 1e-12);
testCase.verifyEqual(r2.groups.curves(1,1), 5, 'AbsTol', 1e-12);
testCase.verifyEqual(r3.groups.curves(1,1), 3, 'AbsTol', 1e-12);
end

function test_modesShareOneDefinitionWithTepFieldCurve(testCase)
time = 0:3;
map = containers.Map({'a.set'}, {fakeEEG({'F3','CZ'}, time, 10, 1)});
cache = loadReducedSets({'a.set'}, struct('loadFcn', loaderFor(map)));
cache(1).trialAvg = [ones(1,4); 5*ones(1,4)];
entries = struct('path', {'a.set'}, 'subject', {'s1'}, 'group', {'g'});
res = groupCurves(cache, entries, optsTEP('mode', 'GMFP'));
expected = tepFieldCurve(cache(1).trialAvg, [1 2], 'GMFP');
testCase.verifyEqual(res.groups.curves(1,:), expected, 'AbsTol', 1e-12);
end

function test_pairedDropsIncompleteSubjectsAndNamesThem(testCase)
% s2 has no post session. A paired estimate must exclude them and say so.
time = 0:3; labels = {'F3'};
paths = {'s1_pre.set','s2_pre.set','s1_post.set'};
map = containers.Map(paths, ...
    {fakeEEG(labels,time,10,1), fakeEEG(labels,time,10,2), fakeEEG(labels,time,10,3)});
cache   = loadReducedSets(paths, struct('loadFcn', loaderFor(map)));
entries = struct('path', paths, 'subject', {'s1','s2','s1'}, ...
                 'group', {'pre','pre','post'});
res = groupCurves(cache, entries, optsTEP('roi', {'F3'}, 'design', 'paired'));
testCase.verifyEqual(res.complete, {'s1'});
testCase.verifyEqual(res.dropped, {'s2'}, 'the exclusion must be reportable');
testCase.verifyEqual([res.groups.nSubjects], [1 1]);
end

function test_unpairedKeepsEveryone(testCase)
time = 0:3; labels = {'F3'};
paths = {'s1_pre.set','s2_pre.set','s3_post.set'};
map = containers.Map(paths, ...
    {fakeEEG(labels,time,10,1), fakeEEG(labels,time,10,2), fakeEEG(labels,time,10,3)});
cache   = loadReducedSets(paths, struct('loadFcn', loaderFor(map)));
entries = struct('path', paths, 'subject', {'s1','s2','s3'}, ...
                 'group', {'pre','pre','post'});
res = groupCurves(cache, entries, optsTEP('roi', {'F3'}, 'design', 'unpaired'));
testCase.verifyEqual([res.groups.nSubjects], [2 1], ...
    'unpaired groups may have different n');
testCase.verifyEmpty(res.dropped);
end

function test_scalesToThreeGroups(testCase)
time = 0:3; labels = {'F3'};
paths = {'a.set','b.set','c.set'};
map = containers.Map(paths, ...
    {fakeEEG(labels,time,10,1), fakeEEG(labels,time,10,2), fakeEEG(labels,time,10,3)});
cache   = loadReducedSets(paths, struct('loadFcn', loaderFor(map)));
entries = struct('path', paths, 'subject', {'s1','s2','s3'}, ...
                 'group', {'HC','NSI','SI'});
res = groupCurves(cache, entries, optsTEP('roi', {'F3'}));
testCase.verifyNumElements(res.groups, 3);
testCase.verifyEqual({res.groups.name}, {'HC','NSI','SI'});
end

function test_chanMeansAreKeptForTopographies(testCase)
[cache, entries] = twoGroupFixture();
res = groupCurves(cache, entries, optsTEP());
testCase.verifyEqual(size(res.groups(1).chanMeans), ...
    [numel(res.channelLabels), numel(res.time)], ...
    'scalp maps need channels x time per group');
testCase.verifyNumElements(res.chanlocs, numel(res.channelLabels));
end

function test_ungroupedFilesAreIgnored(testCase)
[cache, entries] = twoGroupFixture();
entries(1).group = '';
res = groupCurves(cache, entries, optsTEP());
pre = res.groups(strcmp({res.groups.name}, 'pre'));
testCase.verifyEqual(pre.nFiles, 1);
end

function test_roiMatchingNothingErrorsClearly(testCase)
[cache, entries] = twoGroupFixture();
testCase.verifyError(@() groupCurves(cache, entries, optsTEP('roi', {'OZ'})), ...
    'nestapp:emptyROI');
end
