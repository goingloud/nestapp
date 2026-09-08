% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef WindowMeasureTest < NestappTestCase
% WINDOWMEASURETEST  The numbers in the measures table and on the bars.
%
%   computeWindowMeasures -> tepWindowTable -> exploreMeasures is a delegation
%   chain: each layer calls the one below and adds shaping. The old suite had
%   FOUR tests down this chain that each computed their expected value by
%   calling the very function the source delegates to - which cannot fail, and
%   so said nothing. Two of them additionally transcribed curveInterval's own
%   arithmetic line for line and asserted mean +/- t*sem == mean +/- t*sem.
%
%   Here the innermost layer is checked against numbers worked out by hand, and
%   the outer layers are checked for the one thing delegation can actually get
%   wrong: agreeing with each other. That is one assertion per layer instead of
%   one tautology per layer.

    properties (Constant)
        % A triangle peaking at +4 at t = 100, on a 1 ms grid from 0 to 200.
        % Chosen so every measure below is arithmetic anyone can check: the
        % window 90..110 spans 21 samples rising 3.0 -> 4.0 -> 3.0.
        Time  = 0:200
    end

    properties (TestParameter)
        % One rule, four polarities. 'auto' takes the largest ABSOLUTE
        % deflection, which is what makes it different from 'pos' on a curve
        % whose trough is deeper than its peak.
        polarityCase = struct( ...
            'autoTakesTheDeeperTrough', struct('pol', 'auto', 'amp', -13), ...
            'posIgnoresTheTrough',      struct('pol', 'pos',  'amp',   4), ...
            'negTakesTheTrough',        struct('pol', 'neg',  'amp', -13))
    end

    methods (Test)

        % ── the innermost layer, against hand-computed numbers ───────────────

        function theMeanIsTheAverageOverTheClosedWindow(tc)
            m = computeWindowMeasures(tc.triangle(), tc.Time, 95, 105, 'auto');
            % 11 samples, symmetric about the apex: 3.5 3.6 ... 4.0 ... 3.6 3.5
            expected = mean(4 - abs((95:105) - 100) * 0.1);
            tc.verifyEqual(m.mean, expected, 'AbsTol', 1e-12);
        end

        function thePeakIsTheApexAndItsLatencyIsWhereItSits(tc)
            m = computeWindowMeasures(tc.triangle(), tc.Time, 90, 110, 'auto');
            tc.verifyEqual(m.peakAmp, 4, 'AbsTol', 1e-12);
            tc.verifyEqual(m.peakLatency, 100);
            tc.verifyTrue(m.found);
        end

        function theWindowIsClosedAtBothEnds(tc)
        % [t1 t2] includes t1 and t2. An off-by-one here shifts every mean in
        % the measures table by one sample and nothing on screen shows it.
            narrow = computeWindowMeasures(tc.triangle(), tc.Time, 100, 100, 'auto');
            tc.verifyTrue(narrow.found);
            tc.verifyEqual(narrow.mean, 4, 'AbsTol', 1e-12, ...
                'a single-sample window is the sample itself');
        end

        function theWindowIsOrderIndependent(tc)
            fwd = computeWindowMeasures(tc.triangle(), tc.Time, 90, 110, 'auto');
            rev = computeWindowMeasures(tc.triangle(), tc.Time, 110, 90, 'auto');
            tc.verifyEqual(rev.mean, fwd.mean);
        end

        function anEmptyWindowReportsNotFoundRatherThanZero(tc)
        % Zero is a measurement; NaN is the absence of one. A window off the
        % end of the epoch has no samples, and reporting 0 would put a real
        % number in the table for data that does not exist.
            m = computeWindowMeasures(tc.triangle(), tc.Time, 900, 950, 'auto');
            tc.verifyFalse(m.found);
            tc.verifyTrue(isnan(m.mean));
        end

        function thePolaritySelectsWhichExtremumCounts(tc, polarityCase)
        % A curve with a +4 peak and a -13 trough inside one window: the
        % triangle has already fallen to its 0 floor by t = 150, so the notch
        % bottoms out at -13 rather than at 4 - 13.
            curve = tc.triangle() - 13 * (abs(tc.Time - 150) < 5);
            m = computeWindowMeasures(curve, tc.Time, 90, 160, polarityCase.pol);
            tc.verifyEqual(m.peakAmp, polarityCase.amp, 'AbsTol', 1e-9);
        end

        function polarityDefaultsToAutoWhenAWindowDoesNotSayOtherwise(tc)
        % User-created windows have no polarity field at all until one is set.
            tc.verifyEqual(windowPolarity(struct('name', 'w')), 'auto');
            tc.verifyEqual(windowPolarity(struct('polarity', '')), 'auto');
            tc.verifyEqual(windowPolarity(struct('polarity', 'neg')), 'neg');
        end

        % ── the layers above, checked for the one thing they can get wrong ───

        function theTableAgreesWithTheMeasureItDelegatesTo(tc)
        % Not a tautology: the table reshapes, names and orders things, and any
        % of that could drop or misalign a value. What it must not do is report
        % a DIFFERENT number from the function it calls. One assertion, at the
        % seam, instead of one per layer computing itself.
            curves = [tc.triangle(); tc.triangle() * 2];   % one ROW per file
            w = struct('name', 'N100', 'winStart', 90, 'winEnd', 110);
            T = tepWindowTable({'a', 'b'}, curves, tc.Time, w, 'TEP');

            direct = computeWindowMeasures(curves(2, :), tc.Time, 90, 110, 'auto');
            row    = T(strcmp(T.file, 'b'), :);
            tc.verifyEqual(row.mean_uV, direct.mean,    'AbsTol', 1e-12);
            tc.verifyEqual(row.peak_uV, direct.peakAmp, 'AbsTol', 1e-12);
            tc.verifyEqual(row.peak_ms, direct.peakLatency);
        end

        function everyFileAndWindowGetsARow(tc)
            w = [struct('name', 'A', 'winStart', 10, 'winEnd', 40), ...
                 struct('name', 'B', 'winStart', 90, 'winEnd', 110)];
            T = tepWindowTable({'a', 'b', 'c'}, ...
                               repmat(tc.triangle(), 3, 1), tc.Time, w, 'TEP');
            tc.verifyEqual(height(T), 6, '3 files x 2 windows');
        end

        function theMeasuresAreTakenPerSubjectNotOnTheGroupMean(tc)
        % The invariant the quantification view exists for. Three subjects
        % peaking at 90, 100 and 110 ms each reach 4; their MEAN curve is
        % flattened by the latency jitter and peaks lower. Measuring the
        % average would understate every peak in the cohort, systematically.
            jitter = [90 100 110];
            perSubject = zeros(1, 3);
            for k = 1:3
                c = 4 - abs(tc.Time - jitter(k)) * 0.1;
                c(c < 0) = 0;
                perSubject(k) = computeWindowMeasures(c, tc.Time, 80, 120, 'auto').peakAmp;
            end
            meanCurve = mean(cell2mat(arrayfun(@(j) ...
                max(4 - abs(tc.Time - j) * 0.1, 0), jitter', ...
                'UniformOutput', false)), 1);
            onAverage = computeWindowMeasures(meanCurve, tc.Time, 80, 120, 'auto').peakAmp;

            tc.verifyEqual(mean(perSubject), 4, 'AbsTol', 1e-12);
            tc.verifyLessThan(onAverage, mean(perSubject), ...
                'the flattening is the whole reason measures are per subject');
        end
    end

    methods (Access = private)
        function c = triangle(tc)
        % Peaks at +4 at t = 100, falling 0.1 per ms, floored at 0.
            c = max(4 - abs(tc.Time - 100) * 0.1, 0);
        end
    end
end
