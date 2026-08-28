% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_fillDefaults
% TEST_FILLDEFAULTS  The options-defaults helper five call sites now share.
%
%   The behaviour that matters is that EMPTY counts as absent: callers build
%   options structs field by field and leave a field as [] to mean "you
%   choose", so struct('roi', []) must behave like omitting roi. That is the
%   one rule the five hand-written copies could have drifted on.
%
%   Run: runtests('tests/unit/test_fillDefaults')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function test_missingFieldsAreFilled(testCase)
s = fillDefaults(struct('a', 1), struct('a', 9, 'b', 2));
testCase.verifyEqual(s.a, 1, 'an existing value must win');
testCase.verifyEqual(s.b, 2);
end

function test_emptyCountsAsAbsent(testCase)
s = fillDefaults(struct('mode', []), struct('mode', 'TEP'));
testCase.verifyEqual(s.mode, 'TEP', ...
    '[] means "you choose", not "use empty"');
end

function test_falseAndZeroAreRealValues(testCase)
% The trap next to the empty rule: false and 0 are not empty and must survive.
s = fillDefaults(struct('showBand', false, 'level', 0), ...
                 struct('showBand', true, 'level', 0.95));
testCase.verifyFalse(s.showBand, 'false is a choice, not an absence');
testCase.verifyEqual(s.level, 0, '0 is a choice, not an absence');
end

function test_extraFieldsPassThrough(testCase)
s = fillDefaults(struct('custom', 'keep'), struct('a', 1));
testCase.verifyEqual(s.custom, 'keep');
end

function test_emptyInputsAreSafe(testCase)
testCase.verifyEqual(fillDefaults(struct(), struct('a', 3)).a, 3);
testCase.verifyEqual(fillDefaults([], struct('a', 3)).a, 3);
s = struct('a', 1);
testCase.verifyEqual(fillDefaults(s, []), s);
end

function test_cellDefaultSurvives(testCase)
% A cellstr default is the common case here (roi, titles) and is easy to get
% wrong when building the defaults struct.
s = fillDefaults(struct(), struct('roi', {{'F3', 'CZ'}}));
testCase.verifyEqual(s.roi, {'F3', 'CZ'});
end
