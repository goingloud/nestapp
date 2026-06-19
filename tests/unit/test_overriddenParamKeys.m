
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_overriddenParamKeys
% TEST_OVERRIDDENPARAMKEYS  Unit tests for the mutually-exclusive param rule.
%
%   'Remove un-needed Channels' has two ways of writing one selection:
%   'channel' (Keep) and 'nochannel' (Remove). Keep overrides Remove
%   (matching pop_select), and the param editor greys/locks the overridden one.
%
%   Run: runtests('tests/unit/test_overriddenParamKeys')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
end

function test_onlyKeepSet_disablesRemove(testCase)
p = struct('nochannel', {{}}, 'channel', {{'Cz','Fz'}});
testCase.verifyEqual(overriddenParamKeys('Remove un-needed Channels', p), {'nochannel'});
end

function test_onlyRemoveSet_disablesKeep(testCase)
p = struct('nochannel', {{'TP9','TP10'}}, 'channel', {[]});
testCase.verifyEqual(overriddenParamKeys('Remove un-needed Channels', p), {'channel'});
end

function test_bothSet_keepWinsTie(testCase)
% The user's real case: both populated -> Keep takes precedence, Remove locked.
p = struct('nochannel', {{'TP9','TP10'}}, 'channel', {{'Cz','Fz'}});
testCase.verifyEqual(overriddenParamKeys('Remove un-needed Channels', p), {'nochannel'});
end

function test_neitherSet_nothingDisabled(testCase)
p = struct('nochannel', {{}}, 'channel', {[]});
testCase.verifyEmpty(overriddenParamKeys('Remove un-needed Channels', p));
end

function test_otherStepNeverDisables(testCase)
p = struct('nochannel', {{'TP9'}}, 'channel', {{'Cz'}});
testCase.verifyEmpty(overriddenParamKeys('Remove Bad Channels', p));
end

function test_missingFieldsTolerated(testCase)
testCase.verifyEmpty(overriddenParamKeys('Remove un-needed Channels', struct()));
end
