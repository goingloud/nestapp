% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_drawScalpTopo
% TEST_DRAWSCALPTOPO  Integration tests for the scalp-map drawing helper.
%
%   Needs EEGLAB (topoplot). Covers the two things the old inline topoplot
%   code got wrong:
%     1. the colour limits were captured on a throwaway axes and dropped, so
%        the destination silently autoscaled and the colours meant nothing;
%     2. it called gcf (which CREATES a figure when none is open) and then a
%        bare close, which shut whatever figure happened to be current -
%        potentially one of the user's own plots or an EEGLAB window.
%
%   Run: runtests('tests/integration/test_drawScalpTopo')
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

% -- tests ----------------------------------------------------------------

function test_classicAxesGetsSymmetricLimitsAndColorbar(testCase)
[values, chanlocs] = syntheticScalp();
fig = figure('Visible', 'off');
testCase.addTeardown(@() delete(fig));
ax = axes(fig);

cLim = drawScalpTopo(ax, values, chanlocs);

testCase.verifyEqual(cLim(1), -cLim(2), 'AbsTol', 1e-12, ...
    'Limits must be symmetric so white lands on 0 uV');
testCase.verifyGreaterThan(cLim(2), 0, 'Limits must be a real range');
testCase.verifyEqual(ax.CLim, cLim, 'The axes must actually carry the limits');

cb = findobj(fig, 'Type', 'colorbar');
testCase.verifyNumElements(cb, 1, 'A colorbar is the readable scale');
testCase.verifyEqual(cb.Label.String, 'uV', 'Colorbar must be labelled in uV');
end

function test_uiAxesPathKeepsTheLimits(testCase)
% The uiaxes path goes through a hidden figure; the limits used to be lost
% with it, leaving UIAxes2 autoscaled to the copied surface.
[values, chanlocs] = syntheticScalp();
uf = uifigure('Visible', 'off');
testCase.addTeardown(@() delete(uf));
uiAx = uiaxes(uf);

cLim = drawScalpTopo(uiAx, values, chanlocs);

testCase.verifyEqual(uiAx.CLim, cLim, 'AbsTol', 1e-12, ...
    'The uiaxes must end up with topoplot''s limits, not an autoscale');
testCase.verifyNotEmpty(allchild(uiAx), 'The map must be copied into the uiaxes');
end

function test_doesNotDisturbOtherFigures(testCase)
% Regression: render with a user figure open and confirm it survives, and
% that no extra figure is left behind.
[values, chanlocs] = syntheticScalp();
userFig = figure('Visible', 'off', 'Name', 'user plot');
testCase.addTeardown(@() delete(userFig));
plot(axes(userFig), 1:10);

uf = uifigure('Visible', 'off');
testCase.addTeardown(@() delete(uf));
uiAx = uiaxes(uf);

% Count only around the render, so the destination figure itself is not
% mistaken for a leak.
before = findall(groot, 'Type', 'figure');
drawScalpTopo(uiAx, values, chanlocs);
after = findall(groot, 'Type', 'figure');

testCase.verifyTrue(isvalid(userFig), 'The user''s figure must not be closed');
testCase.verifyEqual(numel(after), numel(before), ...
    'No figure may be created or destroyed behind the user''s back');
end

% -- helpers --------------------------------------------------------------

function [values, chanlocs] = syntheticScalp()
% Two concentric rings plus a vertex electrode, with polar coordinates set
% directly. topoplot reads theta/radius, so this needs no location file -
% which keeps the test independent of the EEGLAB install's cap files.
theta  = [0:45:315, 0:45:315, 0];
radius = [repmat(0.20, 1, 8), repmat(0.42, 1, 8), 0];
labels = arrayfun(@(k) sprintf('E%d', k), 1:numel(theta), 'UniformOutput', false);
chanlocs = struct('labels', labels, ...
                  'theta',  num2cell(theta), ...
                  'radius', num2cell(radius));
% readlocs (inside topoplot) expects the full coordinate field set, so let
% EEGLAB derive the cartesian/spherical ones from the polar pair.
chanlocs = convertlocs(chanlocs, 'topo2all');
% Front-positive / back-negative pattern, so the map is clearly signed and
% the absmax limits are non-degenerate.
values = (cosd(theta) .* radius * 20)';
end
