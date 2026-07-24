
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_stepMigration < matlab.unittest.TestCase
% TEST_STEPMIGRATION  Tests for src/canonicalStepName.m legacy-step migration.
%
%   Regression for a silent-wrong-result hazard: 'Run ICA' selected its
%   algorithm through an `icatype` parameter and became three separate steps,
%   one per engine. Migrating it as a NAME-ONLY alias to Run ICA (FastICA)
%   would have quietly run FastICA for every saved pipeline that asked for
%   infomax or Picard - a different decomposition, no error raised, and output
%   that looks entirely plausible. The engine must come from icatype.

    methods (TestClassSetup)
        function addSrcPath(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'src'));
            tc.addTeardown(@rmpath, fullfile(root, 'src'));
        end
    end

    methods (Test)
        % --- the hazard: engine must follow icatype, not the name ---------
        function runica_migrates_to_infomax_not_fastica(tc)
            p = struct('icatype', 'runica', 'approach', 'symm');
            name = canonicalStepName('Run ICA', p);
            tc.verifyEqual(name, 'Run ICA (Infomax)');
        end

        function picard_migrates_to_picard(tc)
            p = struct('icatype', 'picard');
            tc.verifyEqual(canonicalStepName('Run ICA', p), 'Run ICA (Picard)');
        end

        function fastica_migrates_to_fastica(tc)
            p = struct('icatype', 'fastica');
            tc.verifyEqual(canonicalStepName('Run ICA', p), 'Run ICA (FastICA)');
        end

        function missing_icatype_uses_old_default(tc)
            % The old step defaulted to fastica, so a spec that never set
            % icatype must land on FastICA.
            tc.verifyEqual(canonicalStepName('Run ICA', struct()), ...
                'Run ICA (FastICA)');
        end

        % --- parameter handling -------------------------------------------
        function icatype_is_consumed(tc)
            [~, p] = canonicalStepName('Run ICA', struct('icatype', 'fastica'));
            tc.verifyFalse(isfield(p, 'icatype'));
        end

        function fastica_keeps_its_parameters(tc)
            in = struct('icatype', 'fastica', 'approach', 'defl', ...
                        'g', 'gauss', 'stabilization', 'off');
            [~, p] = canonicalStepName('Run ICA', in);
            tc.verifyEqual(p.approach,      'defl');
            tc.verifyEqual(p.g,             'gauss');
            tc.verifyEqual(p.stabilization, 'off');
        end

        function infomax_drops_fastica_only_parameters(tc)
            % The old dispatch stripped these before calling pop_runica for
            % runica (they crash its parser), so dropping them preserves
            % behaviour exactly.
            in = struct('icatype', 'runica', 'approach', 'symm', ...
                        'g', 'tanh', 'stabilization', 'on');
            [~, p] = canonicalStepName('Run ICA', in);
            tc.verifyFalse(isfield(p, 'approach'));
            tc.verifyFalse(isfield(p, 'g'));
            tc.verifyFalse(isfield(p, 'stabilization'));
            tc.verifyEqual(p.extended, 'on');
        end

        % --- migrations that made a judgement call must say so ------------
        function infomax_migration_reports_the_extended_assumption(tc)
            [~, ~, note] = canonicalStepName('Run ICA', ...
                struct('icatype', 'runica'));
            tc.verifyNotEmpty(note);
            tc.verifyTrue(contains(lower(note), 'extended'));
        end

        function unknown_engine_is_not_guessed(tc)
            % binica has no equivalent step. Leaving the name unmigrated makes
            % the caller's "unknown step" warning fire, which is far better
            % than silently picking an engine for the user.
            [name, ~, note] = canonicalStepName('Run ICA', ...
                struct('icatype', 'binica'));
            tc.verifyEqual(name, 'Run ICA');
            tc.verifyNotEmpty(note);
        end

        % --- existing behaviour must be preserved -------------------------
        function pure_rename_still_works(tc)
            tc.verifyEqual( ...
                canonicalStepName('Remove Recording Noise (SOUND)'), ...
                'Source-Informed Sensor Cleaning (SOUND)');
        end

        function single_argument_call_still_works(tc)
            % processOneFile and methodsClause call this name-only.
            tc.verifyEqual(canonicalStepName('Epoching'), 'Epoching');
        end

        function current_names_pass_through_unchanged(tc)
            tc.verifyEqual(canonicalStepName('Run ICA (Picard)'), ...
                'Run ICA (Picard)');
        end

        function non_char_input_is_tolerated(tc)
            tc.verifyEqual(canonicalStepName(42), 42);
        end

        % --- retired AARATEP steps migrate rather than break --------------
        function aaratep_muscle_migrates_to_manual_command(tc)
            % Retired step -> Manual Command calling the kept helper, window
            % and threshold carried across so the pipeline runs what it asked.
            p = struct('winStartMs', 12, 'winEndMs', 28, 'muscleThreshold', 6);
            [name, params, note] = canonicalStepName('Flag ICA Components (AARATEP Muscle)', p);
            tc.verifyEqual(name, 'Manual Command');
            tc.verifyTrue(contains(params.command, 'aaratepMuscleClassifier'));
            tc.verifyTrue(contains(params.command, '''winStartMs'', 12'));
            tc.verifyTrue(contains(params.command, '''muscleThreshold'', 6'));
            tc.verifyNotEmpty(note);
        end

        function aaratep_bandpass_migrates_to_tesa_with_baked_window(tc)
            % Retired AARATEP bandpass -> TESA step. The x3 artifact multiplier
            % must be baked into the window (the TESA step has no multiplier),
            % or the migrated pipeline would filter a 3x-narrower artifact span.
            p = struct('lowCutoff', 1, 'highCutoff', 0, 'artifactStartMs', -2, ...
                'artifactEndMs', 12, 'artifactMultiplier', 3, 'piecewiseTimeToExtend', 0.5);
            [name, params, note] = canonicalStepName('Modified Bandpass Filter (AARATEP)', p);
            tc.verifyEqual(name, 'Modified Bandpass Filter (TESA)');
            tc.verifyEqual(params.artifactStartMs, -6);   % -2 x 3
            tc.verifyEqual(params.artifactEndMs,   36);   % 12 x 3
            tc.verifyEqual(params.extendMs, 500);         % 0.5 s -> ms
            tc.verifyEmpty(params.highCutoff);            % 0 -> [] (no low-pass)
            tc.verifyEqual(params.filterMethod, 'butterworth');
            tc.verifyNotEmpty(note);
        end
    end
end
