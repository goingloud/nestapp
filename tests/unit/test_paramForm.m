% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_paramForm
% TEST_PARAMFORM  Choosing a control from makeParam metadata.
%
%   The point of the form is that a setting's control follows from what it
%   already declares, so a new registry entry needs no UI work. Two things are
%   worth pinning:
%
%   1. The right control appears for each kind of value - in particular that a
%      pipe-separated validRange becomes a dropdown of those choices without
%      anything new being declared.
%   2. UNSET SURVIVES. A setting the user never touches must stay absent from
%      the values struct, because the defaults live in the draw function and a
%      value frozen here would stop following them.
%
%   Run: runtests('tests/unit/test_paramForm')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('paramForm'));
end

% -- fixture --------------------------------------------------------------

function panel = build(testCase, meta, values)
% No test here inspects the change callback, so it is a sink.
fig = uifigure('Visible', 'off', 'Position', [100 100 500 400]);
testCase.addTeardown(@() delete(fig));
panel = uipanel(fig, 'Position', [0 0 470 34 * numel(meta) + 8]);
paramForm(panel, meta, values, @(varargin) []);
end

function m = toggleParam()
m = makeParam('showBand', 'Confidence band', '', 'on|off', 'desc', ...
              'type', 'logical', 'placeholder', '(on)');
end

function m = choiceParam()
m = makeParam('measure', 'Measure', '', 'mean | peak | area', 'desc', ...
              'type', 'string', 'placeholder', '(mean)');
end

function m = rangeParam()
m = makeParam('xlim', 'Time range', 'ms', 't1 t2', 'desc', ...
              'type', 'vector', 'placeholder', '(-50 300)');
end

% -- tests ----------------------------------------------------------------

function test_aLogicalBecomesADropdownOfDefaultOnOff(testCase)
panel = build(testCase, toggleParam(), struct());
dd = findall(panel, 'Type', 'uidropdown');
testCase.assertNumElements(dd, 1);
testCase.verifyEqual(dd.Items, {'Default (on)', 'On', 'Off'}, ...
    'the default has to be offerable, and named');
testCase.verifyEmpty(dd.Value, 'an untouched setting starts at its default');
end

function test_aPipeSeparatedRangeBecomesADropdownOfThoseChoices(testCase)
% Nothing new is declared in the registry for this - validRange already is a
% closed list, so it can drive the control.
panel = build(testCase, choiceParam(), struct());
dd = findall(panel, 'Type', 'uidropdown');
testCase.verifyEqual(dd.Items, {'Default (mean)', 'mean', 'peak', 'area'});
end

function test_aTwoElementVectorBecomesADefaultBoxAndTwoNumbers(testCase)
panel = build(testCase, rangeParam(), struct());
testCase.verifyNumElements(findall(panel, 'Type', 'uicheckbox'), 1);
fields = findall(panel, 'Type', 'uinumericeditfield');
testCase.assertNumElements(fields, 2);
testCase.verifyEqual(sort([fields.Value]), [-50 300], ...
    'the fields should show the default named in the placeholder');
for f = fields'
    testCase.verifyEqual(char(f.Enable), 'off', ...
        'the fields are disabled while the default is in force, not hidden');
end
end

function test_aSetValueIsShownRatherThanTheDefault(testCase)
panel = build(testCase, rangeParam(), struct('xlim', [-80 260]));
cb = findall(panel, 'Type', 'uicheckbox');
testCase.verifyFalse(cb.Value, 'a set value means the Default box is clear');
fields = findall(panel, 'Type', 'uinumericeditfield');
testCase.verifyEqual(sort([fields.Value]), [-80 260]);
end

function test_aStoredOnOffStringStillShowsAsOn(testCase)
% Sessions saved before the controls existed hold 'on'/'off' text.
panel = build(testCase, toggleParam(), struct('showBand', 'off'));
dd = findall(panel, 'Type', 'uidropdown');
testCase.verifyEqual(dd.Value, false);
end

function test_everyRegistryParamGetsAControl(testCase)
% The contract that makes the registry the extension point: nothing in the
% catalogue may declare a setting the form cannot render.
reg = plotRegistry();
for k = 1:numel(reg)
    if isempty(reg(k).params); continue; end
    panel = build(testCase, reg(k).params, struct());
    n = numel(findall(panel, 'Type', 'uidropdown')) ...
      + numel(findall(panel, 'Type', 'uicheckbox'));
    testCase.verifyGreaterThanOrEqual(n, numel(reg(k).params), ...
        sprintf('%s has a setting with no control', reg(k).name));
end
end
