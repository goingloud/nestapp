% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef CohortCurvesTest < NestappTestCase
% COHORTCURVESTEST  Turning a set of recordings into per-group curves.
%
%   groupCurves is where n is decided, where files on the wrong cap are
%   excluded, and where the ROI actually applied is recorded. Every number in
%   the app downstream of it inherits those decisions, so this is the file that
%   matters most in the suite.
%
%   Uses fakeReducedCache and calls groupCurves directly, rather than
%   fakeGroupResult - which is implemented ON groupCurves and would make these
%   assertions circular.

    methods (Test)

        % ── n is subjects, not files ─────────────────────────────────────────

        function nCountsSubjectsNotRecordings(tc)
        % The defect the whole curve layer was rebuilt around: with n = files,
        % a subject recorded twice counted twice and every interval was
        % narrower than the data supports.
            [cache, entries] = fakeReducedCache('subjects', 4, 'sessions', 1, ...
                                                'repeats', 3);
            res = tc.curvesFor(cache, entries);
            tc.verifyEqual(res.groups(1).nSubjects, 4);
            tc.verifyEqual(res.groups(1).nFiles, 7, '4 subjects, 3 repeats');
            tc.verifyEqual(res.est(1).n, 4, 'n is the subject count');
        end

        function everyRecordingSurvivesInFilesEvenAfterTheCollapse(tc)
        % .files exists so an outlying recording can be seen in context; the
        % subject collapse must not be the only thing kept.
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 1, ...
                                                'repeats', 2);
            res = tc.curvesFor(cache, entries);
            tc.verifyNumElements(res.groups(1).files, 5);
            tc.verifyEqual(size(res.groups(1).curves, 1), 3, ...
                'curves are per SUBJECT');
        end

        function aRepeatedSubjectIsWeightedByItsTrialCount(tc)
        % Two sessions of one subject are not equal evidence if one held ten
        % trials and the other two hundred. A plain mean of the two averages
        % would treat them as if they were.
            [cache, entries] = fakeReducedCache('subjects', 1, 'sessions', 1, ...
                                                'repeats', 1, 'nTrials', [10 190]);
            heavy = tc.curvesFor(cache, entries);

            [cache2, entries2] = fakeReducedCache('subjects', 1, 'sessions', 1, ...
                                                  'repeats', 1, 'nTrials', [100 100]);
            even = tc.curvesFor(cache2, entries2);

            tc.verifyNotEqual(heavy.groups(1).curves, even.groups(1).curves, ...
                'the trial counts must change the subject average');
        end

        % ── what got excluded, and whether it was said ───────────────────────

        function aFileThatFailedToLoadIsExcludedRatherThanFatal(tc)
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 1, ...
                                                'repeats', 0, 'badFile', 2);
            res = tc.curvesFor(cache, entries);
            tc.verifyEqual(res.groups(1).nFiles, 2);
        end

        function aFileOnADifferentCapIsExcludedAndNAMED(tc)
        % Excluding it silently is the failure: the curve would then be over a
        % cohort the rail does not describe, with nothing on screen differing.
            [cache, entries] = fakeReducedCache('subjects', 4, 'sessions', 1, ...
                                                'repeats', 0, 'oddLabels', 3);
            res = tc.curvesFor(cache, entries);
            [~, base, ext] = fileparts(entries(3).path);
            tc.verifyEqual(res.info.montage.excluded, {[base ext]}, ...
                'the excluded file has to be identifiable');
        end

        function theModalMontageIsWhatMostFilesCarry(tc)
            [cache, entries] = fakeReducedCache('subjects', 4, 'sessions', 1, ...
                                                'repeats', 0, 'oddLabels', 3);
            res = tc.curvesFor(cache, entries);
            tc.verifyEqual(res.channelLabels, {'F3', 'FC1', 'C3', 'CP1', 'Pz'});
        end

        % ── the ROI actually used ────────────────────────────────────────────

        function theRoiRecordsWhatWasAskedForAndWhatWasFound(tc)
        % A partial ROI is averaged rather than refused, so it has to be
        % reported - otherwise the exported figure's footer names electrodes
        % that were never in the average.
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 1);
            res = groupCurves(cache, entries, struct( ...
                'roi', {{'F3', 'FC1', 'NOSUCH'}}, 'mode', 'TEP', ...
                'design', 'unpaired'));
            tc.verifyEqual(res.info.roi.requested, {'F3', 'FC1', 'NOSUCH'});
            tc.verifyEqual(res.info.roi.matched,   {'F3', 'FC1'});
            tc.verifyEqual(res.info.roi.missing,   {'NOSUCH'});
        end

        function anRoiMatchingNothingIsRefusedOutright(tc)
        % Averaging over no electrodes is not a weaker answer, it is no answer.
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 1);
            tc.verifyError(@() groupCurves(cache, entries, struct( ...
                'roi', {{'NOPE', 'ALSONOPE'}}, 'mode', 'TEP', ...
                'design', 'unpaired')), 'nestapp:emptyROI');
        end

        function theLevelUsedIsRecordedOnTheResult(tc)
        % Ledger C2: downstream readers must not restate 95. The status line
        % and the figure footer read this.
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 1);
            res = groupCurves(cache, entries, struct('roi', {{'F3'}}, ...
                'mode', 'TEP', 'design', 'unpaired', 'level', 0.90));
            tc.verifyEqual(res.info.level, 0.90);
        end

        % ── paired designs ───────────────────────────────────────────────────

        function pairedDropsSubjectsWithoutACompleteSetAndNamesThem(tc)
        % A paired interval over subjects present in only one group is not
        % paired at all.
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 2, ...
                                                'repeats', 0);
            entries(end).subject = 's99';   % one group loses s3, gains a stranger
            res = groupCurves(cache, entries, struct('roi', {{'F3'}}, ...
                'mode', 'TEP', 'design', 'paired'));
            tc.verifyNotEmpty(res.dropped);
            tc.verifyEqual(res.groups(1).nSubjects, res.groups(2).nSubjects, ...
                'a paired design must end with matched groups');
        end

        function unpairedKeepsEveryone(tc)
            [cache, entries] = fakeReducedCache('subjects', 3, 'sessions', 2, ...
                                                'repeats', 0);
            entries(end).subject = 's99';
            res = groupCurves(cache, entries, struct('roi', {{'F3'}}, ...
                'mode', 'TEP', 'design', 'unpaired'));
            tc.verifyEmpty(res.dropped);
        end

        % ── the shared time base ─────────────────────────────────────────────

        function filesAreCroppedOntoTheTimeTheyShare(tc)
            t = commonTimeBase({-50:2:300, -20:2:280}, {'a', 'b'});
            tc.verifyEqual(t(1), -20);
            tc.verifyEqual(t(end), 280);
        end

        function adifferentSampleRateIsAnErrorNotAnInterpolation(tc)
        % Quietly resampling would change the data behind the reader's back;
        % the honest answer is that these files cannot be compared as they are.
            tc.verifyError(@() commonTimeBase({0:2:100, 0:4:100}, {'a', 'b'}), ...
                           'nestapp:sampleRateMismatch');
        end
    end

    methods (Access = private)
        function res = curvesFor(~, cache, entries)
        % The default call. Named because several tests here differ only in the
        % cohort they hand it, and spelling the options struct out each time
        % would bury that difference.
        %
        % NOT called run(): matlab.unittest.TestCase inherits a public run(),
        % and a private override of it makes MATLAB refuse to load the class -
        % which the runner reported as an excluded file rather than a failure.
        % Worth knowing before naming any other helper after a framework verb.
            res = groupCurves(cache, entries, struct('roi', {{'F3', 'FC1'}}, ...
                'mode', 'TEP', 'design', 'unpaired'));
        end
    end
end
