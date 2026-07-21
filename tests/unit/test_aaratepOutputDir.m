
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_aaratepOutputDir < matlab.unittest.TestCase
% TEST_AARATEPOUTPUTDIR  The orchestrator's output folder, derived per file.
%
%   Upstream MOVES an existing output folder aside to <folder>_old# before it
%   writes. That makes a single hand-typed folder actively wrong for a batch:
%   every file after the first displaces its predecessor, the run reports
%   success, and only the last file's output is left where it was asked for.
%
%   So the folder is derived per input file from the batch context the rest of
%   the run already uses. The property that matters is separation - two inputs
%   in one batch must never resolve to the same folder.

    properties
        ctx
    end

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            tc.ctx = buildBatchContext( ...
                {fullfile(tempdir, 'subj01.set'), fullfile(tempdir, 'subj02.set')}, ...
                'aaratep-test', 'typeBased', tempdir);
        end
    end

    methods (Test)
        function two_files_never_share_an_output_folder(tc)
            % The regression this exists for. Sharing means silent data loss.
            a = aaratepOutputDir(tc.ctx, fullfile(tempdir, 'subj01.set'));
            b = aaratepOutputDir(tc.ctx, fullfile(tempdir, 'subj02.set'));
            tc.verifyNotEqual(a, b, ...
                'Two inputs sharing a folder means the second moves the first aside');
        end

        function the_same_file_resolves_the_same_way(tc)
            % Re-running a file must land where it landed before, or reruns
            % scatter output across folders instead of replacing it.
            f = fullfile(tempdir, 'subj01.set');
            tc.verifyEqual(aaratepOutputDir(tc.ctx, f), aaratepOutputDir(tc.ctx, f));
        end

        function output_lands_under_the_configured_output_root(tc)
            % The whole point: it goes where the user already said output goes,
            % not somewhere AARATEP-specific they would have to hunt for.
            d = aaratepOutputDir(tc.ctx, fullfile(tempdir, 'subj01.set'));
            tc.verifyTrue(startsWith(d, tc.ctx.batchRoot), sprintf( ...
                '%s is outside the batch root %s', d, tc.ctx.batchRoot));
        end

        function the_folder_is_named_for_its_input(tc)
            d = aaratepOutputDir(tc.ctx, fullfile(tempdir, 'subj01.set'));
            tc.verifyTrue(contains(d, 'subj01'), ...
                'The folder should be traceable to the file it came from');
        end

        function awkward_filenames_do_not_leak_into_the_path(tc)
            % Spaces and hyphens are normalised the same way the .set
            % destination normalises them, so the two stay side by side.
            d = aaratepOutputDir(tc.ctx, fullfile(tempdir, 'subj 03-post.set'));
            [~, leaf] = fileparts(d);
            tc.verifyFalse(contains(leaf, ' '), 'No spaces in a generated folder name');
            tc.verifyFalse(contains(leaf, '-'), 'No hyphens in a generated folder name');
        end

        function no_batch_context_yields_empty_not_a_guess(tc)
            % A direct processOneFile call has no batch context. Returning ''
            % lets the caller say "set Output folder" rather than inventing a
            % location and writing a user's results somewhere unexpected.
            tc.verifyEmpty(aaratepOutputDir([], fullfile(tempdir, 'subj01.set')));
        end
    end
end
