% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_figureExportHelpers
% TEST_FIGUREEXPORTHELPERS  Unit tests for popOutAxes and divergingColormap.
%
%   popOutAxes backs the "Open in Figure" buttons: it must hand back a real
%   figure with a classic axes (which is what makes the plot editor and the
%   Property Inspector available) carrying the same content and limits as the
%   in-app uiaxes. divergingColormap gives the topoplot a readable zero.
%
%   All figures are created invisible, so this runs headless.
%
%   Run: runtests('tests/unit/test_figureExportHelpers')
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

% ── popOutAxes ────────────────────────────────────────────────────────────

function test_popOutGivesClassicFigureAndAxes(testCase)
srcAx  = sourceAxes(testCase);
outFig = popOut(testCase, srcAx);

testCase.verifyClass(outFig, 'matlab.ui.Figure');
outAx = findobj(outFig, 'Type', 'axes');
testCase.verifyNumElements(outAx, 1, 'Exactly one axes expected');
% A classic axes - NOT a uiaxes - is what the plot editor needs.
testCase.verifyClass(outAx, 'matlab.graphics.axis.Axes');
end

function test_popOutCopiesContentAndLimits(testCase)
srcAx  = sourceAxes(testCase);
outFig = popOut(testCase, srcAx);
outAx  = findobj(outFig, 'Type', 'axes');

testCase.verifyNumElements(findobj(outAx, 'Type', 'line'), 2, ...
    'Both plotted lines must be copied');
testCase.verifyEqual(outAx.XLim, srcAx.XLim, 'XLim must carry over');
testCase.verifyEqual(outAx.YLim, srcAx.YLim, 'YLim must carry over');
testCase.verifyEqual(outAx.Title.String, 'Source title', 'Title must carry over');
testCase.verifyEqual(outAx.XLabel.String, 'Time (ms)', 'XLabel must carry over');
end

function test_popOutRebuildsLegendForNamedLines(testCase)
outFig = popOut(testCase, sourceAxes(testCase));
testCase.verifyNotEmpty(findobj(outFig, 'Type', 'legend'), ...
    'Named lines must get a legend');
end

function test_popOutSkipsLegendWhenNothingNamed(testCase)
% plotTEP hides the SEM ribbon from the legend; an unconditional
% legend('show') would invent 'data1'-style entries for unnamed content.
srcFig = figure('Visible', 'off');
testCase.addTeardown(@() delete(srcFig));
srcAx = axes(srcFig);
plot(srcAx, 1:10, 1:10);

outFig = popOut(testCase, srcAx);
testCase.verifyEmpty(findobj(outFig, 'Type', 'legend'), ...
    'Unnamed content must not get a legend');
end

% ── divergingColormap ─────────────────────────────────────────────────────

function test_colormapShape(testCase)
cmap = divergingColormap();
testCase.verifySize(cmap, [256 3]);
testCase.verifyTrue(all(cmap(:) >= 0 & cmap(:) <= 1), 'Colours must be in [0,1]');
testCase.verifySize(divergingColormap(9), [9 3]);
end

function test_colormapHasWhiteCentreAndColouredEnds(testCase)
cmap = divergingColormap(101);   % odd -> an exact centre row
testCase.verifyEqual(cmap(51,:), [1 1 1], 'AbsTol', 1e-12, ...
    'The midpoint must be white so a symmetric CLim puts white at 0 uV');
testCase.verifyTrue(cmap(1,3)   > cmap(1,1),   'Cold end must be blue-dominant');
testCase.verifyTrue(cmap(end,1) > cmap(end,3), 'Warm end must be red-dominant');
end

function test_colormapLimbsAreBalanced(testCase)
% Rows equidistant from the centre must sit equally far from white, so equal
% magnitudes of opposite sign read as equally strong.
cmap = divergingColormap(101);
distFromWhite = sum(abs(cmap - 1), 2);
testCase.verifyEqual(distFromWhite(1:50), flipud(distFromWhite(52:101)), ...
    'AbsTol', 1e-12, 'The two limbs must be balanced about the midpoint');
end

% ── helpers ───────────────────────────────────────────────────────────────

function ax = sourceAxes(testCase)
% A stand-in for the app's TEP uiaxes: two named lines, custom limits and
% labels. A plain axes is used so the test runs without building the app.
fig = figure('Visible', 'off');
testCase.addTeardown(@() delete(fig));
ax = axes(fig);
hold(ax, 'on');
plot(ax, 1:10, (1:10),    'DisplayName', 'file A');
plot(ax, 1:10, (10:-1:1), 'DisplayName', 'file B');
hold(ax, 'off');
xlim(ax, [2 8]);
ylim(ax, [-5 15]);
title(ax,  'Source title');
xlabel(ax, 'Time (ms)');
ylabel(ax, 'TEP (\muV)');
end

function fig = popOut(testCase, srcAx)
fig = popOutAxes(srcAx, struct('visible', 'off'));
testCase.addTeardown(@() delete(fig));
end
