
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_failureSurfacing < matlab.unittest.TestCase
% TEST_FAILURESURFACING  Unit tests for the failed-file surfacing helpers.
%   Covers failedFileRows (dashboard table rows), writeFailedFilesList (the
%   copy-paste re-run list), and the "did not complete" section that
%   summarizeReports adds when handed a failure list. These are the pieces
%   that make a parallel-mode failure visible in the dashboard / reports
%   instead of vanishing after the run.

    methods (TestClassSetup)
        function addSrcPath(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'src'));
            tc.addTeardown(@rmpath, fullfile(root, 'src'));
        end
    end

    methods (Static)
        function failed = sampleFailures()
            % Two records shaped exactly like runPipelineCore's failure log:
            % one hard error, one Quality-Gate skip.
            failed = struct( ...
                'fi',       {1, 2}, ...
                'name',     {'subjA.set', 'subjB.set'}, ...
                'path',     {'C:\data\subjA.set', 'C:\data\subjB.set'}, ...
                'step',     {'21', '3'}, ...
                'stepName', {'Remove ICA Components (TESA)', 'Quality Gate "post-load"'}, ...
                'message',  {sprintf('bad rank\n  at line 5'), 'flatline on 12 channels'}, ...
                'kind',     {'errored', 'skipped'});
        end
    end

    %% failedFileRows
    methods (Test)
        function empty_failed_gives_zero_by_four(tc)
            tc.verifyEqual(failedFileRows(struct([])), cell(0, 4));
            tc.verifyEqual(failedFileRows([]), cell(0, 4));
        end

        function builds_one_row_per_failure_with_verdicts(tc)
            rows = failedFileRows(test_failureSurfacing.sampleFailures());
            tc.verifyEqual(size(rows), [2 4]);

            % File column is the stem (no extension), matching the report rows.
            tc.verifyEqual(rows{1, 1}, 'subjA');
            tc.verifyEqual(rows{2, 1}, 'subjB');

            % Gate column carries the step name.
            tc.verifyEqual(rows{1, 2}, 'Remove ICA Components (TESA)');

            % Verdict distinguishes errored from skipped.
            tc.verifyEqual(rows{1, 3}, 'Errored');
            tc.verifyEqual(rows{2, 3}, 'Skipped');

            % Reason is flattened to a single line.
            tc.verifyFalse(contains(rows{1, 4}, newline));
            tc.verifyTrue(contains(rows{1, 4}, 'bad rank'));
        end

        function missing_step_uses_em_dash(tc)
            f = struct('fi', 1, 'name', 'x.set', 'step', '', ...
                'stepName', '', 'message', 'died early', 'kind', 'errored');
            rows = failedFileRows(f);
            tc.verifyEqual(rows{1, 2}, char(8212));
        end
    end

    %% writeFailedFilesList
    methods (Test)
        function writes_all_paths_as_noncomment_lines(tc)
            failed = test_failureSurfacing.sampleFailures();
            tmp = [tempname '.txt'];
            tc.addTeardown(@() tc.deleteIfExists(tmp));

            writeFailedFilesList(tmp, failed);

            raw = string(splitlines(fileread(tmp)));
            raw = raw(strlength(raw) > 0);
            pathLines = raw(~startsWith(raw, "#"));

            tc.verifyEqual(sort(pathLines), ...
                sort(["C:\data\subjA.set"; "C:\data\subjB.set"]));

            % Every path is preceded by a self-documenting comment.
            tc.verifyTrue(any(contains(raw, "subjA.set") & startsWith(raw, "#")));
        end

        function falls_back_to_name_without_path(tc)
            f = struct('fi', 1, 'name', 'orphan.set', ...
                'stepName', 'Load Data', 'message', 'missing file', 'kind', 'errored');
            tmp = [tempname '.txt'];
            tc.addTeardown(@() tc.deleteIfExists(tmp));

            writeFailedFilesList(tmp, f);

            raw = string(splitlines(fileread(tmp)));
            pathLines = raw(strlength(raw) > 0 & ~startsWith(raw, "#"));
            tc.verifyEqual(pathLines, "orphan.set");
        end
    end

    %% summarizeReports section
    methods (Test)
        function summary_lists_failures_when_provided(tc)
            reports = {test_failureSurfacing.stubReport('a'), ...
                       test_failureSurfacing.stubReport('b')};
            failed = test_failureSurfacing.sampleFailures();

            txt = summarizeReports(reports, failed);

            tc.verifyTrue(contains(txt, 'FILES THAT DID NOT COMPLETE (2)'));
            tc.verifyTrue(contains(txt, 'subjA'));
            tc.verifyTrue(contains(txt, 'Skipped at Quality Gate:'));
        end

        function summary_omits_section_without_failures(tc)
            reports = {test_failureSurfacing.stubReport('a'), ...
                       test_failureSurfacing.stubReport('b')};
            txt = summarizeReports(reports);   % no failed arg = back-compatible
            tc.verifyFalse(contains(txt, 'DID NOT COMPLETE'));
        end
    end

    methods (Static)
        function r = stubReport(tag)
            % Minimal report struct with just the fields summarizeReports reads.
            r.inputFile = ['C:\data\' tag '.set'];
            r.channels = struct('original', 32, 'nRejected', 0, ...
                'nInterpolated', 0, 'final', 32);
            r.trials   = struct('original', 0, 'rejected', 0, 'final', 0);
            r.ica      = struct('nComponents', 0, 'nRejected', 0, 'varRemoved', NaN, ...
                'categories', struct('names', {{}}, 'nRemoved', []));
            r.steps    = {};
        end
    end

    methods
        function deleteIfExists(~, p)
            if exist(p, 'file'); delete(p); end
        end
    end
end
