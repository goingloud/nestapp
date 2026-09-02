% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_renderQcImages
% TEST_RENDERQCIMAGES  The Reports tab showing images the run already wrote.
%
%   renderQualityFigure has always produced these PNGs and processOneFile has
%   always recorded their paths; only the PDF exporter ever rendered them, so
%   seeing one meant exporting a PDF. What is pinned here is the wiring and the
%   two states that are easy to get wrong: a report with no images at all, and
%   a report naming an image that is no longer on disk - which happens as soon
%   as reports are loaded from a folder whose qc/ directory has been cleaned
%   out.
%
%   Run: runtests('tests/unit/test_renderQcImages')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('renderQcImages'));
end

% -- fixture --------------------------------------------------------------

function p = makePanel(testCase)
fig = uifigure('Visible', 'off', 'Position', [100 100 700 500]);
testCase.addTeardown(@() delete(fig));
p = uipanel(fig, 'Position', [0 0 637 457], 'BorderType', 'none');
end

function f = writePng(testCase, name)
d = fullfile(tempdir, 'nestapp_qc_test');
if ~isfolder(d); mkdir(d); end
f = fullfile(d, name);
imwrite(uint8(zeros(8, 8, 3)), f);
testCase.addTeardown(@() delete(f));
end

% -- tests ----------------------------------------------------------------

function test_noImagesSaysSoAndSaysWhyNot(testCase)
% A blank pane reads as broken. The message has to name the two switches that
% produce these files, because "there are none" is otherwise unactionable.
p = makePanel(testCase);
renderQcImages(p, {});

lbl = findall(p, 'Type', 'uilabel');
testCase.assertNumElements(lbl, 1);
testCase.verifySubstring(lbl.Text, 'Quality Gate');
testCase.verifyEmpty(findall(p, 'Type', 'uiimage'), ...
    'nothing to show means no image widget');
end

function test_imagesGetAPickerAndTheFirstIsShown(testCase)
p = makePanel(testCase);
a = writePng(testCase, '01_Quality_Gate.png');
b = writePng(testCase, '02_Quality_Gate.png');

renderQcImages(p, {a, b});

dd = findall(p, 'Type', 'uidropdown');
testCase.assertNumElements(dd, 1);
testCase.verifyEqual(dd.Items, {'01_Quality_Gate.png', '02_Quality_Gate.png'}, ...
    'the picker names the checkpoints, in order');

img = findall(p, 'Type', 'uiimage');
testCase.assertNumElements(img, 1);
testCase.verifyEqual(img.ImageSource, a);
end

function test_switchingTheDropdownSwapsTheImage(testCase)
p = makePanel(testCase);
a = writePng(testCase, '01_Quality_Gate.png');
b = writePng(testCase, '02_Quality_Gate.png');
renderQcImages(p, {a, b});

dd = findall(p, 'Type', 'uidropdown');
dd.Value = 2;
feval(dd.ValueChangedFcn, dd, []);

img = findall(p, 'Type', 'uiimage');
testCase.verifyEqual(img.ImageSource, b);
end

function test_aMissingFileIsNamedRatherThanShownBlank(testCase)
% Reports outlive the images they name - Load from Folder on a batch whose
% qc/ was cleared is the ordinary case, not an exotic one.
p = makePanel(testCase);
gone = fullfile(tempdir, 'nestapp_qc_test', 'nope_00_Quality_Gate.png');

renderQcImages(p, {gone});

img = findall(p, 'Type', 'uiimage');
testCase.assertNumElements(img, 1);
testCase.verifyEmpty(img.ImageSource);
testCase.verifySubstring(img.Tooltip, 'Missing');
end

function test_reRenderReplacesRatherThanStacks(testCase)
% Same contract renderDashboardPanel holds: the pane is re-rendered on resize
% and on every selection change, so a second copy underneath is invisible
% until it is not.
p = makePanel(testCase);
a = writePng(testCase, '01_Quality_Gate.png');

renderQcImages(p, {a});
n1 = numel(findall(p, 'Type', 'uiimage'));
renderQcImages(p, {a});
n2 = numel(findall(p, 'Type', 'uiimage'));

testCase.verifyEqual(n1, 1);
testCase.verifyEqual(n2, 1);
end

function test_theOpenFolderButtonAppearsOnlyWhenACallbackIsGiven(testCase)
p = makePanel(testCase);
a = writePng(testCase, '01_Quality_Gate.png');

renderQcImages(p, {a});
testCase.verifyEmpty(findall(p, 'Type', 'uibutton'), ...
    'no handler means no button offering to do nothing');

delete(p.Children);
got = {};
renderQcImages(p, {a}, struct('onOpen', @(d) assignHit(d)));
btn = findall(p, 'Type', 'uibutton');
testCase.assertNumElements(btn, 1);
feval(btn.ButtonPushedFcn, btn, []);
testCase.verifyEqual(got{1}, fileparts(a), ...
    'the handler is given the folder holding the image');

    function assignHit(d)
        got{end+1} = d; %#ok<AGROW>
    end
end
