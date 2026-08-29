% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_publicationFigure
% TEST_PUBLICATIONFIGURE  How the figure width is specified.
%
%   The width setting has to accept the words 'single' and 'double', so the
%   export dialog stores it as TEXT. A millimetre value typed there therefore
%   arrives as '400' rather than 400, and rejecting that made the millimetre
%   option this function advertises unreachable from the only interface that
%   sets it. Both spellings have to work.
%
%   Run: runtests('tests/unit/test_publicationFigure')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('publicationFigure'));
end

function info = sizeFor(testCase, width)
% Compose an empty figure just to read back the size that was resolved.
[fig, info] = publicationFigure(@(parent, axesFcn) [], struct('width', width));
testCase.addTeardown(@() delete(fig(isgraphics(fig))));
end

% -- tests ----------------------------------------------------------------

function test_theNamedJournalWidths(testCase)
testCase.verifyEqual(sizeFor(testCase, 'single').widthMm, 89);
testCase.verifyEqual(sizeFor(testCase, 'double').widthMm, 183);
testCase.verifyEqual(sizeFor(testCase, 'Double').widthMm, 183, ...
    'the named widths should not be case-sensitive');
end

function test_aWidthTypedAsTextIsAWidth(testCase)
% The regression: the dialog hands over '400', not 400.
testCase.verifyEqual(sizeFor(testCase, '400').widthMm, 400);
testCase.verifyEqual(sizeFor(testCase, ' 120 ').widthMm, 120, ...
    'a value typed with stray spaces is still a number');
end

function test_aNumericWidthAlsoWorks(testCase)
testCase.verifyEqual(sizeFor(testCase, 400).widthMm, 400);
end

function test_anUnsetWidthFallsBackToDoubleColumn(testCase)
testCase.verifyEqual(sizeFor(testCase, []).widthMm, 183);
end

function test_heightFollowsWhicheverWidthWasGiven(testCase)
info = sizeFor(testCase, '400');
testCase.verifyEqual(info.heightMm, 400 * 0.62, 'AbsTol', 1e-9);
end

function test_somethingThatIsNotAWidthIsRefusedWithWhatWasGiven(testCase)
for bad = {'banana', '0', '-50', 'NaN'}
    caught = [];
    try
        publicationFigure(@(p, a) [], struct('width', bad{1}));
    catch caught
    end
    testCase.assertNotEmpty(caught, ...
        sprintf('"%s" should not be accepted as a width', bad{1}));
    testCase.verifyEqual(caught.identifier, 'nestapp:badFigureWidth');
    testCase.verifyTrue(contains(caught.message, bad{1}), ...
        'the message should quote what was actually typed');
end
end
