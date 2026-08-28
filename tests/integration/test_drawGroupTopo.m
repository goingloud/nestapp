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
