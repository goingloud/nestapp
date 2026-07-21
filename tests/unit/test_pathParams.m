
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_pathParams < matlab.unittest.TestCase
% TEST_PATHPARAMS  Path parameters are declared as such, and behave as strings.
%
%   A path typed by hand into a table cell is easy to get wrong and gives no
%   feedback until the run fails. Parameters that hold one are declared
%   'folder' or 'file', which is what enables the Browse button beside the
%   parameter table.
%
%   The button itself needs the app open and is not covered here. What is
%   covered is everything that decides its behaviour: which parameters are
%   paths, and that declaring one does not change how the value is stored or
%   converted.

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
            tc.verifyTrue(p.required, ...
                'It is required as well as browsable - the run cannot start without it');
        end

        function the_lead_field_is_a_file_param(tc)
            p = paramFor(tc, 'AARATEP Pipeline (whole)', 'leadFieldPath');
            tc.verifyEqual(p.type, 'file');
            tc.verifyFalse(p.required, ...
                'Optional - empty means the template lead field');
        end

        function an_unset_path_cell_names_the_control_that_fills_it(tc)
            % '(not set)' says something is missing but not what to do. The
            % required one has to point at Browse, because a user who does not
            % find that button types the path by hand or gives up.
            reg  = tc.registry;
            step = makePipelineStep('AARATEP Pipeline (whole)', reg);
            k    = find(strcmp({reg.name}, 'AARATEP Pipeline (whole)'), 1);

            data = buildParamTableData(step, reg(k));
            shown = valueShownFor(tc, data, 'Output folder');
            tc.verifyTrue(contains(lower(shown), 'browse'), sprintf( ...
                'An unset output folder shows "%s"; it should name Browse', shown));

            % Placeholders are greyed by the '(' convention - without it the
            % hint would read as a real value the user had already chosen.
            tc.verifyEqual(shown(1), '(');
        end

        function a_chosen_path_replaces_the_hint(tc)
            % The hint must not linger once Browse has written a value.
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
            % What the Browse button writes has to come back unchanged, or the
            % user picks a folder and the run still fails.
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
