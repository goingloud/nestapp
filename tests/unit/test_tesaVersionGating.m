
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_tesaVersionGating < matlab.unittest.TestCase
% TEST_TESAVERSIONGATING  Steps appear only when the plugin can run them.
%
%   Six steps wrap functions introduced in TESA 1.2. They must be offered
%   only when the installed plugin is at least 1.2, and a pipeline that
%   references one on an older plugin must be BLOCKED with an explanation, not
%   silently skipped. Both directions are checked here.
%
%   The version is read from the plugin's own declaration and never inferred
%   from whether a function is on the path. That distinction is not
%   theoretical: nestapp once shipped vendored copies of pop_tesa_robustdetrend
%   in src/, so exist() said "1.2 is here" on a 1.1.1 machine. A probe would
%   have offered steps the plugin could not run.
%
%   The install this runs on is TESA 1.2.0, so the "available" direction is
%   checked against the real plugin; the "too old" direction is checked by
%   shadowing eegplugin_tesa with a stub declaring an older version - which the
%   version gate rejects BEFORE the function-presence check, so the real 1.2
%   functions on the path do not mask it.

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
        function version_is_read_from_the_declaration_not_probed(tc)
            % Shadow the plugin with a distinctive declared version and confirm
            % tesaVersion parses exactly that - proving it reads the string, not
            % the install, and keeping this test correct across future upgrades.
            restore = shadowTesaVersion(tc, '9.8.7');   %#ok<NASGU>
            [v, source] = tesaVersion(true);
            tc.verifySize(v, [1 3]);
            tc.verifyEqual(source, 'vers', ...
                'Version must be read from eegplugin_tesa''s own declaration');
            tc.verifyEqual(v, [9 8 7], ...
                'tesaVersion must parse the declared version, whatever it is');
        end

        function the_installed_plugin_is_at_least_12(tc)
            % Sanity anchor for the rest of the suite: the real install must be
            % 1.2+ for the "available" tests below to mean anything.
            v = tesaVersion(true);
            tc.verifyFalse(versionLess(v, [1 2 0]), sprintf( ...
                'This suite expects TESA 1.2+ installed; found %d.%d.%d', v));
        end

        function tesa12_steps_are_available_on_this_install(tc)
            offered = {availableSteps(tc.registry).name};
            for n = tesa12Steps()
                tc.verifyTrue(ismember(n{1}, offered), sprintf( ...
                    '%s wraps TESA 1.2, which is installed, so it must be offered.', n{1}));
            end
        end

        function an_installed_12_step_is_fully_runnable(tc)
            % Version satisfied AND the function present -> no unmet
            % requirements. This is what the old stub-only test could not show.
            k = find(strcmp({tc.registry.name}, 'Robust Detrend (TESA)'), 1);
            [ok, unmet] = stepAvailability(tc.registry(k));
            tc.verifyTrue(ok, sprintf( ...
                'Robust Detrend (TESA) should be runnable on 1.2; unmet: %s', ...
                strjoin({unmet.fn}, ', ')));
        end

        function steps_that_do_not_need_12_are_still_offered(tc)
            offered = {availableSteps(tc.registry).name};
            for n = {'Load Data', 'Re-Reference', 'Epoching', 'Frequency Filter'}
                tc.verifyTrue(ismember(n{1}, offered), ...
                    sprintf('%s has no version requirement and must be offered', n{1}));
            end
            tc.verifyGreaterThan(numel(offered), numel(tesa12Steps()), ...
                'Almost every step should still be available');
        end

        function an_older_plugin_hides_the_12_steps(tc)
            % Shadow the plugin with a 1.1.1 declaration: the six steps must
            % drop out of the picker even though the real 1.2 functions are on
            % the path (the version gate is checked first).
            restore = shadowTesaVersion(tc, '1.1.1');   %#ok<NASGU>
            tesaVersion(true);
            offered = {availableSteps(tc.registry).name};
            for n = tesa12Steps()
                tc.verifyFalse(ismember(n{1}, offered), sprintf( ...
                    '%s requires TESA 1.2 and the shadowed plugin is older; it must be hidden.', n{1}));
            end
        end

        function an_older_plugin_blocks_a_pipeline_with_the_reason(tc)
            % Hiding it from the picker is not enough - a pipeline saved on a
            % 1.2 machine and opened on an older one must fail loudly at
            % pre-flight, naming the step and both versions.
            restore = shadowTesaVersion(tc, '1.1.1');   %#ok<NASGU>
            tesaVersion(true);
            [ok, msg] = checkStepDependencies({'Load Data', 'Robust Detrend (TESA)'}, {});
            tc.verifyFalse(ok, 'A step needing TESA 1.2 must block on an older plugin');
            tc.verifyTrue(contains(msg, 'Robust Detrend (TESA)'), ...
                'The message must name the offending step');
            tc.verifyTrue(contains(msg, '1.2'), ...
                'The message must state the version required');
            tc.verifyTrue(contains(msg, '1.1.1'), ...
                'The message must state the version installed');
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function names = tesa12Steps()
names = {'Robust Detrend (TESA)', 'Robust Demean (TESA)', ...
         'Modified Bandpass Filter (TESA)', 'Detect Bad Channels (TESA)', ...
         'Fit Artifact Model (TESA)', 'Interactive Channel Reject (TESA)'};
end

function cleanup = shadowTesaVersion(tc, verStr)
% Put a stub eegplugin_tesa declaring verStr first on the path, so which()
% resolves to it and tesaVersion reads it. Torn down (and the real version
% re-read) after the test.
d = tempname; mkdir(d);
fid = fopen(fullfile(d, 'eegplugin_tesa.m'), 'w');
fprintf(fid, 'function vers = eegplugin_tesa(fig, t, c)\n');
fprintf(fid, '    vers = ''tesa%s'';\nend\n', verStr);
fclose(fid);
addpath(d, '-begin');
rehash path;
cleanup = onCleanup(@() restorePath(d));
tc.addTeardown(@() tesaVersion(true));   % refresh the cache back to the real plugin
end

function restorePath(d)
rmpath(d);
rmdir(d, 's');
rehash path;
end

function tf = versionLess(a, b)
tf = false;
for k = 1:3
    if a(k) < b(k); tf = true;  return; end
    if a(k) > b(k); tf = false; return; end
end
end
