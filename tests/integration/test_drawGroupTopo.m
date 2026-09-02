% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_drawGroupTopo
% TEST_DRAWGROUPTOPO  One scalp map per group on a shared scale.
%
%   Needs EEGLAB (topoplot).
%
%   The bug this pins: drawing the second map reset the colormap of the axes
%   already drawn, so the first group came out in topoplot's own colours and
%   the last in the diverging map. Two maps of the same data then looked like
%   two different results - the precise misreading a shared scale exists to
%   prevent, and one that looks like a finding rather than a rendering fault.
%   Setting the scale per map inside the loop is not enough; the invariant is
%   that all maps share one scale, so it has to be asserted after the loop.
%
%   Run: runtests('tests/integration/test_drawGroupTopo')
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

function res = twoGroupRes(scaleB)
% A groupCurves-shaped result: same montage, group B scaled so the two groups
% genuinely differ in amplitude.
theta  = [0:45:315, 0:45:315, 0];
radius = [repmat(0.20, 1, 8), repmat(0.42, 1, 8), 0];
labels = arrayfun(@(k) sprintf('E%d', k), 1:numel(theta), 'UniformOutput', false);
chanlocs = struct('labels', labels, 'theta', num2cell(theta), ...
                  'radius', num2cell(radius));
chanlocs = convertlocs(chanlocs, 'topo2all');

time = -100:2:300;
pat  = (cosd(theta) .* radius * 20)';
res  = struct();
res.time          = time;
res.chanlocs      = chanlocs;
res.channelLabels = labels;
res.design        = 'unpaired';
res.groups = struct( ...
    'name',      {'A', 'B'}, ...
    'subjects',  {{'s1'}, {'s2'}}, ...
    'curves',    {zeros(1, numel(time)), zeros(1, numel(time))}, ...
    'chanMeans', {pat * ones(1, numel(time)), scaleB * pat * ones(1, numel(time))}, ...
    'nFiles',    {1, 1}, 'nSubjects', {1, 1});
end

function axs = twoAxes(testCase)
fig = figure('Visible', 'off');
testCase.addTeardown(@() delete(fig));
axs = [subplot(1, 2, 1, 'Parent', fig), subplot(1, 2, 2, 'Parent', fig)];
end

% -- tests ----------------------------------------------------------------

function test_everyMapEndsWithTheDivergingColormap(testCase)
axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(0.2), struct('window', [90 120]));
want = divergingColormap();
testCase.verifyEqual(axs(1).Colormap, want, ...
    'the first map must not be left in topoplot''s own colours');
testCase.verifyEqual(axs(2).Colormap, want);
end

function test_allMapsShareOneSymmetricScale(testCase)
axs = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(0.2), struct('window', [90 120]));
testCase.verifyEqual(axs(1).CLim, axs(2).CLim, ...
    'per-map limits would make a small map look like a large one');
testCase.verifyEqual(axs(1).CLim, clim);
testCase.verifyEqual(clim(1), -clim(2), 'AbsTol', 1e-12, ...
    'zero must sit at the centre of a diverging map');
end

function test_scaleComesFromTheLargestGroup(testCase)
% The shared limit has to cover every group, or the biggest map clips.
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(3), struct('window', [90 120]));
res  = twoGroupRes(3);
peak = max(cellfun(@(c) max(abs(mean(c, 2))), {res.groups.chanMeans}));
testCase.verifyGreaterThanOrEqual(clim(2), peak * 0.99);
end

function test_explicitClimWins(testCase)
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'clim', [-9 9]));
testCase.verifyEqual(clim, [-9 9]);
testCase.verifyEqual(axs(1).CLim, [-9 9]);
end

function test_tooFewAxesIsAnError(testCase)
fig = figure('Visible', 'off');
testCase.addTeardown(@() delete(fig));
testCase.verifyError(@() drawGroupTopo(axes(fig), twoGroupRes(1), struct()), ...
    'nestapp:tooFewAxes');
end

function test_windowOutsideEpochIsAnError(testCase)
axs = twoAxes(testCase);
testCase.verifyError(@() drawGroupTopo(axs, twoGroupRes(1), ...
    struct('window', [900 1200])), 'nestapp:windowOutsideEpoch');
end

% -- colour scale mode ----------------------------------------------------

function test_perMapGivesEachMapItsOwnScale(testCase)
% The setting exists because a group ten times larger flattens the others to
% near-neutral, and their topography then cannot be read at all.
axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(0.1), struct('window', [90 120], 'scale', 'per map'));
testCase.verifyNotEqual(axs(1).CLim, axs(2).CLim);
for k = 1:2
    testCase.verifyEqual(axs(k).CLim(1), -axs(k).CLim(2), 'AbsTol', 1e-12, ...
        'each map is still symmetric - zero stays at the middle of the map');
end
end

function test_perMapReportsNoSharedScaleForTheCallerToLabel(testCase)
% The contract the tab relies on. A shared bar hung over maps that no longer
% share a scale states a voltage for a colour that means a different voltage
% in the map beside it - a wrong number on a published figure, which is the
% class of bug this whole stage is about.
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(0.1), ...
                     struct('window', [90 120], 'scale', 'per map'));
testCase.verifyEmpty(clim);
end

function test_perMapPutsABarOnEveryMapSinceNoSharedOneCan(testCase)
axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(0.1), struct('window', [90 120], ...
    'scale', 'per map', 'colorbar', false));
for k = 1:2
    testCase.verifyNotEmpty(findall(axs(k).Parent, 'Type', 'colorbar'), ...
        'a map with no scale at all is worse than a slightly smaller head');
end
end

function test_sharedStaysTheDefault(testCase)
% Every figure already exported reads a shared scale; an absent setting must
% still mean exactly that.
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(0.2), struct('window', [90 120]));
testCase.verifyNotEmpty(clim);
testCase.verifyEqual(axs(1).CLim, axs(2).CLim);
end

function test_aFixedLimitPinsTheScaleSymmetrically(testCase)
% What makes two runs comparable: a derived scale moves with the data, so the
% same colour means a different voltage in each figure.
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'climit', 7));
testCase.verifyEqual(clim, [-7 7]);
testCase.verifyEqual(axs(1).CLim, [-7 7]);
testCase.verifyEqual(axs(2).CLim, [-7 7]);
end

function test_aFixedLimitOverridesPerMap(testCase)
% A stated number is a stated scale, so it cannot also be per-map. Documented
% precedence, pinned because the two settings are independently reachable.
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(0.1), ...
                     struct('window', [90 120], 'scale', 'per map', 'climit', 4));
testCase.verifyEqual(clim, [-4 4]);
testCase.verifyEqual(axs(1).CLim, axs(2).CLim);
end

function test_aNegativeFixedLimitIsReadAsAMagnitude(testCase)
% -6 and 6 name the same symmetric scale; the alternative is an inverted CLim
% that renders every map in reverse polarity.
axs  = twoAxes(testCase);
clim = drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'climit', -6));
testCase.verifyEqual(clim, [-6 6]);
end

% -- markers and contours -------------------------------------------------

function test_markersAreOffByDefaultAndDrawnWhenAsked(testCase)
axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120]));
bare = nMarks(axs(1));

axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'markers', 'dots'));
testCase.verifyGreaterThan(nMarks(axs(1)), bare);
end

function test_labelsNameTheElectrodesRatherThanJustMarkingThem(testCase)
axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'markers', 'labels'));
txt   = findall(axs(1), 'Type', 'text');
% topoplot pads each label with a leading space to hold it off the marker,
% so the comparison has to trim - matching on ' E1' would pin a detail of
% topoplot's spacing rather than the behaviour under test.
shown = strtrim(cellfun(@(c) char(string(c)), {txt.String}, 'UniformOutput', false));
testCase.verifyTrue(any(strcmp(shown, 'E1')), ...
    'the point of labels is answering WHICH electrode');
end

function test_anUnknownMarkerWordIsAnErrorNotASilentOff(testCase)
% Passing an unrecognised word straight to topoplot draws nothing and reports
% nothing, so a typo in a saved session would silently lose the markers.
axs = twoAxes(testCase);
testCase.verifyError(@() drawGroupTopo(axs, twoGroupRes(1), ...
    struct('window', [90 120], 'markers', 'dot')), 'nestapp:badMarkers');
end

function test_zeroContoursLeavesTheFieldAlone(testCase)
axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'contours', 0));
few = numel(findall(axs(1), 'Type', 'contour')) ...
    + numel(findall(axs(1), 'Type', 'line'));

axs = twoAxes(testCase);
drawGroupTopo(axs, twoGroupRes(1), struct('window', [90 120], 'contours', 10));
many = numel(findall(axs(1), 'Type', 'contour')) ...
     + numel(findall(axs(1), 'Type', 'line'));
testCase.verifyGreaterThanOrEqual(many, few);
end

function n = nMarks(ax)
% topoplot draws electrode markers as line objects with no connecting segment.
% findall, not findobj: topoplot leaves much of what it draws
% handle-invisible, and findobj skips exactly those.
n = numel(findall(ax, 'Type', 'line', 'LineStyle', 'none'));
end
