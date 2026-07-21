
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_pathParams < matlab.unittest.TestCase
% TEST_PATHPARAMS  Path parameters are declared as such, and behave as strings.
%
%   The AARATEP output folder is the only output path in the app a user could
%   be asked to type. It should not be: left empty it resolves from the same
%   output root every other step writes under, so the common case needs no
%   path at all. Covered here: that it is optional, that the type declaration
%   does not change how a value is stored, and that a hand-set path still
%   round-trips for anyone who wants to override the default.

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
        function the_aaratep_output_folder_is_a_folder_param(tc)
            % The one the user has to supply on every run, and the reason the
            % Browse button exists.
            p = paramFor(tc, 'AARATEP Pipeline (whole)', 'outputDir');
            tc.verifyEqual(p.type, 'folder');
            tc.verifyFalse(p.required, ...
                'Empty is meaningful - it means "use the output root" - so it cannot be required');
        end

        function the_lead_field_is_a_file_param(tc)
            p = paramFor(tc, 'AARATEP Pipeline (whole)', 'leadFieldPath');
            tc.verifyEqual(p.type, 'file');
            tc.verifyFalse(p.required, ...
                'Optional - empty means the template lead field');
        end

        function an_unset_output_folder_says_where_output_goes(tc)
            % '(not set)' would read as something missing. Empty is the
            % normal, correct state here, so the cell says what it resolves to.
            reg  = tc.registry;
            step = makePipelineStep('AARATEP Pipeline (whole)', reg);
            k    = find(strcmp({reg.name}, 'AARATEP Pipeline (whole)'), 1);

            shown = valueShownFor(tc, buildParamTableData(step, reg(k)), 'Output folder');
            tc.verifyTrue(contains(lower(shown), 'output root'), sprintf( ...
                'An empty output folder shows "%s"; it should say it uses the output root', shown));
            % The '(' convention greys it, so the hint cannot read as a real path.
            tc.verifyEqual(shown(1), '(');
        end

        function a_chosen_path_replaces_the_hint(tc)
            % Overriding the default must actually show the override.
            reg  = tc.registry;
            step = makePipelineStep('AARATEP Pipeline (whole)', reg);
            step.params.outputDir = tempdir;
            k = find(strcmp({reg.name}, 'AARATEP Pipeline (whole)'), 1);

            shown = valueShownFor(tc, buildParamTableData(step, reg(k)), 'Output folder');
            tc.verifyEqual(shown, tempdir);
            tc.verifyFalse(contains(lower(shown), 'browse'));
        end

        function path_params_convert_exactly_like_strings(tc)
            % Declaring a path must change only the editing affordance, never
            % what ends up stored - otherwise the same value would round-trip
            % differently depending on a GUI hint.
            samples = {'C:\data\out', "C:\data\out", ''};
            for i = 1:numel(samples)
                asString = convertParam(samples{i}, 'string');
                tc.verifyEqual(convertParam(samples{i}, 'folder'), asString);
                tc.verifyEqual(convertParam(samples{i}, 'file'), asString);
            end
        end

        function a_browsed_path_survives_a_save_and_load(tc)
            % An override has to come back unchanged, or a user who set one
            % deliberately silently gets the default instead.
            reg  = tc.registry;
            step = makePipelineStep('AARATEP Pipeline (whole)', reg);
            chosen = tempdir;
            step.params.outputDir = chosen;

            d = tempname; mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            f = fullfile(d, 'p.mat');
            spec = [makePipelineStep('Load Data', reg), step]; %#ok<NASGU>
            pipelineName = 'browse-test'; version = '3'; %#ok<NASGU>
            save(f, 'spec', 'pipelineName', 'version');

            loaded = specFromSaved(load(f), reg);
            k = find(strcmp({loaded.name}, 'AARATEP Pipeline (whole)'), 1);
            tc.verifyEqual(loaded(k).params.outputDir, chosen);
            tc.verifyEmpty(unsetRequiredParams(loaded, reg), ...
                'With the folder chosen, nothing should still be outstanding');
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function p = paramFor(tc, stepName, key)
k = find(strcmp({tc.registry.name}, stepName), 1);
tc.assertNotEmpty(k, sprintf('%s missing from registry', stepName));
params = tc.registry(k).params;
j = find(strcmp({params.key}, key), 1);
tc.assertNotEmpty(j, sprintf('%s has no param %s', stepName, key));
p = params(j);
end

function v = valueShownFor(tc, data, friendlyName)
row = find(strcmp(data(:, 1), friendlyName), 1);
tc.assertNotEmpty(row, sprintf('No "%s" row in the parameter table', friendlyName));
v = char(data{row, 2});
end
