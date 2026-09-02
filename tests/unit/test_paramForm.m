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
%      value frozen here would stop following them. Since a checkbox and a
%      plain dropdown have no state that MEANS untouched, that now rests on a
%      comparison - selecting the default reports absence - and on the form
%      falling back to an explicit Default item when it cannot know what the
%      default is.
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
[panel, ~] = buildWatched(testCase, meta, values);
end

function [panel, lastChange] = buildWatched(testCase, meta, values)
% Same, but hands back a getter for what the form last reported. A nested
% function, not @() reported - an anonymous handle would capture the value as
% it was at construction and always answer with the empty seed.
reported = struct('key', '', 'value', 'never called');
fig = uifigure('Visible', 'off', 'Position', [100 100 500 400]);
testCase.addTeardown(@() delete(fig));
panel = uipanel(fig, 'Position', [0 0 470 34 * numel(meta) + 8]);
paramForm(panel, meta, values, @record);
lastChange = @get;

    function record(key, value)
        reported = struct('key', key, 'value', {value});
    end
    function r = get()
        r = reported;
    end
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

function test_aLogicalBecomesOneCheckboxSittingAtItsDefault(testCase)
% Two items for a two-state setting, not three: On and "Default (on)" drew the
% identical picture and differed only in whether a value was stored.
panel = build(testCase, toggleParam(), struct());
testCase.verifyEmpty(findall(panel, 'Type', 'uidropdown'));
cb = findall(panel, 'Type', 'uicheckbox');
testCase.assertNumElements(cb, 1);
testCase.verifyTrue(cb.Value, 'an untouched setting shows the default it will use');
testCase.verifyEqual(cb.Text, 'Confidence band', ...
    'the checkbox is its own label - a bare box is a poor click target');
end

function test_aPipeSeparatedRangeBecomesADropdownOfThoseChoices(testCase)
% Nothing new is declared in the registry for this - validRange already is a
% closed list, so it can drive the control.
panel = build(testCase, choiceParam(), struct());
dd = findall(panel, 'Type', 'uidropdown');
testCase.verifyEqual(dd.Items, {'mean', 'peak', 'area'}, ...
    'no separate Default item: the dropdown can show "mean" itself');
testCase.verifyEqual(dd.Value, 'mean');
end

function test_choosingTheDefaultReportsAbsenceRatherThanTheValue(testCase)
% The whole basis for dropping the Default item. Setting a param to what the
% draw function would have done anyway must leave it unset, or it stops
% following that function if the default ever changes.
[panel, lastChange] = buildWatched(testCase, choiceParam(), struct('measure', 'peak'));
dd = findall(panel, 'Type', 'uidropdown');
testCase.assertEqual(dd.Value, 'peak');

dd.Value = 'mean';
dd.ValueChangedFcn(dd, []);
r = lastChange();
testCase.verifyEqual(r.key, 'measure');
testCase.verifyEmpty(r.value, 'selecting the default means "unset", not "= mean"');

dd.Value = 'area';
dd.ValueChangedFcn(dd, []);
r = lastChange();
testCase.verifyEqual(r.value, 'area', 'a non-default choice is still reported');
end

function test_unTickingADefaultOnToggleReportsFalse(testCase)
[panel, lastChange] = buildWatched(testCase, toggleParam(), struct());
cb = findall(panel, 'Type', 'uicheckbox');
cb.Value = false;
cb.ValueChangedFcn(cb, []);
r = lastChange();
testCase.verifyEqual(r.value, false);

cb.Value = true;
cb.ValueChangedFcn(cb, []);
r = lastChange();
testCase.verifyEmpty(r.value, 'back to the default is back to unset');
end

function test_aSettingWithNoStatedDefaultKeepsAnExplicitDefaultItem(testCase)
% The honest fallback. With no placeholder there is nothing for the comparison
% to match, so a checkbox could not express "untouched" - say so in the control
% rather than guessing that off means default.
m = makeParam('legend', 'Legend', '', 'on|off', 'desc', 'type', 'logical');
panel = build(testCase, m, struct());
testCase.verifyEmpty(findall(panel, 'Type', 'uicheckbox'));
dd = findall(panel, 'Type', 'uidropdown');
testCase.assertNumElements(dd, 1);
testCase.verifyEqual(dd.Items, {'Default', 'On', 'Off'});
testCase.verifyEmpty(dd.Value);
end

function test_aDefaultOutsideItsOwnChoicesAlsoFallsBack(testCase)
% A registry entry naming "(median)" where the choices are mean|peak|area is a
% mistake, but the form must not silently show one of the three as if it were
% the default.
m = makeParam('measure', 'Measure', '', 'mean | peak | area', 'desc', ...
              'type', 'string', 'placeholder', '(median)');
panel = build(testCase, m, struct());
dd = findall(panel, 'Type', 'uidropdown');
testCase.verifyEqual(dd.Items, {'Default', 'mean', 'peak', 'area'});
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
cb = findall(panel, 'Type', 'uicheckbox');
testCase.verifyFalse(cb.Value);
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
