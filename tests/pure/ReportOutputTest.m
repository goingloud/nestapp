% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef ReportOutputTest < NestappTestCase
% REPORTOUTPUTTEST  Where a batch writes, and what its report says.
%
%   In tests/pure despite writing to disk: writing to a temp dir is not an axis
%   the folders split on, because there is no environment where a test can
%   otherwise run but cannot write to tempdir. What it is NOT allowed to do is
%   write anywhere else - which the old suite did, leaving 36 untracked .mat
%   files in its own source directories because exportReport falls back to pwd.
%
%   Ledger rows: A1.4 (the methods text claimed full retention when channels
%   had been removed and later interpolated) and C5 (runPipelineCore had an
%   outputRoot override but not its twin, so a test that isolated one
%   inherited the user's preference for the other).

    properties (TestParameter)
        % The two layouts, and where each puts each kind of artifact. This IS
        % the layout map - the thing a reader wants to see in one place, and
        % the thing a batch's whole on-disk shape depends on.
        layoutCase = struct( ...
            'typeBased_data',    struct('layout','typeBased','kind','data',   'rel','data'), ...
            'typeBased_reports', struct('layout','typeBased','kind','reports','rel','reports'), ...
            'typeBased_qc',      struct('layout','typeBased','kind','qc',     'rel','qc/STEM'), ...
            'typeBased_batch',   struct('layout','typeBased','kind','batch',  'rel','batch'), ...
            'perInput_data',     struct('layout','perInput', 'kind','data',   'rel','STEM'), ...
            'perInput_reports',  struct('layout','perInput', 'kind','reports','rel','STEM'), ...
            'perInput_qc',       struct('layout','perInput', 'kind','qc',     'rel','STEM/qc'), ...
            'perInput_batch',    struct('layout','perInput', 'kind','batch',  'rel','_batch'))
    end

    methods (Test)

        % ── the report's shape ───────────────────────────────────────────────

        function aFreshReportHasItsSchemaAtZero(tc)
        % ONE case. The old suite spent eight tests and 94 lines asserting this
        % - and its first test, "has the required fields", was subsumed by the
        % other seven, every one of which dereferenced those fields and would
        % have errored had any been missing.
            r = initPipelineReport('/data/subject01.set');

            tc.verifyEqual(r.inputFile, '/data/subject01.set');
            tc.verifyClass(r.processedAt, 'datetime');
            tc.verifyEmpty(r.steps);

            tc.verifyEqual([r.channels.original, r.channels.nRejected, ...
                            r.channels.nInterpolated, r.channels.final], [0 0 0 0]);
            tc.verifyEqual([r.trials.original, r.trials.rejected, ...
                            r.trials.final], [0 0 0]);
        end

        function theMethodsTextDisclosesWhatWasRemovedAndInterpolated(tc)
        % Ledger A1.4. After interpolation the final channel count equals the
        % original, so a retention line computed from `final` alone read as
        % though nothing had been lost for a file that lost five channels - a
        % wrong claim in the methods paragraph, which is the half of a report
        % people quote verbatim.
        %
        % The fix ADDED the counts rather than rewording the lead: the text
        % reads "64 of 64 channels were retained (5 removed, 3 interpolated)",
        % and the parenthetical is what stops the first clause misleading. So
        % the assertion is on the disclosure, not on the phrasing - an earlier
        % draft of this test banned the string "64 of 64", which would have
        % failed the correct implementation for using words it dislikes.
            r = initPipelineReport('/data/s.set');
            r.channels = struct('original', 64, 'nRejected', 5, ...
                                'nInterpolated', 3, 'final', 64);
            txt = exportReport(r, scratchDir(tc));

            tc.verifyTrue(contains(txt, '5 removed'), ...
                'a reader must be able to see that channels were lost');
            tc.verifyTrue(contains(txt, '3 interpolated'));
        end

        function theSummaryNamesTheFileItIsAbout(tc)
            r = initPipelineReport('/data/subject07.set');
            tc.verifyTrue(contains(exportReport(r, scratchDir(tc)), 'subject07'));
        end

        % ── where things are written ─────────────────────────────────────────

        function exportReportWritesWhereItIsTold(tc)
        % And nowhere else. exportReport falls back to pwd when handed '',
        % which is reasonable production behaviour and was how the old suite
        % littered 36 .mat files into its own source folders - the tests called
        % it that way, not the app.
            d = scratchDir(tc);
            r = initPipelineReport('/data/s.set');
            [~, matPath] = exportReport(r, d);

            tc.verifyTrue(isfile(matPath));
            tc.verifyTrue(startsWith(matPath, d), ...
                'the report must land in the directory it was given');
        end

        function theLayoutMapPutsEachArtifactWhereItBelongs(tc, layoutCase)
            d   = scratchDir(tc);
            ctx = buildBatchContext({'/in/subject01.set'}, 'demo', ...
                                    layoutCase.layout, d);
            got = outputPaths(ctx, layoutCase.kind, 'subject01');

            want = fullfile(ctx.batchRoot, ...
                            strrep(strrep(layoutCase.rel, 'STEM', 'subject01'), ...
                                   '/', filesep));
            tc.verifyEqual(got, want);
        end

        function theBatchFolderIsTimestampedAndNamedForThePipeline(tc)
        % Two runs of the same pipeline must not write into each other.
            d  = scratchDir(tc);
            c1 = buildBatchContext({'/in/a.set'}, 'TMS-EEG / TEP (TESA)', 'typeBased', d);
            [~, name] = fileparts(c1.batchRoot);
            tc.verifyMatches(name, '^\d{8}_\d{6}_[a-z0-9_]+$');
            tc.verifyTrue(contains(name, 'tms'), ...
                'the pipeline should be identifiable in the folder name');
        end

        function anUnknownArtifactKindIsRefused(tc)
        % Silently inventing a folder for a typo would scatter outputs.
            d   = scratchDir(tc);
            ctx = buildBatchContext({'/in/a.set'}, 'demo', 'typeBased', d);
            tc.verifyError(@() outputPaths(ctx, 'nosuchkind', 'a'), ...
                           'nestapp:outputPaths:badKind');
        end

        function anUnknownLayoutFallsBackRatherThanErroring(tc)
        % A stale preference should not stop a run; typeBased is the documented
        % default, so an unrecognised value lands there.
            d   = scratchDir(tc);
            ctx = buildBatchContext({'/in/a.set'}, 'demo', 'nonsense', d);
            tc.verifyEqual(ctx.layout, 'typeBased');
        end

        function theOutputRootOverrideBeatsThePreference(tc)
        % The half that already existed. Its twin - the layout override - is
        % ledger C5 and is exercised in tests/eeglab, because only a real run
        % goes through runPipelineCore.
            d   = scratchDir(tc);
            ctx = buildBatchContext({'/in/a.set'}, 'demo', 'typeBased', d);
            tc.verifyEqual(ctx.outputRoot, d);
        end
    end
end
