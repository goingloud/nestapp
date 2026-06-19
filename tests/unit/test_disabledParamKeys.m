
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_disabledParamKeys
% TEST_DISABLEDPARAMKEYS  Unit tests for the param-relationship disable rule.
%
%   disabledParamKeys(regEntry, params) returns the params the GUI should grey
%   out and lock, from two declarative relationships on the step registry entry:
%   exclusiveParamGroups (mutually-exclusive alternatives, with precedence) and
%   paramEnableWhen (a param gated by another param's value). Also checks the
%   real registry wiring.
%
%   Run: runtests('tests/unit/test_disabledParamKeys')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
end

% ── exclusive groups ──────────────────────────────────────────────────────────

function e = exclusiveEntry()
% Minimal registry entry with one exclusive pair (channel = precedence).
e.exclusiveParamGroups = {{'channel','nochannel'}};
e.paramEnableWhen      = struct('param', {}, 'controller', {}, 'values', {});
e.params = struct('key', {'channel','nochannel'}, ...
                  'friendlyName', {'Keep channels','Remove channels'});
end

function test_onlyKeepSet_disablesRemove(testCase)
p = struct('nochannel', {{}}, 'channel', {{'Cz','Fz'}});
testCase.verifyEqual(disabledParamKeys(exclusiveEntry(), p), {'nochannel'});
end

function test_onlyRemoveSet_disablesKeep(testCase)
p = struct('nochannel', {{'TP9','TP10'}}, 'channel', {[]});
testCase.verifyEqual(disabledParamKeys(exclusiveEntry(), p), {'channel'});
end

function test_bothSet_precedenceWins(testCase)
p = struct('nochannel', {{'TP9'}}, 'channel', {{'Cz'}});
testCase.verifyEqual(disabledParamKeys(exclusiveEntry(), p), {'nochannel'});
end

function test_neitherSet_nothingDisabled(testCase)
p = struct('nochannel', {{}}, 'channel', {[]});
testCase.verifyEmpty(disabledParamKeys(exclusiveEntry(), p));
end

function test_exclusiveReasonNamesTheSibling(testCase)
p = struct('nochannel', {{'TP9'}}, 'channel', {{'Cz'}});
[~, reasons] = disabledParamKeys(exclusiveEntry(), p);
testCase.verifyTrue(contains(reasons.nochannel, 'Keep channels'));
end

% ── conditional enablement ────────────────────────────────────────────────────

function e = conditionalEntry()
e.exclusiveParamGroups = {};
e.paramEnableWhen = struct('param','ISI','controller','paired','values',{{'yes'}});
e.params = struct('key', {'paired','ISI'}, 'friendlyName', {'Paired-pulse','ISI'});
end

function test_conditionalDisabledWhenControllerOff(testCase)
[k, reasons] = disabledParamKeys(conditionalEntry(), struct('paired','no','ISI',[]));
testCase.verifyEqual(k, {'ISI'});
testCase.verifyTrue(contains(reasons.ISI, 'Paired-pulse'));
end

function test_conditionalEnabledWhenControllerOn(testCase)
testCase.verifyEmpty(disabledParamKeys(conditionalEntry(), struct('paired','yes','ISI',[])));
end

function test_missingControllerDisables(testCase)
% Controller absent from params -> dependent param disabled.
testCase.verifyEqual(disabledParamKeys(conditionalEntry(), struct('ISI',[])), {'ISI'});
end

function test_noMetadata_nothingDisabled(testCase)
e = struct('exclusiveParamGroups', {{}}, ...
           'paramEnableWhen', struct('param',{},'controller',{},'values',{}), ...
           'params', struct('key',{},'friendlyName',{}));
testCase.verifyEmpty(disabledParamKeys(e, struct('a', 1)));
end

% ── real registry wiring ──────────────────────────────────────────────────────

function e = regEntry(name)
reg = stepRegistry();
e = reg(strcmp({reg.name}, name));
end

function test_registry_removeUnneededExclusive(testCase)
e = regEntry('Remove un-needed Channels');
p = struct('channel', {{'Cz'}}, 'nochannel', {{'TP9'}});
testCase.verifyEqual(disabledParamKeys(e, p), {'nochannel'});
end

function test_registry_removeBadChannels_freqrangeGatedByMeasure(testCase)
e = regEntry('Remove Bad Channels');
p = e.defaults; p.measure = 'kurt';
testCase.verifyTrue(ismember('freqrange', disabledParamKeys(e, p)));
p.measure = 'spec';
testCase.verifyFalse(ismember('freqrange', disabledParamKeys(e, p)));
end

function test_registry_removeBaseline_timeVsPointExclusive(testCase)
e = regEntry('Remove Baseline');
testCase.verifyEqual(disabledParamKeys(e, struct('timerange',[-100 0],'pointrange',[])), {'pointrange'});
testCase.verifyEqual(disabledParamKeys(e, struct('timerange',[],'pointrange',[1 50])), {'timerange'});
testCase.verifyEmpty(disabledParamKeys(e, struct('timerange',[],'pointrange',[])));
end

function test_registry_findPulses_pairedAndRepetitiveGates(testCase)
e = regEntry('Find TMS Pulses (TESA)');
p = e.defaults;            % paired = no, repetitive = no by default
k = disabledParamKeys(e, p);
testCase.verifyTrue(all(ismember({'ISI','pairlabel','ITI','pulseNum'}, k)));
p.paired = 'yes';
k2 = disabledParamKeys(e, p);
testCase.verifyFalse(any(ismember({'ISI','pairlabel'}, k2)));
testCase.verifyTrue(all(ismember({'ITI','pulseNum'}, k2)));   % repetitive still no
end
