
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_requiredParams < matlab.unittest.TestCase
% TEST_REQUIREDPARAMS  A template that cannot run yet must say so on load.
%
%   The AARATEP template calls upstream's orchestrator, which asserts on three
%   settings - pulse event type, output folder, epoch window. An output folder
%   has no sensible default, so the template ships without one and the app asks
%   when the template is loaded.
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
            tc.verifyEqual(sort(req), {'epochTimespan', 'outputDir', 'pulseEvents'}, ...
                'These are the three upstream asserts on; they must be declared required');
        end

        function the_shipped_template_is_flagged_as_needing_input(tc)
            % The real case: load the template as shipped and confirm the app
            % would prompt, naming the output folder.
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            S = load(fullfile(root, 'src', 'templates', '4_aaratep.mat'));
            spec = specFromSaved(S, tc.registry);

            [stepIdx, keys, labels] = unsetRequiredParams(spec, tc.registry);
            tc.assertNotEmpty(stepIdx, ...
                'The AARATEP template ships without an output folder and must prompt');
            tc.verifyEqual(spec(stepIdx).name, 'AARATEP Pipeline (whole)');
            tc.verifyTrue(ismember('outputDir', keys));
            tc.verifyNotEmpty(labels, 'The prompt needs friendly names, not raw keys');
            % The template DOES supply these two, so they must not be asked for.
            tc.verifyFalse(ismember('pulseEvents', keys), ...
                'pulseEvents is set by the template and must not be requested');
            tc.verifyFalse(ismember('epochTimespan', keys), ...
                'epochTimespan is set by the template and must not be requested');
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
                          'params', struct('pulseEvents', {{'TMS'}}, ...
                                           'outputDir', '   ', ...
                                           'epochTimespan', [-1 1.5]));
            [~, keys] = unsetRequiredParams(spec, tc.registry);
            tc.verifyTrue(ismember('outputDir', keys));
        end

        function ordinary_templates_prompt_for_nothing(tc)
            % The prompt must not fire on templates that are ready to run.
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            for f = {'1_tesa_tep.mat', '2_resting_state.mat', '3_minimal.mat'}
                S = load(fullfile(root, 'src', 'templates', f{1}));
                spec = specFromSaved(S, tc.registry);
                tc.verifyEmpty(unsetRequiredParams(spec, tc.registry), ...
                    sprintf('%s should be runnable as shipped', f{1}));
            end
        end
    end
end
