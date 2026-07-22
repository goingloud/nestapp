
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_qualityGate < matlab.unittest.TestCase
% TEST_QUALITYGATE  Unit tests for src/qa/qualityGate.m

    methods (TestClassSetup)
        function addSrcPath(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(genpath(fullfile(root, 'src')));
            tc.addTeardown(@() rmpath(genpath(fullfile(root, 'src'))));
        end
    end

    methods (Static, Access = private)
        function EEG = makeEEG(nbchan, nTrials, nPnts, srate)
            EEG.data   = randn(nbchan, nPnts, nTrials);
            EEG.times  = (0:nPnts-1) / srate * 1000 - 200;
            EEG.srate  = srate;
            EEG.nbchan = nbchan;
            EEG.trials = nTrials;
            EEG.pnts   = nPnts;
            EEG.event  = struct('type', {}, 'latency', {});
        end

        function EEG = withEvents(EEG, n)
            for k = 1:n
                EEG.event(k).type    = 'TMS';
                EEG.event(k).latency = k * 100;
            end
        end

        function EEG = epochedWithGmfaPeak()
            % Epoched data with a deterministic cross-channel deflection at
            % 100 ms (inside the default [20 300] window). The trial-mean GMFA
            % (std across channels) peaks there at a known, large value, well
            % above the small residual noise elsewhere.
            EEG = test_qualityGate.makeEEG(8, 20, 500, 1000);   % times: -200..299 ms
            EEG.data = single(0.1 * EEG.data);                  % small baseline noise
            tIdx = find(EEG.times >= 100, 1);                   % ~100 ms
            offset = (0:7)' * 10;                               % std ~24.5 uV across chans
            EEG.data(:, tIdx, :) = EEG.data(:, tIdx, :) + offset;
        end
    end

    methods (Test)
        % -- disabled / default behavior ---------------------------------

        function disabled_gate_passes(tc)
            EEG = test_qualityGate.makeEEG(16, 40, 500, 1000);
            gate = qualityGate(EEG, struct());
            tc.verifyEqual(gate.verdict, 'Pass');
            tc.verifyEmpty(gate.reasons);
        end

        function records_label_and_thresholds(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            params = struct('gateLabel', 'after-load', 'expectedChans', 8);
            gate = qualityGate(EEG, params);
            tc.verifyEqual(gate.label, 'after-load');
            tc.verifyEqual(gate.thresholds.expectedChans, 8);
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        % -- exact-match checks ------------------------------------------

        function expectedChans_mismatch_fails(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            gate = qualityGate(EEG, struct('expectedChans', 64));
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, 'nbchan')));
        end

        function expectedSrate_mismatch_fails(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            gate = qualityGate(EEG, struct('expectedSrate', 500));
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, 'srate')));
        end

        % -- min/max thresholds + marginal slack -------------------------

        function minTriggers_fail_below_slack(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 50);   % below 0.8 * 100 = 80
            gate = qualityGate(EEG, struct('minTriggers', 100));
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        function minTriggers_marginal_above_threshold_with_warnAt(tc)
            % WarnAt sits above threshold for min checks. With
            % minTriggers = 100, minTriggersWarnAt = 120, a value of 110
            % is in the marginal band [100, 120).
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 110);
            gate = qualityGate(EEG, struct( ...
                'minTriggers',       100, ...
                'minTriggersWarnAt', 120));
            tc.verifyEqual(gate.verdict, 'Marginal');
        end

        function minTriggers_pass_at_or_above(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 150);
            gate = qualityGate(EEG, struct('minTriggers', 100));
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function maxTriggers_fails_on_over_detection(tc)
            % Too MANY triggers (pulse over-detection) must Fail the gate.
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 500);   % > 300 ceiling
            gate = qualityGate(EEG, struct('maxTriggers', 300));
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, 'triggers')));
        end

        function maxTriggers_pass_within_bound(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 120);   % normal protocol
            gate = qualityGate(EEG, struct('maxTriggers', 300));
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function maxTrials_fails_on_over_segmentation(tc)
            % An inflated epoch count must Fail the maxTrials check.
            EEG = test_qualityGate.makeEEG(8, 400, 500, 1000);   % 400 trials
            gate = qualityGate(EEG, struct('maxTrials', 300));
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, 'trials')));
        end

        function maxFlatChans_counts_zero_var_channels(tc)
            EEG = test_qualityGate.makeEEG(8, 30, 500, 1000);
            EEG.data(3, :, :) = 0;
            EEG.data(7, :, :) = 0;
            gate = qualityGate(EEG, struct('maxFlatChans', 1));
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyEqual(gate.metrics.nFlatChans, 2);
        end

        function maxSatChans_counts_saturated_channels(tc)
            EEG = test_qualityGate.makeEEG(8, 30, 500, 1000);
            EEG.data(1, :, :) = 500;  % > 250 uV
            EEG.data(2, :, :) = 500;  % 2 saturated channels
            % value 2 <= threshold 5, no WarnAt -> Pass.
            gate = qualityGate(EEG, struct('maxSatChans', 5));
            tc.verifyEqual(gate.metrics.nSatChans, 2);
            tc.verifyEqual(gate.verdict, 'Pass');
            % value 2 > threshold 1 -> Fail (a hard cutoff, no slack band).
            gate = qualityGate(EEG, struct('maxSatChans', 1));
            tc.verifyEqual(gate.verdict, 'Fail');
            % With a WarnAt below the threshold, the same value is Marginal.
            gate = qualityGate(EEG, struct('maxSatChans', 5, 'maxSatChansWarnAt', 1));
            tc.verifyEqual(gate.verdict, 'Marginal');
        end

        function minRankRatio_catches_rank_deficient_data(tc)
            EEG = test_qualityGate.makeEEG(8, 1, 500, 1000);
            % Force rank deficiency: make 4 channels identical.
            EEG.data(2, :) = EEG.data(1, :);
            EEG.data(3, :) = EEG.data(1, :);
            EEG.data(4, :) = EEG.data(1, :);
            gate = qualityGate(EEG, struct('minRankRatio', 0.9));
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        function rank_deficiency_is_seen_in_single_precision_data(tc)
            % Real pipeline data is single precision by the time a gate runs,
            % and average-referencing forces an exact rank drop of one. The
            % rank ratio must reflect that. Regression: computing
            % rank(double(data)) upcast float32 quantization noise into a
            % spurious extra dimension, so every single-precision dataset
            % reported full rank (ratio 1.0) no matter its true state.
            EEG = test_qualityGate.makeEEG(16, 1, 4000, 1000);
            EEG.data = single(EEG.data - mean(EEG.data, 1));   % exact rank 15
            gate = qualityGate(EEG, struct());
            tc.verifyLessThan(gate.metrics.rankRatio, 1, ...
                'average-referenced data cannot be full rank');
            tc.verifyEqual(gate.metrics.rankRatio, 15/16, 'AbsTol', 1e-6);
        end

        function single_precision_rank_deficiency_fails_the_gate(tc)
            % The end-to-end consequence: a gate that should catch this must.
            EEG = test_qualityGate.makeEEG(16, 1, 4000, 1000);
            EEG.data = single(EEG.data - mean(EEG.data, 1));
            gate = qualityGate(EEG, struct('minRankRatio', 0.99));
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        function gmfa_peak_check_is_reachable_from_the_registry(tc)
            % The check is fully wired in qualityGate.m but was declared in the
            % registry NOWHERE, so the GUI could never enable it. Confirm the
            % three params (threshold, window, warn) are now declared.
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(genpath(fullfile(root, 'src')));
            reg = stepRegistry();
            k = find(strcmp({reg.name}, 'Quality Gate'), 1);
            keys = {reg(k).params.key};
            for want = {'maxGmfaPeak', 'gmfaWindowMs', 'maxGmfaPeakWarnAt'}
                tc.verifyTrue(ismember(want{1}, keys), sprintf( ...
                    '%s must be a declared Quality Gate param', want{1}));
                tc.verifyTrue(isfield(reg(k).defaults, want{1}), sprintf( ...
                    '%s must have a default so a fresh step carries it', want{1}));
            end
        end

        function gmfa_peak_over_threshold_fails(tc)
            % An elevated grand-average TEP must trip the gate - this is the
            % blown-GMFA failure mode the check exists for.
            EEG = test_qualityGate.epochedWithGmfaPeak();
            % Read the metric the gate computes, then bracket it.
            peak = qualityGate(EEG, struct('maxGmfaPeak', 1)).metrics.gmfaPeakUv;
            tc.assertGreaterThan(peak, 5, 'fixture must have a clear GMFA peak');
            gate = qualityGate(EEG, struct('maxGmfaPeak', peak / 2));
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, 'GMFA')));
        end

        function gmfa_peak_under_threshold_passes(tc)
            EEG = test_qualityGate.epochedWithGmfaPeak();
            peak = qualityGate(EEG, struct('maxGmfaPeak', 1)).metrics.gmfaPeakUv;
            gate = qualityGate(EEG, struct('maxGmfaPeak', peak * 2));
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function minTrials_catches_low_trial_count(tc)
            EEG = test_qualityGate.makeEEG(8, 5, 500, 1000);
            gate = qualityGate(EEG, struct('minTrials', 30));
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        % -- worst-of logic ----------------------------------------------

        function fail_dominates_marginal(tc)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 85);   % marginal for minTriggers=100
            gate = qualityGate(EEG, struct( ...
                'minTriggers', 100, ...
                'expectedChans', 64));   % fail (8 != 64)
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyGreaterThanOrEqual(numel(gate.reasons), 2);
        end

        % -- ICA-based checks --------------------------------------------

        function emgFraction_uses_attached_TESA_classifier(tc)
            EEG = test_qualityGate.makeEEG(16, 1, 2000, 1000);
            EEG.icaweights = eye(4, 16);
            EEG.icasphere  = eye(16);
            EEG.icawinv    = randn(16, 4);
            EEG.icachansind = 1:16;
            EEG.icaCompClass.TESA1.compClass = [1 3 3 1];   % 2 of 4 are TMS Muscle
            EEG.icaCompClass.TESA1.compVars  = ones(1, 4);
            gate = qualityGate(EEG, struct('maxEMGFraction', 0.3));
            tc.verifyEqual(gate.metrics.emgFraction, 0.5);
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        function electrodeCount_uses_ICLabel(tc)
            EEG = test_qualityGate.makeEEG(16, 1, 2000, 1000);
            EEG.icaweights = eye(5, 16);
            EEG.icasphere  = eye(16);
            EEG.icawinv    = randn(16, 5);
            EEG.icachansind = 1:16;
            % 3 of 5 components classified as Channel Noise (electrode artifact)
            probs = zeros(5, 7);
            probs(1, 1) = 1;   % Brain
            probs(2, 6) = 1;   % Channel Noise
            probs(3, 6) = 1;
            probs(4, 6) = 1;
            probs(5, 1) = 1;
            EEG.etc.ic_classification.ICLabel.classifications = probs;
            gate = qualityGate(EEG, struct('maxElectrodeCount', 2));
            tc.verifyEqual(gate.metrics.electrodeCount, 3);
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        % -- gate.metrics shape ------------------------------------------

        % -- WarnAt overrides (Phase 4) ----------------------------------

        function maxWarnAt_defines_the_marginal_band(tc)
            % maxFlatChans = 10 (Fail above), WarnAt = 3 (Marginal above):
            % 5 flat channels is > 3 and <= 10, so Marginal.
            EEG = test_qualityGate.makeEEG(8, 30, 500, 1000);
            for k = 1:5
                EEG.data(k, :, :) = 0;   % 5 flat channels
            end
            gate = qualityGate(EEG, struct( ...
                'maxFlatChans',       10, ...
                'maxFlatChansWarnAt', 3));
            tc.verifyEqual(gate.metrics.nFlatChans, 5);
            tc.verifyEqual(gate.verdict, 'Marginal');
        end

        function no_warnAt_means_no_marginal_band(tc)
            % Without a WarnAt, a max metric goes straight Pass -> Fail:
            % 5 flat channels under a threshold of 10 is a clean Pass (there
            % is no slack-derived Marginal band any more).
            EEG = test_qualityGate.makeEEG(8, 30, 500, 1000);
            for k = 1:5
                EEG.data(k, :, :) = 0;
            end
            gate = qualityGate(EEG, struct('maxFlatChans', 10));
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function minWarnAt_defines_marginal_upper_bound(tc)
            % WarnAt is the upper edge of the marginal band for a min
            % check: anything below threshold fails, anything between
            % threshold and WarnAt is Marginal, anything at or above
            % WarnAt passes.
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);

            % 40 < threshold(50) -> Fail
            EEG = test_qualityGate.withEvents(EEG, 40);
            gate = qualityGate(EEG, struct( ...
                'minTriggers',       50, ...
                'minTriggersWarnAt', 100));
            tc.verifyEqual(gate.verdict, 'Fail');

            % 70 in [50, 100) -> Marginal
            EEG.event = struct('type', {}, 'latency', {});
            EEG = test_qualityGate.withEvents(EEG, 70);
            gate = qualityGate(EEG, struct( ...
                'minTriggers',       50, ...
                'minTriggersWarnAt', 100));
            tc.verifyEqual(gate.verdict, 'Marginal');

            % 120 >= warnAt(100) -> Pass
            EEG.event = struct('type', {}, 'latency', {});
            EEG = test_qualityGate.withEvents(EEG, 120);
            gate = qualityGate(EEG, struct( ...
                'minTriggers',       50, ...
                'minTriggersWarnAt', 100));
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function minWarnAt_zero_means_no_marginal_band(tc)
            % Without an explicit WarnAt, min checks have no marginal
            % band: anything below threshold fails, anything else passes.
            % (Min metrics like rankRatio cap at 1.0, so a slack-derived
            % upper cutoff would falsely mark perfect data as Marginal.)
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            EEG = test_qualityGate.withEvents(EEG, 99);
            gate = qualityGate(EEG, struct( ...
                'minTriggers',   100));
            tc.verifyEqual(gate.verdict, 'Fail');
        end

        % -- rejected-pct metrics (Phase 5) ------------------------------

        function maxRejectedChanPct_fails_above_threshold(tc)
            % maxRejectedChanPct reads the running rejection tally from the
            % context (channels removed so far / original count).
            EEG = test_qualityGate.makeEEG(55, 10, 500, 1000); % 55 left now
            ctx = struct( ...
                'channels', struct('original', 63, 'nRejected', 8), ...
                'trials',   struct('original', 0,  'rejected',  0));
            gate = qualityGate(EEG, struct('maxRejectedChanPct', 10), ctx);
            % 8/63 = 12.7% > 10 -> Fail.
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, '% rejected channels')));
        end

        function maxRejectedTrialPct_fails_above_threshold(tc)
            EEG = test_qualityGate.makeEEG(8, 59, 500, 1000);
            ctx = struct( ...
                'channels', struct('original', 8,  'nRejected', 0), ...
                'trials',   struct('original', 80, 'rejected', 21));
            gate = qualityGate(EEG, struct('maxRejectedTrialPct', 15), ctx);
            % 21/80 = 26.25% > 15 -> Fail.
            tc.verifyEqual(gate.verdict, 'Fail');
            tc.verifyTrue(any(contains(gate.reasons, '% rejected trials')));
        end

        function maxRejectedChanPct_warnAt_yields_marginal(tc)
            % 8/63 = 12.7%. Threshold 15 (Fail above), WarnAt 10 (Marginal
            % above) -> Marginal.
            EEG = test_qualityGate.makeEEG(55, 10, 500, 1000);
            ctx = struct( ...
                'channels', struct('original', 63, 'nRejected', 8), ...
                'trials',   struct('original', 0,  'rejected',  0));
            gate = qualityGate(EEG, struct( ...
                'maxRejectedChanPct',       15, ...
                'maxRejectedChanPctWarnAt', 10), ctx);
            tc.verifyEqual(gate.verdict, 'Marginal');
        end

        function maxRejected_passes_when_under_threshold(tc)
            EEG = test_qualityGate.makeEEG(60, 10, 500, 1000);
            ctx = struct( ...
                'channels', struct('original', 63, 'nRejected', 3), ...
                'trials',   struct('original', 80, 'rejected',  4));
            gate = qualityGate(EEG, struct( ...
                'maxRejectedChanPct',  10, ...
                'maxRejectedTrialPct', 15), ctx);
            % 3/63 = 4.8%, 4/80 = 5% - both under their thresholds.
            tc.verifyEqual(gate.verdict, 'Pass');
        end

        function maxRejected_NaN_when_context_missing(tc)
            % No context -> metric is NaN -> check skipped (Pass). This
            % silent-skip is the deliberately-kept behaviour.
            EEG = test_qualityGate.makeEEG(8, 10, 500, 1000);
            gate = qualityGate(EEG, struct('maxRejectedChanPct', 10));
            tc.verifyEqual(gate.verdict, 'Pass');
            tc.verifyTrue(isnan(gate.metrics.rejectedChanPct));
        end

        function metrics_always_has_cheap_fields(tc)
            EEG = test_qualityGate.makeEEG(8, 5, 500, 1000);
            gate = qualityGate(EEG, struct());
            tc.verifyTrue(isfield(gate.metrics, 'nbchan'));
            tc.verifyTrue(isfield(gate.metrics, 'srate'));
            tc.verifyTrue(isfield(gate.metrics, 'nTriggers'));
            tc.verifyTrue(isfield(gate.metrics, 'nTrials'));
            tc.verifyTrue(isfield(gate.metrics, 'rankRatio'));
        end
    end
end
