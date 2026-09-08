% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef IntervalTest < NestappTestCase
% INTERVALTEST  The confidence interval drawn on every waveform in the app.
%
%   These numbers reach a published figure, so the invariants here are the
%   reason the suite exists at all. Ledger rows C2 (Window bars read a level
%   that agreed with the reported one only by coincidence) and the T1 interval
%   set.
%
%   Covers curveInterval, differenceInterval, intervalAtLevel and tCritical
%   together because they are one mechanism: the bounds are always
%   mean -/+ tCritical(df, alpha) .* sem, and everything that differs between
%   them lives in how sem is computed.

    properties (TestParameter)
        % One rule over many inputs, expressed once. The old suite wrote this
        % shape out by hand - 28 cases for one relationship in convertParam,
        % 8 for one rule in the window clamp.
        level = struct('at80', 0.80, 'at90', 0.90, 'at95', 0.95, 'at99', 0.99)
        design = struct('paired', 'paired', 'unpaired', 'unpaired')
    end

    methods (Test)

        % ── the property that makes the level a DRAW option ──────────────────

        function reDerivingAtALevelEqualsComputingAtIt(tc, level, design)
        % The load-bearing fact. If this were merely approximate, the level
        % could not be changed at draw time and would need a recompute; the app
        % relies on it being exact, and it was verified at 0 uV difference on
        % the real cohort.
        %
        % Parameterised over the design as well as the level, because the
        % paired case is the one that could plausibly break: the
        % Cousineau-Morey normalisation and Morey's sqrt(J/(J-1)) live inside
        % .sem, and if either depended on the level a paired band would be
        % subtly wrong at every level but 0.95 with nothing to say so.
        %
        % This was two methods differing only by a hardcoded 'unpaired' /
        % 'paired' - the same case count, twice the code, and the paired copy
        % had quietly stopped checking .hi.
            res    = fakeGroupResult('design', design);
            stored = intervalAtLevel(res.est, level);
            fresh  = curveInterval({res.groups.curves}, design, level);
            for g = 1:numel(fresh)
                tc.verifyEqual(stored(g).lo, fresh(g).lo, 'AbsTol', 1e-12);
                tc.verifyEqual(stored(g).hi, fresh(g).hi, 'AbsTol', 1e-12);
            end
        end

        % ── the label cannot disagree with the band ──────────────────────────

        function theNoteStatesTheLevelActuallyDrawn(tc)
        % A 90% band under a title reading 95% is the one failure here that
        % does real damage: both halves look right alone, and the figure
        % outlives the session that made it.
            res = fakeGroupResult('groups', 2, 'design', 'paired');
            tc.assertTrue(contains(res.contrast.note, '95% CI'));
            out = intervalAtLevel(res.contrast, 0.90);
            tc.verifyEqual(out.note, 'paired, 90% CI');
        end

        function relabellingKeepsWhateverTheSourceCalledTheDesign(tc, design)
        % Only the level is replaced. Rebuilding the whole string would make
        % intervalAtLevel a second place the design wording lived.
            res = fakeGroupResult('groups', 2, 'design', design);
            out = intervalAtLevel(res.contrast, 0.80);
            tc.verifyEqual(out.note, sprintf('%s, 80%% CI', design));
        end

        % ── degenerate and invalid input ─────────────────────────────────────

        function oneSubjectGivesNaNBoundsRatherThanZeroWidth(tc)
        % A zero-width band would read as perfect precision. NaN says "no
        % interval", which is the truth for n = 1.
            res = fakeGroupResult('groups', 1, 'subjects', 1);
            tc.verifyTrue(all(isnan(res.est.lo)));
            tc.verifyTrue(all(isnan(res.est.hi)));
        end

        function aDegenerateEstimateIsLeftAloneRatherThanInvented(tc)
            res = fakeGroupResult('groups', 1, 'subjects', 1);
            out = intervalAtLevel(res.est, 0.90);
            tc.verifyTrue(all(isnan(out.lo)));
            tc.verifyEqual(out.mean, res.est.mean);
        end

        function anImpossibleLevelIsAnErrorNotASilentBand(tc)
        % 0, 1, and 95 (someone typing per cent) have no interval. Drawing
        % something anyway would put a meaningless band on a figure.
            res = fakeGroupResult();
            for bad = [0 1 95 -0.5 Inf]
                tc.verifyError(@() intervalAtLevel(res.est, bad), ...
                               'nestapp:badLevel', sprintf('level %g', bad));
            end
        end

        function pairedRequiresMatchedRows(tc)
            tc.verifyError(@() curveInterval({randn(4, 20), randn(5, 20)}, 'paired'), ...
                           'nestapp:pairedGroupsUnequal');
        end

        % ── the relationships a reader relies on ─────────────────────────────

        function aHigherLevelGivesAWiderBand(tc)
            res = fakeGroupResult('design', 'unpaired');
            % One group indexed explicitly: res.est is a struct ARRAY, so
            % est.hi would be a comma-separated list and the subtraction would
            % receive two arguments rather than one.
            w = @(e) mean(e(1).hi - e(1).lo);
            tc.verifyLessThan(w(intervalAtLevel(res.est, 0.80)), ...
                              w(intervalAtLevel(res.est, 0.95)));
            tc.verifyLessThan(w(intervalAtLevel(res.est, 0.95)), ...
                              w(intervalAtLevel(res.est, 0.99)));
        end

        function pairingNarrowsTheBandWhenSubjectsDifferInOffset(tc)
        % What the Cousineau-Morey normalisation is for: between-subject
        % offset is removed, so the within-subject effect is visible.
            curves = {sin(linspace(0, pi, 60)) .* (1:5)'};
            wide   = curveInterval(curves, 'unpaired');
            narrow = curveInterval([curves, curves], 'paired');
            tc.verifyLessThan(mean(narrow(1).hi - narrow(1).lo), ...
                              mean(wide.hi - wide.lo));
        end

        % ── the toolbox-free t ───────────────────────────────────────────────

        function tCriticalMatchesTheStatisticsToolbox(tc)
        % tCritical exists so intervals need no Statistics Toolbox. That is
        % only worth anything if it agrees with tinv, so it is checked against
        % published values rather than against tinv itself - which would be a
        % tautology on a machine that has the toolbox, and unrunnable on one
        % that does not.
            expected = containers.Map( ...
                {1, 2, 5, 10, 30, 100}, ...
                {12.7062, 4.3027, 2.5706, 2.2281, 2.0423, 1.9840});
            for df = expected.keys()
                tc.verifyEqual(tCritical(df{1}, 0.05), expected(df{1}), ...
                               'AbsTol', 1e-4, sprintf('df = %d', df{1}));
            end
        end

        function theWindowFallsBackWhenThereIsNoEventToFind(tc)
        % inferTmsWindow with an eventless recording. Included here because it
        % is the pure half of the same "what interval are we describing"
        % question, and because a fixture with no consumer is a fixture that
        % drifts - see SuiteHygieneTest/theHelpersAreActuallyShared.
            EEG = fakeEeg('events', 0);
            tc.verifyEqual(inferTmsWindow(EEG, [0 25]), [0 25]);
        end

        function theWindowIsTakenFromTheFirstMatchingEvent(tc)
            EEG = fakeEeg('pnts', 1000, 'srate', 1000, 'xmin', 0, 'events', 3);
            win = inferTmsWindow(EEG, [0 25]);
            tc.verifyNotEqual(win, [0 25]);
            tc.verifyEqual(win(2) - win(1), 25, 'AbsTol', 1e-9, ...
                'the default 25 ms decay must survive the inference');
        end

        function tCriticalIsInfiniteWhereThereIsNoSpreadToEstimate(tc)
        % df < 1 means one observation. Inf makes "no interval" visible rather
        % than implying a precision that does not exist.
            tc.verifyEqual(tCritical(0, 0.05), Inf);
        end
    end
end
