
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_aggregateMetricDistributions < matlab.unittest.TestCase
% TEST_AGGREGATEMETRICDISTRIBUTIONS  Unit tests for src/qa/aggregateMetricDistributions.m

    methods (TestClassSetup)
        function addSrcPath(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(genpath(fullfile(root, 'src')));
            tc.addTeardown(@() rmpath(genpath(fullfile(root, 'src'))));
        end
    end

    methods (Static, Access = private)
        function r = reportWithGates(gates)
            r = struct( ...
                'inputFile',   'fake.set', ...
                'processedAt', datetime('now'), ...
                'quality',     struct('figures', {{}}, ...
                                      'gates', {gates}, ...
                                      'worstVerdict', 'Pass'));
        end

        function g = gate(thresholds, metrics)
            g = struct( ...
                'label',      'g', ...
                'verdict',    'Pass', ...
                'reasons',    {{}}, ...
                'metrics',    metrics, ...
                'thresholds', thresholds, ...
                'stepIndex',  1);
        end
    end

    methods (Test)
        function disabled_metrics_absent_from_output(tc)
            mk = @test_aggregateMetricDistributions.reportWithGates;
            mg = @test_aggregateMetricDistributions.gate;
            % All thresholds disabled (= 0) -> nothing to plot.
            r = mk({mg(struct('maxFlatChans', 0), struct('nFlatChans', 3))});
            d = aggregateMetricDistributions({r});
            tc.verifyEmpty(d);
        end

        function single_enabled_metric_appears_once(tc)
            mk = @test_aggregateMetricDistributions.reportWithGates;
            mg = @test_aggregateMetricDistributions.gate;
            r = mk({mg(struct('maxFlatChans', 5), struct('nFlatChans', 2))});
            d = aggregateMetricDistributions({r});
            tc.verifyLength(d, 1);
            tc.verifyEqual(d(1).name, 'nFlatChans');
            tc.verifyEqual(d(1).values, 2);
            tc.verifyEqual(d(1).absThresholds, 5);
        end

        function values_accumulate_across_files(tc)
            mk = @test_aggregateMetricDistributions.reportWithGates;
            mg = @test_aggregateMetricDistributions.gate;
            r1 = mk({mg(struct('maxFlatChans', 5), struct('nFlatChans', 2))});
            r2 = mk({mg(struct('maxFlatChans', 5), struct('nFlatChans', 4))});
            d = aggregateMetricDistributions({r1, r2});
            tc.verifyLength(d, 1);
            tc.verifyEqual(sort(d.values), [2 4]);
            tc.verifyEqual(sort(d.absThresholds), [5 5]);
        end

        function NaN_metric_values_omitted(tc)
            mk = @test_aggregateMetricDistributions.reportWithGates;
            mg = @test_aggregateMetricDistributions.gate;
            r1 = mk({mg(struct('maxEMGFraction', 0.3), struct('emgFraction', NaN))});
            r2 = mk({mg(struct('maxEMGFraction', 0.3), struct('emgFraction', 0.15))});
            d = aggregateMetricDistributions({r1, r2});
            tc.verifyLength(d, 1);
            tc.verifyEqual(d.values, 0.15);   % only the non-NaN entry
        end

        function min_style_metric_picked_up_via_minTriggers(tc)
            mk = @test_aggregateMetricDistributions.reportWithGates;
            mg = @test_aggregateMetricDistributions.gate;
            r = mk({mg(struct('minTriggers', 100), struct('nTriggers', 85))});
            d = aggregateMetricDistributions({r});
            tc.verifyEqual(d.name, 'nTriggers');
            tc.verifyEqual(d.values, 85);
            tc.verifyEqual(d.absThresholds, 100);
        end
    end
end
