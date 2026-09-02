% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_figureExportHelpers
% TEST_FIGUREEXPORTHELPERS  Unit tests for divergingColormap.
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
