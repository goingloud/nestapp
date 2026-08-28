% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_drawTEPTopo
% TEST_DRAWTEPTOPO  The composite: a grid of scalp maps over the group curves.
%
%   Needs EEGLAB (topoplot).
%
%   Three things are worth pinning and the rest is layout arithmetic that a
%   screenshot checks better than an assertion:
%
%   1. The maps AVERAGE over each window. Sampling the window's midpoint
%      instead would print a map beside a mean it does not describe, and
%      nothing about the picture would look wrong - the failure is silent and
%      lands in a figure someone publishes.
%   2. ONE colour bar for the whole grid. Every map shares the scale, so a bar
%      per map repeated one fact twelve times and took about 40% of the width
%      out of the heads to do it.
%   3. A CLASSIC figure is a valid parent. Every MATLAB export path omits UI
%      components, so if this drifts back to needing uiaxes or uilabel, saved
%      figures lose their maps and their group names with only a warning on
%      the command line - and the app's whole publication route is that call.
%
%   Run: runtests('tests/integration/test_drawTEPTopo')
tests = functiontests(localfunctions);
end

% -- fixture --------------------------------------------------------------

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('topoplot'), 'EEGLAB not on path');
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function res = twoGroupRes(midpointGain)
% A groupCurves-shaped result whose scalp pattern is flat across each window
% EXCEPT for a spike at the window midpoint, scaled by midpointGain. A drawer
% that averages sees the flat level; one that samples the midpoint sees the
% spike. With midpointGain = 1 the two agree, so a test can compare them.
theta  = [0:45:315, 0:45:315, 0];
radius = [repmat(0.20, 1, 8), repmat(0.42, 1, 8), 0];
labels = arrayfun(@(k) sprintf('E%d', k), 1:numel(theta), 'UniformOutput', false);
chanlocs = struct('labels', labels, 'theta', num2cell(theta), ...
                  'radius', num2cell(radius));
chanlocs = convertlocs(chanlocs, 'topo2all');

% 1 ms sampling so the midpoint of the test window is an actual sample - at
% 2 ms it is not, and the spike below would land nowhere.
time = -100:300;
pat  = (cosd(theta) .* radius * 20)';        % peak magnitude 8.4 uV
amp  = ones(1, numel(time));
amp(time == 105) = midpointGain;             % the midpoint of [90 120]

% Three subjects per group, each a scaled copy, so the interval is real
% rather than degenerate - drawTEPOverlay skips a band it cannot compute, and
% a fixture that never exercises the band would not catch a broken one.
roi = mean(pat) * amp;
curvesA = [0.8; 1.0; 1.2] * roi;
curvesB = [0.5; 1.0; 1.5] * roi;

res = struct();
res.time          = time;
res.chanlocs      = chanlocs;
res.channelLabels = labels;
res.design        = 'unpaired';
res.groups = struct( ...
    'name',      {'pre', 'post'}, ...
    'subjects',  {{'s1', 's2', 's3'}, {'s4', 's5', 's6'}}, ...
    'curves',    {curvesA, curvesB}, ...
    'chanMeans', {pat * amp, pat * amp}, ...
    'nFiles',    {3, 3}, 'nSubjects', {3, 3});
res.est = curveInterval({res.groups.curves}, 'unpaired', 0.95);
end

function fig = uiParent(testCase)
fig = uifigure('Visible', 'off', 'Position', [100 100 900 600]);
testCase.addTeardown(@() delete(fig));
end

function w = oneWindow()
w = struct('name', 'N100', 'winStart', 90, 'winEnd', 120);
end

function w = twoWindows()
w = [oneWindow(), struct('name', 'P180', 'winStart', 150, 'winEnd', 240)];
end

function [fig, axesFcn] = classicParent(testCase)
% The publication route's parent: a classic figure and a classic-axes maker.
fig = figure('Visible', 'off', 'Position', [100 100 900 600]);
testCase.addTeardown(@() delete(fig));
axesFcn = @(p, pos) axes('Parent', p, 'Units', 'pixels', 'Position', pos);
end

% -- tests ----------------------------------------------------------------

function test_theGridIsGroupsByWindowsPlusBarAndCurve(testCase)
fig  = uiParent(testCase);
w    = twoWindows();
info = drawTEPTopo(fig, twoGroupRes(1), struct('windows', w));
% 2 groups x 2 windows of maps, one shared colour bar, one curve panel.
testCase.verifyEqual(numel(info.axes), 2 * 2 + 2);
end

function test_oneColourBarForTheWholeGrid(testCase)
fig = uiParent(testCase);
w   = twoWindows();
drawTEPTopo(fig, twoGroupRes(1), struct('windows', w));
testCase.verifyEqual(numel(findall(fig, 'Type', 'ColorBar')), 1, ...
    'a bar per map repeats one fact and takes the width out of the heads');
end

function test_mapsAverageTheWindowRatherThanSampleAMidpoint(testCase)
% The window is flat at the pattern level with a 40x spike at its midpoint. An
% averaging drawer's scale stays near the flat level; a sampling one jumps.
fig  = uiParent(testCase);
flat = drawTEPTopo(fig, twoGroupRes(1), struct('windows', oneWindow()));
delete(allchild(fig));
spiky = drawTEPTopo(fig, twoGroupRes(40), struct('windows', oneWindow()));

nSamples = numel(90:120);
expected = flat.clim(2) * (1 + 39 / nSamples);   % one sample of 40 in the mean
testCase.verifyEqual(spiky.clim(2), expected, 'RelTol', 0.02, ...
    'the scale must follow the window mean, not the midpoint sample');
end

function test_theScaleIsSharedAndSymmetric(testCase)
fig  = uiParent(testCase);
w    = twoWindows();
info = drawTEPTopo(fig, twoGroupRes(1), struct('windows', w));
testCase.verifyEqual(info.clim(1), -info.clim(2), 'AbsTol', 1e-12);
for k = 1:numel(info.axes) - 1      % the curve panel keeps its own limits
    testCase.verifyEqual(info.axes(k).CLim, info.clim, 'AbsTol', 1e-9);
end
end

function test_anEmptyWindowSetIsHonouredNotReplacedByTheDefaults(testCase)
% Emptying the windows table must not revive the six standard components: the
% user deleted them, and a plot that puts them back is reporting windows
% nobody asked for.
fig  = uiParent(testCase);
info = drawTEPTopo(fig, twoGroupRes(1), struct('windows', struct( ...
    'name', {}, 'winStart', {}, 'winEnd', {})));
testCase.verifyEqual(numel(info.axes), 1, ...
    'with nothing to map, the waveform alone is still worth drawing');
end

function test_omittingWindowsFallsBackToTheStandardComponents(testCase)
fig  = uiParent(testCase);
info = drawTEPTopo(fig, twoGroupRes(1), struct());
nW   = numel(defaultTEPComponentDefs());
testCase.verifyEqual(numel(info.axes), 2 * nW + 2);
end

function test_aClassicFigureIsAValidParent(testCase)
% The publication route draws into a classic figure with classic axes, because
% exportgraphics, print and saveas all silently drop UI components. A drawer
% that reaches for uiaxes or uilabel breaks that route without failing here,
% so the check is that NOTHING it created is a UI component.
[fig, axesFcn] = classicParent(testCase);
info = drawTEPTopo(fig, twoGroupRes(1), ...
                   struct('windows', twoWindows(), 'axesFcn', axesFcn));

testCase.verifyEqual(numel(info.axes), 2 * 2 + 2);
testCase.verifyEmpty(findall(fig, 'Type', 'uilabel'), ...
    'a uilabel would be dropped from every exported figure');
for k = 1:numel(info.axes)
    testCase.verifyClass(info.axes(k), 'matlab.graphics.axis.Axes');
end
end

function test_theGridStaysInsideThePanel(testCase)
% topoplot calls axis equal, which moves and resizes the axes it is handed. Left
% alone the maps grow out of their cells and overlap the curve below - which
% looks like a layout choice rather than a bug, and only in the exported file.
[fig, axesFcn] = classicParent(testCase);
info = drawTEPTopo(fig, twoGroupRes(1), ...
                   struct('windows', oneWindow(), 'axesFcn', axesFcn));

for k = 1:numel(info.axes)
    pos = info.axes(k).Position;
    testCase.verifyGreaterThanOrEqual(pos(1), 0);
    testCase.verifyGreaterThanOrEqual(pos(2), 0);
    testCase.verifyLessThanOrEqual(pos(1) + pos(3), fig.Position(3), ...
        'an axes ran off the right of the panel');
    testCase.verifyLessThanOrEqual(pos(2) + pos(4), fig.Position(4), ...
        'an axes ran off the top of the panel');
end
end
