
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_tesaVersionGating < matlab.unittest.TestCase
% TEST_TESAVERSIONGATING  Steps appear only when the plugin can run them.
%
%   TESA 1.2 exists only as unreleased commits upstream, so the six steps
%   wrapping it must be invisible on a stock 1.1.1 install - and a pipeline
%   that references one must be BLOCKED with an explanation, not silently
%   skipped. Those are different requirements and both are checked here.
%
%   The version is read from the plugin's own declaration and never inferred
%   from whether a function is on the path. That distinction is not
%   theoretical: nestapp shipped vendored copies of pop_tesa_robustdetrend in
%   src/, so exist() said "1.2 is here" on a 1.1.1 machine. A probe would have
%   offered steps the plugin cannot run.

    properties
        registry
    end

    methods (TestClassSetup)
        function setup(tc)
            if ~exist('eeglab', 'file')
                tc.assumeFail('EEGLAB not on path');
            end
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            tc.registry = stepRegistry();
        end
    end

    methods (Test)
        function version_comes_from_the_declaration_not_a_probe(tc)
            [v, source] = tesaVersion(true);
            tc.verifySize(v, [1 3]);
            tc.verifyEqual(source, 'vers', ...
                'Version must be read from eegplugin_tesa''s own declaration');
            tc.verifyEqual(v, [1 1 1], ...
                'The bundled plugin is TESA 1.1.1');
        end

        function tesa12_steps_are_hidden_on_this_install(tc)
            offered = {availableSteps(tc.registry).name};
            for n = tesa12Steps()
                tc.verifyFalse(ismember(n{1}, offered), sprintf( ...
                    ['%s requires TESA 1.2 and the installed plugin is older; ' ...
                     'it must not be offered in the picker.'], n{1}));
            end
        end

        function steps_that_do_not_need_12_are_still_offered(tc)
            % The gate must not quietly swallow everything else.
            offered = {availableSteps(tc.registry).name};
            for n = {'Load Data', 'Re-Reference', 'Epoching', 'Frequency Filter'}
                tc.verifyTrue(ismember(n{1}, offered), ...
                    sprintf('%s has no version requirement and must be offered', n{1}));
            end
            tc.verifyGreaterThan(numel(offered), numel(tesa12Steps()), ...
                'Almost every step should still be available');
        end

        function a_pipeline_using_one_is_blocked_with_the_reason(tc)
            % Hiding it from the picker is not enough - a pipeline saved on a
            % 1.2 machine and opened here must fail loudly at the pre-flight.
            [ok, msg] = checkStepDependencies({'Load Data', 'Robust Detrend (TESA)'}, {});
            tc.verifyFalse(ok, 'A step needing TESA 1.2 must block the run');
            tc.verifyTrue(contains(msg, 'Robust Detrend (TESA)'), ...
                'The message must name the offending step');
            tc.verifyTrue(contains(msg, '1.2'), ...
                'The message must state the version required');
            tc.verifyTrue(contains(msg, '1.1.1'), ...
                'The message must state the version installed');
        end

        function the_gate_opens_when_the_plugin_reports_12(tc)
            % The other direction. Shadow eegplugin_tesa with a stub declaring
            % 1.2 and confirm the same code now considers the steps available -
            % otherwise this suite only ever proves the "hidden" half.
            d = tempname; mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            fid = fopen(fullfile(d, 'eegplugin_tesa.m'), 'w');
            fprintf(fid, 'function vers = eegplugin_tesa(fig, t, c)\n');
            fprintf(fid, '    vers = ''tesa1.2.0'';\nend\n');
            fclose(fid);

            addpath(d, '-begin');
            tc.addTeardown(@() rmpath(d));
            tc.addTeardown(@() tesaVersion(true));   % restore the real reading
            rehash path;

            v = tesaVersion(true);
            tc.assertEqual(v, [1 2 0], 'The stub should now be what is found');

            k = find(strcmp({tc.registry.name}, 'Robust Detrend (TESA)'), 1);
            [ok, unmet] = stepAvailability(tc.registry(k));
            % which() still cannot find the function - the plugin is a stub -
            % but the VERSION requirement must now be satisfied, which is what
            % this test is about.
            % Read .kind rather than matching the note: a version-gated
            % requirement's INSTALL note also mentions the version, so the
            % two messages are not distinguishable by text.
            versionComplaints = {unmet(strcmp({unmet.kind}, 'version')).fn};
            tc.verifyEmpty(versionComplaints, ...
                'With 1.2 declared, the version requirement must be satisfied');
            tc.verifyFalse(ok, ...
                'Still unavailable here, but now for the honest reason: the stub has no functions');
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function names = tesa12Steps()
names = {'Robust Detrend (TESA)', 'Robust Demean (TESA)', ...
         'Modified Bandpass Filter (TESA)', 'Detect Bad Channels (TESA)', ...
         'Fit Artifact Model (TESA)', 'Interactive Channel Reject (TESA)'};
end
