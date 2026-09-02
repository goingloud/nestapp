% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_drawWindowBars
% TEST_DRAWWINDOWBARS  The quantification view: a bar per group, per window.
%
%   No EEGLAB needed - this plot never touches chanlocs or topoplot.
%
%   What is worth pinning is the measurement, not the drawing. Two ways of
%   getting a "group peak" look identical in the picture and differ in the
%   number, and only one of them is right:
%
%     per-subject then average - measure each subject's own curve, average the
%                                values. What this draws, and what the CSV says.
%     average then measure     - measure the group-mean curve. Attenuated by
%                                every millisecond of latency jitter between
%                                subjects, so it understates a component that is
%                                present in all of them at slightly different
%                                times.
%
%   The fixture below builds exactly that disagreement, so the test fails if the
%   order is ever swapped.
%
%   Run: runtests('tests/unit/test_drawWindowBars')
tests = functiontests(localfunctions);
end

% -- fixture --------------------------------------------------------------

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('drawWindowBars'));
end

function res = jitteredPeakRes()
% One group of three subjects, each a unit-height Gaussian bump inside the
% window but at a DIFFERENT latency. Every subject peaks at 1.0, so the
% per-subject mean peak is 1.0; the mean curve is broader and lower, so
% measuring it instead gives visibly less.
time  = 0:200;
peaks = [90 100 110];
curves = zeros(numel(peaks), numel(time));
for i = 1:numel(peaks)
    curves(i, :) = exp(-0.5 * ((time - peaks(i)) / 6).^2);
end

res = struct();
res.time          = time;
res.design        = 'unpaired';
res.channelLabels = {'E1'};
res.groups = struct('name', 'g', 'subjects', {{'s1', 's2', 's3'}}, ...
                    'curves', curves, ...
                    'chanMeans', mean(curves, 1), ...
                    'nFiles', 3, 'nSubjects', 3);
res.est = curveInterval({curves}, 'unpaired', 0.95);
end

function res = twoGroupRes()
time = 0:200;
a = repmat(sin(time / 30), 4, 1) + 0.10 * randn(4, numel(time));
b = repmat(sin(time / 30), 4, 1) * 2 + 0.10 * randn(4, numel(time));
res = struct();
res.time          = time;
res.design        = 'unpaired';
res.channelLabels = {'E1'};
res.groups = struct( ...
    'name',      {'pre', 'post'}, ...
    'subjects',  {{'s1','s2','s3','s4'}, {'s5','s6','s7','s8'}}, ...
    'curves',    {a, b}, ...
    'chanMeans', {mean(a, 1), mean(b, 1)}, ...
    'nFiles',    {4, 4}, 'nSubjects', {4, 4});
res.est = curveInterval({a, b}, 'unpaired', 0.95);
end

function fig = uiParent(testCase)
fig = uifigure('Visible', 'off', 'Position', [100 100 900 500]);
testCase.addTeardown(@() delete(fig));
end

function w = oneWindow()
w = struct('name', 'N100', 'winStart', 70, 'winEnd', 150);
end

% -- tests ----------------------------------------------------------------

function test_thePeakIsMeasuredPerSubjectNotOnTheGroupMean(testCase)
% The invariant the docstring is about. Every subject peaks at exactly 1.0, so
% the per-subject answer is 1.0; the group-mean curve is flattened by the
% latency spread and peaks lower. Measuring the average would pass silently.
res  = jitteredPeakRes();
info = drawWindowBars(uiParent(testCase), res, ...
    struct('windows', oneWindow(), 'measure', 'peak'));

testCase.verifyEqual(info.est{1}.mean, 1, 'AbsTol', 1e-9, ...
    'each subject peaks at 1.0, so the group mean of the peaks is 1.0');

meanCurvePeak = max(mean(res.groups.curves, 1));
testCase.verifyLessThan(meanCurvePeak, 0.95, ...
    'fixture is not exercising the difference - the mean curve should be flattened');
end

function test_theBarIsTheMeanOfWhatTheCsvWouldReport(testCase)
% What is drawn has to be the number that leaves in the Measures export, or the
% figure and the statistics someone runs from the CSV describe different things.
res  = twoGroupRes();
w    = oneWindow();
info = drawWindowBars(uiParent(testCase), res, struct('windows', w));

T = exploreMeasures(res, w);
for g = 1:numel(res.groups)
    rows = strcmp(T.group, res.groups(g).name) & strcmp(T.window, w.name);
    testCase.verifyEqual(info.est{1}(g).mean, mean(T.mean_uV(rows)), ...
        'AbsTol', 1e-12, 'the bar must equal the mean of the exported rows');
end
end

function test_theIntervalCountsSubjectsAndComesFromTheSharedEstimator(testCase)
% n is subjects, and the interval is curveInterval's - so the design rule and
% the paired correction cannot drift from the waveform band's.
res  = twoGroupRes();
info = drawWindowBars(uiParent(testCase), res, struct('windows', oneWindow()));
e    = info.est{1};

testCase.verifyEqual([e.n], [4 4]);
for g = 1:2
    testCase.verifyLessThan(e(g).lo, e(g).mean);
    testCase.verifyGreaterThan(e(g).hi, e(g).mean);
end
end

function test_onePanelPerWindow(testCase)
res  = twoGroupRes();
w    = [oneWindow(), struct('name', 'P180', 'winStart', 150, 'winEnd', 200)];
info = drawWindowBars(uiParent(testCase), res, struct('windows', w));
testCase.verifyEqual(numel(info.axes), 2);
testCase.verifyEqual(numel(info.est),  2);
end

function test_theLevelFollowsTheRunRatherThanALiteral(testCase)
% This function used to default opts.level to 0.95 of its own, independent of
% the level groupCurves had actually used. The two matched only because both
% defaults happened to be 0.95 - so a run at another level would have drawn
% these intervals at 0.95 while the status line and the exported figure's
% footer both stated the run's level.
%
% Asserted against a DOCTORED res.info.level, because that is the only way to
% tell "reads the recorded level" apart from "happens to agree with it".
res = twoGroupRes();
res.info = struct('level', 0.80);
fig = uiParent(testCase);

fromRun      = drawWindowBars(fig, res, struct('windows', oneWindow()));
askedFor80   = drawWindowBars(fig, res, struct('windows', oneWindow(), 'level', 0.80));
askedFor95   = drawWindowBars(fig, res, struct('windows', oneWindow(), 'level', 0.95));

testCase.verifyEqual(fromRun.est{1}(1).lo, askedFor80.est{1}(1).lo, ...
    'AbsTol', 1e-12, 'unset must follow the level the run was computed at');
testCase.verifyNotEqual(fromRun.est{1}(1).lo, askedFor95.est{1}(1).lo, ...
    'and must not silently fall back to a literal 0.95');
end

function test_aResultPredatingTheRecordedLevelStillDraws(testCase)
% res.info.level is new; a session saved before it simply lacks the field, and
% then curveInterval's own default applies rather than an error.
res = twoGroupRes();
testCase.assertFalse(isfield(res, 'info'));
fig  = uiParent(testCase);
info = drawWindowBars(fig, res, struct('windows', oneWindow()));
testCase.verifyNotEmpty(info.est{1}(1).lo);
end

function test_anEmptyWindowSetDrawsNothing(testCase)
res  = twoGroupRes();
info = drawWindowBars(uiParent(testCase), res, struct('windows', struct( ...
    'name', {}, 'winStart', {}, 'winEnd', {})));
testCase.verifyEmpty(info.axes);
end
