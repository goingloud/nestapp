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
           'nFiles', {}, 'nSubjects', {});
for k = 1:nGroups
    curves = sin(linspace(0, pi, numel(time))) .* (1:4)' + k;
    g(k) = struct('name', names{k}, 'subjects', {{'s1','s2','s3','s4'}}, ...
                  'curves', curves, 'chanMeans', mean(curves, 1), ...
                  'nFiles', 4, 'nSubjects', 4);
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
