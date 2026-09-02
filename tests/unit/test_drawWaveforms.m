% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_drawWaveforms
% TEST_DRAWWAVEFORMS  The waveform draw functions actually run.
%
%   Added because a parse error in drawDifferenceWave got past the whole fast
%   suite: nothing called it. These functions need only a figure - no EEGLAB -
%   so there was no excuse for leaving them unexercised. Headless-safe.
%
%   The assertions are deliberately structural rather than pixel-level: one
%   line per group, a band per group, n in the legend, and the arity contract.
%   Anything finer would break on cosmetic changes without catching more.
%
%   Run: runtests('tests/unit/test_drawWaveforms')
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

function ax = offscreenAxes(testCase)
fig = figure('Visible', 'off');
testCase.addTeardown(@() delete(fig));
ax = axes(fig);
end

function res = fakeRes(nGroups, design)
% nGroups groups of 4 subjects on a shared time base, each offset so the means
% differ and the intervals are non-degenerate.
time = -50:2:300;
names = {'pre', 'post', 'sham', 'other'};
res = struct('time', time, 'design', design, 'channelLabels', {{'F3'}}, ...
             'chanlocs', [], 'complete', {{}}, 'dropped', {{}}, ...
             'contrast', struct([]), 'info', struct());
g = struct('name', {}, 'subjects', {}, 'curves', {}, 'chanMeans', {}, ...
           'nFiles', {}, 'nSubjects', {}, 'files', {});
for k = 1:nGroups
    curves = sin(linspace(0, pi, numel(time))) .* (1:4)' + k;
    % Six recordings for four subjects, as a real cohort has: two people were
    % recorded twice. That is exactly the case .files exists to show.
    rows  = [curves; curves(1:2, :) * 1.1];
    files = struct('name',    {'a','b','c','d','e','f'}, ...
                   'subject', {'s1','s2','s3','s4','s1','s2'}, ...
                   'curve',   num2cell(rows, 2)');
    g(k) = struct('name', names{k}, 'subjects', {{'s1','s2','s3','s4'}}, ...
                  'curves', curves, 'chanMeans', mean(curves, 1), ...
                  'nFiles', 6, 'nSubjects', 4, 'files', files);
end
res.groups   = g;
res.est      = curveInterval({g.curves}, design);
% groupCurves fills .contrast for exactly two groups, and drawDifferenceWave
% renders it rather than deriving one - so the fixture must supply it too.
res.contrast = struct([]);
if nGroups == 2
    res.contrast = differenceInterval(g(1).curves, g(2).curves, design);
end
end

function n = nLines(ax)
% Only the mean lines: the zero line and the baseline marker are drawn with
% HandleVisibility off to keep them out of the legend.
n = numel(findobj(ax, 'Type', 'Line', 'HandleVisibility', 'on'));
end

function n = nBands(ax)
% findall, not findobj: the confidence bands are also HandleVisibility off, so
% findobj and get(ax,'Children') do not see them at all.
n = numel(findall(ax, 'Type', 'Patch'));
end

% ── drawTEPOverlay ────────────────────────────────────────────────────────

function test_overlayDrawsOneVisibleLinePerGroup(testCase)
ax = offscreenAxes(testCase);
drawTEPOverlay(ax, fakeRes(3, 'unpaired'), struct());
testCase.verifyEqual(nLines(ax), 3);
testCase.verifyEqual(nBands(ax), 3, 'one confidence band per group');
end

function test_overlayDrawsOneTraceLinePerRecordingWhenAsked(testCase)
% The traces are HandleVisibility off - they belong behind the estimate and
% out of the legend - so findall is the only way to count them, and the
% legend must not grow.
ax = offscreenAxes(testCase);
res = fakeRes(2, 'unpaired');

drawTEPOverlay(ax, res, struct('showTraces', false));
without = numel(findall(ax, 'Type', 'Line'));

drawTEPOverlay(ax, res, struct('showTraces', true));
with = numel(findall(ax, 'Type', 'Line'));

testCase.verifyEqual(with - without, sum([res.groups.nFiles]), ...
    'one thin line per RECORDING, not per subject');
testCase.verifyEqual(nLines(ax), 2, ...
    'traces must stay out of the legend, which names groups');
end

function test_traceOptionIsSafeOnAResultThatPredatesIt(testCase)
% A session saved before .files existed, or any hand-built res, simply
% has nothing to draw - it must not error.
ax = offscreenAxes(testCase);
res = fakeRes(2, 'unpaired');
res.groups = rmfield(res.groups, 'files');

drawTEPOverlay(ax, res, struct('showTraces', true));
testCase.verifyEqual(nLines(ax), 2);
end

function test_overlayLegendStatesN(testCase)
% A band whose n is not stated cannot be interpreted.
ax = offscreenAxes(testCase);
drawTEPOverlay(ax, fakeRes(2, 'unpaired'), struct());
lines = flipud(findobj(ax, 'Type', 'Line', 'HandleVisibility', 'on'));
testCase.verifyTrue(contains(lines(1).DisplayName, 'n=4'));
testCase.verifyTrue(contains(lines(1).DisplayName, 'pre'));
end

function test_overlayLabelsTheModeItWasGiven(testCase)
ax = offscreenAxes(testCase);
drawTEPOverlay(ax, fakeRes(1, 'unpaired'), struct('mode', 'GMFP'));
testCase.verifyTrue(contains(ax.YLabel.String, 'GMFP'));
testCase.verifyTrue(contains(ax.Title.String, 'Global Mean Field Power'));
end

function test_overlayHandlesOneGroupAndSuppressibleBand(testCase)
ax = offscreenAxes(testCase);
drawTEPOverlay(ax, fakeRes(1, 'unpaired'), struct('showBand', false));
testCase.verifyEqual(nLines(ax), 1);
testCase.verifyEqual(nBands(ax), 0);
end

function test_overlayScalesPastThePaletteLength(testCase)
% groupColors repeats darker beyond eight; the overlay must not error there.
ax  = offscreenAxes(testCase);
res = fakeRes(4, 'unpaired');
drawTEPOverlay(ax, res, struct('colors', groupColors(2)));
testCase.verifyEqual(nLines(ax), 4, ...
    'an undersized palette must be replaced, not indexed past its end');
end

% ── drawDifferenceWave ────────────────────────────────────────────────────

function test_differenceWaveRunsAndNamesTheContrast(testCase)
ax = offscreenAxes(testCase);
drawDifferenceWave(ax, fakeRes(2, 'paired'), struct());
testCase.verifyEqual(nLines(ax), 1);
testCase.verifyTrue(contains(ax.Title.String, 'post minus pre'));
testCase.verifyTrue(contains(ax.Title.String, 'paired'), ...
    'the reader must be told which interval this is');
testCase.verifyTrue(contains(ax.YLabel.String, 'Difference'));
end

function test_differenceWaveRefusesWrongGroupCount(testCase)
ax = offscreenAxes(testCase);
for n = [1 3]
    testCase.verifyError(@() drawDifferenceWave(ax, fakeRes(n, 'unpaired'), struct()), ...
        'nestapp:differenceNeedsTwoGroups');
end
end

function test_differenceWaveWorksUnpairedToo(testCase)
ax = offscreenAxes(testCase);
drawDifferenceWave(ax, fakeRes(2, 'unpaired'), struct());
testCase.verifyTrue(contains(ax.Title.String, 'unpaired'));
end

function test_contrastDirectionInvertsTheCurveAndTheTitleTogether(testCase)
% The picture and the sentence above it must agree about which subtraction
% happened - a flipped curve under an unflipped title is the worst outcome
% available, because both look plausible on their own.
res = fakeRes(2, 'paired');

ax = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct());
forward = lineYData(ax);
testCase.assertTrue(contains(ax.Title.String, 'post minus pre'));

ax = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct('direction', 'first - second'));
testCase.verifyEqual(lineYData(ax), -forward, 'AbsTol', 1e-12);
testCase.verifyTrue(contains(ax.Title.String, 'pre minus post'));
end

function test_flippingIsTheIntervalTheOtherContrastWouldHaveGiven(testCase)
% Negation has to take the bounds with it. Reading lo as lo after a flip
% would draw a band on the wrong side of the mean, which is not a cosmetic
% error - it is an interval that excludes zero where the real one includes it.
res = fakeRes(2, 'unpaired');

ax = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct());
fwd = bandYData(ax);

ax = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct('direction', 'first - second'));
testCase.verifyEqual(sort(bandYData(ax)), sort(-fwd), 'AbsTol', 1e-12);
end

function test_theDefaultDirectionIsUnchanged(testCase)
% Every saved session and every figure already exported reads
% second-minus-first, so an absent setting must still mean exactly that.
res = fakeRes(2, 'paired');

ax = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct());
absent = lineYData(ax);

ax = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct('direction', 'second - first'));
testCase.verifyEqual(lineYData(ax), absent);
end

function test_theBandFollowsTheLevelItWasGiven(testCase)
% The level is a draw option, so a narrower one has to actually narrow the
% band rather than being accepted and ignored.
res = fakeRes(2, 'paired');

ax = offscreenAxes(testCase);
drawTEPOverlay(ax, res, struct('level', 0.99));
wide = bandSpan(ax);

ax = offscreenAxes(testCase);
drawTEPOverlay(ax, res, struct('level', 0.80));
testCase.verifyLessThan(bandSpan(ax), wide);
end

function test_theDifferenceTitleStatesTheLevelActuallyDrawn(testCase)
% The failure this guards: a 90% band under a title reading 95%. Both halves
% look right alone, and the figure outlives the session that made it.
res = fakeRes(2, 'unpaired');
ax  = offscreenAxes(testCase);
drawDifferenceWave(ax, res, struct('level', 0.90));
testCase.verifyTrue(contains(ax.Title.String, '90% CI'));
testCase.verifyFalse(contains(ax.Title.String, '95% CI'));
end

function test_anAbsentLevelLeavesTheComputedBandAlone(testCase)
res = fakeRes(2, 'paired');

ax = offscreenAxes(testCase);
drawTEPOverlay(ax, res, struct());
absent = bandSpan(ax);

ax = offscreenAxes(testCase);
drawTEPOverlay(ax, res, struct('level', []));
testCase.verifyEqual(bandSpan(ax), absent);
end

function s = bandSpan(ax)
% Total vertical extent of the shaded patches - a scale-free stand-in for
% "how wide is the band", which is all these tests compare.
h = findall(ax, 'Type', 'patch');
s = 0;
for k = 1:numel(h)
    s = s + (max(h(k).YData) - min(h(k).YData));
end
end

function y = lineYData(ax)
% The one visible line: the zero and baseline markers are HandleVisibility off,
% which findobj skips and findall would not - the trap this file already
% documents for nLines.
h = findobj(ax, 'Type', 'line');
y = h(1).YData;
end

function y = bandYData(ax)
h = findall(ax, 'Type', 'patch');
y = h(1).YData(:)';
end
