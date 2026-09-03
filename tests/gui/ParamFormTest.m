% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef ParamFormTest < NestappTestCase
% PARAMFORMTEST  The control a setting gets, and what "untouched" means.
%
%   In tests/gui because paramForm builds real uicontrols. It needs a display
%   but NOT the app - the form goes into a bare uipanel - which is why this is
%   gui/ rather than eeglab_gui/, and why it costs milliseconds rather than the
%   two to four seconds an app launch does.
%
%   Two things are worth pinning. The control follows from what a param already
%   DECLARES, so a new registry entry needs no UI work. And UNSET SURVIVES: a
%   setting nobody touched must stay absent from the values struct, because the
%   defaults live in the draw function and a value frozen here would stop
%   following them.
%
%   Ledger row C1: unticking a DERIVED default used to leave 0 0 in the fields
%   and hand it over, which silently replaced "the first window of interest"
%   with the single sample at t = 0.

    properties (TestParameter)
        % Every control kind the form can infer, and the shape it must produce.
        control = struct( ...
            'logicalBecomesACheckbox', struct( ...
                'param', 'toggle',  'type', 'uicheckbox'), ...
            'closedListBecomesADropdown', struct( ...
                'param', 'choice',  'type', 'uidropdown'), ...
            'listValuedBecomesAListbox', struct( ...
                'param', 'multi',   'type', 'uilistbox'), ...
            'twoElementVectorBecomesNumberFields', struct( ...
                'param', 'range',   'type', 'uinumericeditfield'), ...
            'freeTextBecomesAnEditField', struct( ...
                'param', 'text',    'type', 'uieditfield'))
    end

    methods (Test)

        % ── the control follows the declaration ──────────────────────────────

        function theControlIsInferredFromWhatTheParamDeclares(tc, control)
        % No registry entry names a widget. The type plus whether the value has
        % a closed list of choices is enough, which is what lets a new setting
        % arrive with a usable editor and no UI change.
        % The context is supplied for every case, not just the multi-select:
        % a param naming a choice source falls back to a text field when the
        % choices are absent, which is right, and is covered separately.
            panel = tc.buildForm(tc.paramNamed(control.param), struct(), tc.windowCtx());
            tc.verifyNotEmpty(findall(panel, 'Type', control.type), ...
                sprintf('expected a %s', control.type));
        end

        function aCheckboxCarriesItsOwnLabelRatherThanABareBox(tc)
        % A bare checkbox is a poor click target, and a separate label beside
        % it just repeats the text.
            panel = tc.buildForm(tc.paramNamed('toggle'));
            cb = findall(panel, 'Type', 'uicheckbox');
            tc.verifyEqual(cb.Text, 'Confidence band');
        end

        function aDropdownOffersOnlyItsRealChoicesWhenTheDefaultIsKnown(tc)
        % Two items for a two-state setting, not three. "Default (mean)" and
        % "mean" drew the identical picture and differed only in whether a
        % value was stored.
            panel = tc.buildForm(tc.paramNamed('choice'));
            dd = findall(panel, 'Type', 'uidropdown');
            tc.verifyEqual(dd.Items, {'mean', 'peak', 'area'});
            tc.verifyEqual(dd.Value, 'mean');
        end

        function aSettingWithNoStatedDefaultKeepsAnExplicitDefaultItem(tc)
        % The honest fallback: with nothing for a comparison to match, no
        % control state can mean "untouched", so the control says so rather
        % than showing one of the choices as if it were the default.
            m = makeParam('legend', 'Legend', '', 'on|off', 'd', 'type', 'logical');
            panel = tc.buildForm(m);
            tc.verifyEmpty(findall(panel, 'Type', 'uicheckbox'));
            dd = findall(panel, 'Type', 'uidropdown');
            tc.verifyEqual(dd.Items, {'Default', 'On', 'Off'});
        end

        % ── unset survives ───────────────────────────────────────────────────

        function choosingTheDefaultReportsAbsenceNotTheValue(tc)
        % The whole basis for dropping the Default item. Setting a param to
        % what the draw function would have done anyway must leave it unset, or
        % it stops following that function if the default ever changes.
            [panel, last] = tc.buildForm(tc.paramNamed('choice'), struct('measure', 'peak'));
            dd = findall(panel, 'Type', 'uidropdown');

            tc.setAndFire(dd, 'mean');
            tc.verifyEmpty(last().value, 'selecting the default means unset');

            tc.setAndFire(dd, 'area');
            tc.verifyEqual(last().value, 'area', 'a real choice is still reported');
        end

        function unTickingADerivedDefaultStatesNothing(tc)
        % Ledger C1. The fields fall back to 0 because there is no number to
        % show, and handing that over replaced "the first window of interest"
        % with the single sample at 0 ms - which sits inside the epoch, so
        % nothing downstream errored and the map just described one sample.
            m = makeParam('window', 'Time window', 'ms', 't1 t2', 'd', ...
                          'type', 'vector', 'placeholder', '(first window of interest)');
            [panel, last] = tc.buildForm(m);
            cb = findall(panel, 'Type', 'uicheckbox');
            tc.assertTrue(cb.Value, 'a derived default starts in force');

            tc.setAndFire(cb, false);
            tc.verifyEmpty(last().value, ...
                'unticking alone states no number, so the setting stays unset');
        end

        function editingAFieldOnADerivedRowDoesReportIt(tc)
            m = makeParam('window', 'Time window', 'ms', 't1 t2', 'd', ...
                          'type', 'vector', 'placeholder', '(first window of interest)');
            [panel, last] = tc.buildForm(m);
            tc.setAndFire(findall(panel, 'Type', 'uicheckbox'), false);

            f = findall(panel, 'Type', 'uinumericeditfield');
            f(1).Value = 60; f(2).Value = 90;
            tc.setAndFire(f(2), f(2).Value);
            tc.verifyEqual(sort(last().value), [60 90]);
        end

        function aNamedNumericDefaultStillReportsOnUnticking(tc)
        % Where the placeholder DOES name numbers, "(-50 300)" is a real
        % default and unticking hands over exactly what is displayed.
            [panel, last] = tc.buildForm(tc.paramNamed('range'));
            tc.setAndFire(findall(panel, 'Type', 'uicheckbox'), false);
            tc.verifyEqual(sort(last().value), [-50 300]);
        end

        % ── the multi-select's two collapsed states ──────────────────────────

        function anUnsetMultiselectShowsEverythingSelected(tc)
        % Because that is what unset DOES: no subset named means all of them.
            panel = tc.buildForm(tc.paramNamed('multi'), struct(), tc.windowCtx());
            lb = findall(panel, 'Type', 'uilistbox');
            tc.verifyEqual(sort(lb.Value), sort({'N15', 'P30', 'N100'}));
        end

        function selectingEveryItemIsTheSameAsNotChoosing(tc)
            [panel, last] = tc.buildForm(tc.paramNamed('multi'), struct(), tc.windowCtx());
            lb = findall(panel, 'Type', 'uilistbox');
            tc.setAndFire(lb, {'P30'});
            tc.verifyEqual(last().value, {'P30'});
            tc.setAndFire(lb, {'N15', 'P30', 'N100'});
            tc.verifyEmpty(last().value);
        end

        function aStaleSelectionFallsBackToEverythingRatherThanNothing(tc)
        % A window renamed since the setting was saved. Showing an empty list
        % would misreport the picture the plot actually draws.
            panel = tc.buildForm(tc.paramNamed('multi'), ...
                                 struct('mapWindows', {{'N45'}}), tc.windowCtx());
            lb = findall(panel, 'Type', 'uilistbox');
            tc.verifyEqual(sort(lb.Value), sort({'N15', 'P30', 'N100'}));
        end

        % ── the contract that makes the registry the extension point ─────────

        function everyRegistryParamGetsAControl(tc)
        % Asserted on what paramForm RETURNS rather than by counting widget
        % types: counting had to be extended for every new control, and could
        % not tell one param's two handles from two params with one each.
            reg = plotRegistry();
            for k = 1:numel(reg)
                if isempty(reg(k).params); continue; end
                [~, ~, rows] = tc.buildForm(reg(k).params, struct(), tc.windowCtx());
                tc.verifyEqual({rows.key}, {reg(k).params.key}, ...
                    sprintf('%s has a setting with no control', reg(k).name));
            end
        end

        function theFormFitsInsideThePanelItWasSizedFor(tc)
        % The failure paramFormHeight exists to prevent: a form that overflows
        % its panel, with a setting invisible and nothing reporting it.
            meta  = [tc.paramNamed('range'), tc.paramNamed('multi'), ...
                     tc.paramNamed('toggle')];
            panel = tc.buildForm(meta, struct(), tc.windowCtx());
            for h = findall(panel, '-property', 'Position')'
                if isequal(h, panel); continue; end
                p = h.Position;
                tc.verifyGreaterThanOrEqual(p(2), 0, 'runs off the bottom');
                tc.verifyLessThanOrEqual(p(2) + p(4), panel.Position(4) + 1, ...
                                         'runs off the top');
            end
        end
    end

    % ── fixtures ─────────────────────────────────────────────────────────────
    methods (Access = private)

        function m = paramNamed(~, kind)
        % The five shapes the form has to tell apart, in one place so a test
        % naming one is naming a kind of setting rather than repeating a
        % makeParam call.
            switch kind
                case 'toggle'
                    m = makeParam('showBand', 'Confidence band', '', 'on|off', ...
                                  'd', 'type', 'logical', 'placeholder', '(on)');
                case 'choice'
                    m = makeParam('measure', 'Measure', '', 'mean | peak | area', ...
                                  'd', 'type', 'string', 'placeholder', '(mean)');
                case 'multi'
                    m = makeParam('mapWindows', 'Windows to map', '', '', 'd', ...
                                  'type', 'stringlist', 'choicesFrom', 'windows', ...
                                  'placeholder', '(all of them)');
                case 'range'
                    m = makeParam('xlim', 'Time range', 'ms', 't1 t2', 'd', ...
                                  'type', 'vector', 'placeholder', '(-50 300)');
                case 'text'
                    m = makeParam('title', 'Title', '', '', 'd', 'type', 'string');
            end
        end

        function ctx = windowCtx(~)
            ctx = struct('windows', {{'N15', 'P30', 'N100'}});
        end

        function [panel, lastChange, rows] = buildForm(tc, meta, values, ctx)
        % Builds the form and hands back a getter for what it last reported.
        %
        % lastChange is a NESTED function, not @() reported - an anonymous
        % handle captures by value at construction and would always answer with
        % the seed. The panel is sized with paramFormHeight, the same call the
        % real caller makes, so a height bug shows up here rather than being
        % masked by a generously-sized test panel.
            if nargin < 3; values = struct(); end
            if nargin < 4; ctx = struct(); end
            reported = struct('key', '', 'value', 'never called');

            fig = uifigure('Visible', 'off', 'Position', [100 100 520 600]);
            tc.addTeardown(@() delete(fig));
            panel = uipanel(fig, 'Position', [0 0 480 paramFormHeight(meta)]);
            rows  = paramForm(panel, meta, values, @record, ctx);
            lastChange = @get;

            function record(key, value)
                reported = struct('key', key, 'value', {value});
            end
            function r = get()
                r = reported;
            end
        end

        function setAndFire(~, h, value)
        % Set a control and run its callback, the way a click would. Written
        % once because eight tests do it and the two-line form obscures which
        % value each test is actually about.
            h.Value = value;
            h.ValueChangedFcn(h, []);
        end
    end
end
