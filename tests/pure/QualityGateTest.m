% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef QualityGateTest < NestappTestCase
% QUALITYGATETEST  The thresholds that decide whether a file is usable.
%
%   The gate has exactly TWO rules - a minimum check and a maximum check -
%   applied to a battery of metrics. The old suite asserted them per metric,
%   which is how 423 lines came to express about a dozen facts: the min family
%   alone had four separate tests where one body already covered Fail,
%   Marginal and Pass together.
%
%   Here the two rules are one table each, and the metrics are rows. What stays
%   as its own test is anything that is NOT the generic rule: the rank
%   computation, and the fact that a marginal band only exists when a WarnAt is
%   given.
%
%   Ledger rows: B0 (rank always saw full rank on single-precision data - the
%   gate never fired) and B14 (the gate itself).

    properties (TestParameter)
        % The generic MINIMUM rule, over the metrics that use it.
        % {param, warnParam, metricValue -> expected verdict}
        minCase = struct( ...
            'belowThresholdFails',      struct('v',  40, 'want', 'Fail'), ...
            'insideTheWarnBandIsMarginal', struct('v', 55, 'want', 'Marginal'), ...
            'atTheWarnAtIsPass',        struct('v',  60, 'want', 'Pass'), ...
            'wellAboveIsPass',          struct('v', 100, 'want', 'Pass'), ...
            'exactlyAtThresholdIsNotAFail', struct('v', 50, 'want', 'Marginal'))

        % The generic MAXIMUM rule. Same shape, opposite direction.
        maxCase = struct( ...
            'aboveThresholdFails',      struct('v',  12, 'want', 'Fail'), ...
            'insideTheWarnBandIsMarginal', struct('v',  7, 'want', 'Marginal'), ...
            'atTheWarnAtIsPass',         struct('v',  5, 'want', 'Pass'), ...
            'wellBelowIsPass',           struct('v',  0, 'want', 'Pass'), ...
            'exactlyAtThresholdIsNotAPass', struct('v', 10, 'want', 'Marginal'))
    end

    methods (Test)

        % ── the two generic rules ────────────────────────────────────────────

        function theMinimumRuleGradesEveryMetricTheSameWay(tc, minCase)
        % minTriggers stands in for the whole min family. The rule is one
        % comparison; asserting it once per metric only re-tests the comparison.
            EEG  = fakeEeg('events', minCase.v);
            gate = qualityGate(EEG, struct('minTriggers', 50, ...
                                           'minTriggersWarnAt', 60));
            tc.verifyEqual(gate.verdict, minCase.want);
        end

        function theMaximumRuleGradesEveryMetricTheSameWay(tc, maxCase)
            EEG = fakeEeg('nbchan', 8);
            ctx = tc.contextWithRejected(maxCase.v);
            gate = qualityGate(EEG, struct('maxRejectedChanPct', 10, ...
                                           'maxRejectedChanPctWarnAt', 5), ctx);
            tc.verifyEqual(gate.verdict, maxCase.want);
        end

        function withNoWarnAtThereIsNoMarginalBandAtAll(tc)
        % The documented behaviour: a metric with no WarnAt goes straight from
        % Pass to Fail. Worth its own test because it is the ABSENCE of the
        % band, which no row of the tables above can express.
            EEG = fakeEeg('events', 55);
            gate = qualityGate(EEG, struct('minTriggers', 50));
            tc.verifyEqual(gate.verdict, 'Pass', ...
                'without a WarnAt, 55 over a minimum of 50 is simply a pass');
        end

        function aFailNamesTheMetricAndTheNumber(tc)
        % A verdict with no reason is not actionable - the whole gate exists to
        % tell someone which file to look at and why.
            EEG  = fakeEeg('events', 3);
            gate = qualityGate(EEG, struct('minTriggers', 50));
            tc.assertEqual(gate.verdict, 'Fail');
            tc.verifyNotEmpty(gate.reasons);
            tc.verifyTrue(contains(lower(strjoin(gate.reasons, ' ')), 'trigger'));
        end

        function aPassCarriesNoReasons(tc)
            gate = qualityGate(fakeEeg('events', 99), struct('minTriggers', 50));
            tc.verifyEmpty(gate.reasons);
        end

        function anUncheckedMetricCannotProduceAVerdict(tc)
        % Every threshold is opt-in. A gate configured with nothing must pass,
        % or enabling the feature would fail files on defaults nobody chose.
            gate = qualityGate(fakeEeg(), struct());
            tc.verifyEqual(gate.verdict, 'Pass');
            tc.verifyEmpty(gate.reasons);
        end

        % ── the rank computation, which is not a threshold rule ──────────────

        function rankIsComputedAtTheDataOwnPrecision(tc)
        % Ledger B0, and the one the audit MISSED - a user found it.
        % rank(double(single_data)) turns float32 quantisation noise into a
        % spurious extra dimension, so average-referenced data reported FULL
        % rank and the deficiency check never fired on any real file.
        %
        % Average referencing makes one channel a linear combination of the
        % others, so true rank is nbchan-1 and the ratio must be below 1.
            EEG = fakeEeg('nbchan', 8, 'pnts', 400);
            EEG.data = single(EEG.data - mean(EEG.data, 1));   % average reference

            gate = qualityGate(EEG, struct('minRankRatio', 0.99));
            tc.verifyLessThan(gate.metrics.rankRatio, 1, ...
                'avg-referenced data is rank deficient by construction');
            tc.verifyEqual(gate.verdict, 'Fail', ...
                'and the gate has to notice');
        end

        function fullRankDataPassesTheRankCheck(tc)
        % The positive control. Without it the test above passes for a gate
        % that fails everything.
            EEG  = fakeEeg('nbchan', 8, 'pnts', 400);
            gate = qualityGate(EEG, struct('minRankRatio', 0.99));
            tc.verifyEqual(gate.metrics.rankRatio, 1, 'AbsTol', 1e-12);
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function anEmptyDatasetReportsNaNRatherThanZero(tc)
        % Zero is a measurement; NaN is the absence of one.
            EEG = fakeEeg('nbchan', 8);
            EEG.data = [];
            gate = qualityGate(EEG, struct());
            tc.verifyTrue(isnan(gate.metrics.rankRatio));
        end

        % ── the metrics struct ───────────────────────────────────────────────

        function theCheapMetricsAreAlwaysMeasured(tc)
        % They cost nothing and a report is more useful with them than with a
        % bare verdict, so they are collected whether or not a threshold uses
        % them. Asserted once, on the values - not as five isfield checks,
        % which every other test in this file would already have errored on.
            EEG  = fakeEeg('nbchan', 6, 'pnts', 300, 'srate', 500, 'events', 4);
            gate = qualityGate(EEG, struct());
            tc.verifyEqual(gate.metrics.nbchan, 6);
            tc.verifyEqual(gate.metrics.srate, 500);
            tc.verifyEqual(gate.metrics.nTriggers, 4);
            tc.verifyEqual(gate.metrics.nTrials, 1);
        end
    end

    methods (Access = private)
        function ctx = contextWithRejected(~, pct)
        % A report context in which `pct` per cent of channels were rejected.
        % 100 channels makes the count and the percentage the same number,
        % which keeps the table rows above readable as percentages.
            ctx = struct('channels', struct('original', 100, 'nRejected', pct));
        end
    end
end
