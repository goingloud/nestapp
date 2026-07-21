
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_requiredParams < matlab.unittest.TestCase
% TEST_REQUIREDPARAMS  A template that cannot run yet must say so on load.
%
%   The AARATEP template calls upstream's orchestrator, which asserts on three
%   settings - pulse event type, epoch window, output folder. Two of those the
%   template supplies; the output folder resolves from the output root, so it
%   needs no default and is not asked for.
%
%   The decision of WHICH parameters need asking about is data on the parameter
%   (makeParam(..., 'required', true)), so it is testable without the GUI. The
%   dialog itself is not covered here; the logic that drives it is.

    properties
        registry
    end

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            tc.registry = stepRegistry();
        end
    end

    methods (Test)
        function orchestrator_declares_its_required_settings(tc)
            k = find(strcmp({tc.registry.name}, 'AARATEP Pipeline (whole)'), 1);
            tc.assertNotEmpty(k);
            params = tc.registry(k).params;
            req = {params([params.required]).key};
            tc.verifyEqual(sort(req), {'epochTimespan', 'pulseEvents'}, ...
                ['Upstream also asserts on outputDir, but that one resolves from ' ...
                 'the output root, so it must NOT be required']);
        end

        function the_shipped_template_asks_for_nothing(tc)
            % It used to prompt for an output folder on every load. That
            % prompt is gone because the folder now resolves from the output
            % root - so the template must load ready to run.
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            S = load(fullfile(root, 'src', 'templates', '4_aaratep.mat'));
            spec = specFromSaved(S, tc.registry);

            [stepIdx, keys] = unsetRequiredParams(spec, tc.registry);
            tc.verifyEmpty(stepIdx, sprintf( ...
                'The AARATEP template should load ready to run; it asked for: %s', ...
                strjoin(keys, ', ')));
        end

        function a_pipeline_missing_its_pulse_events_is_still_caught(tc)
            % The prompt machinery still has to work for the settings that do
            % need a human - dropping the outputDir prompt must not disable it.
            reg  = tc.registry;
            step = makePipelineStep('AARATEP Pipeline (whole)', reg);
            step.params.pulseEvents   = {};
            step.params.epochTimespan = [-1 1.5];

            [stepIdx, keys] = unsetRequiredParams(step, reg);
            tc.verifyNotEmpty(stepIdx);
            tc.verifyTrue(ismember('pulseEvents', keys));
        end

        function nothing_is_asked_once_the_value_is_supplied(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            S = load(fullfile(root, 'src', 'templates', '4_aaratep.mat'));
            spec = specFromSaved(S, tc.registry);
            k = find(strcmp({spec.name}, 'AARATEP Pipeline (whole)'), 1);
            spec(k).params.outputDir = tempdir;

            tc.verifyEmpty(unsetRequiredParams(spec, tc.registry), ...
                'With every required value supplied there is nothing to prompt for');
        end

        function a_blank_string_does_not_count_as_supplied(tc)
            % Whitespace in a text box is the commonest way to "fill in" a
            % field without filling it in.
            spec = struct('name', 'AARATEP Pipeline (whole)', ...
                          'params', struct('pulseEvents', {{'   '}}, ...
                                           'outputDir', '', ...
                                           'epochTimespan', [-1 1.5]));
            [~, keys] = unsetRequiredParams(spec, tc.registry);
            tc.verifyTrue(ismember('pulseEvents', keys));
        end

        function ordinary_templates_prompt_for_nothing(tc)
            % The prompt must not fire on templates that are ready to run.
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            for f = {'1_tesa_tep.mat', '2_resting_state.mat', '3_minimal.mat', '4_aaratep.mat'}
                S = load(fullfile(root, 'src', 'templates', f{1}));
                spec = specFromSaved(S, tc.registry);
                tc.verifyEmpty(unsetRequiredParams(spec, tc.registry), ...
                    sprintf('%s should be runnable as shipped', f{1}));
            end
        end
    end
end
