
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function EEG = aaratepPeakAmplitudeClassifier(EEG, opts)
% AARATEPPEAKAMPLITUDECLASSIFIER  Flag ICs whose trial-averaged peak exceeds a µV threshold.
%   EEG = AARATEPPEAKAMPLITUDECLASSIFIER(EEG, opts) implements the AARATEP 2021
%   paper's final component check: "components with peak amplitude exceeding
%   15 µV were removed". For each IC it back-projects the trial-averaged
%   activation to the scalp (EEG.icawinv(:,c) * mean activation) and flags the
%   component when the peak |amplitude| over channels and time exceeds
%   peakThresholdUv. Flagged ICs are written to EEG.reject.gcompreject so the
%   existing "Remove Flagged ICA Components" step can remove them.
%
%   NOTE: this check is in Cline et al. 2021 but NOT in the maintained v2.1.1
%   AARATEPPipeline code. It is included per an explicit request to follow the
%   paper for this step (a paper-over-code fidelity choice; see
%   THIRD_PARTY_NOTICES.md). The µV scale assumes the data is in microvolts.
%
%   Reference:
%     Cline C.C. et al. (2021). Advanced Artifact Removal for Automated
%     TMS-EEG Data Processing. IEEE NER. doi:10.1109/NER49283.2021.9441147.
%
%   Inputs:
%     EEG  - EEGLAB struct with ICA decomposition (icaweights / icawinv set).
%     opts - struct with field:
%              peakThresholdUv  (default 15)  µV threshold on the back-projected peak
%
%   Output:
%     EEG with EEG.reject.gcompreject updated.

    arguments
        EEG  struct
        opts.peakThresholdUv (1,1) double = 15
    end

    if ~isfield(EEG, 'icaweights') || isempty(EEG.icaweights)
        error('aaratepPeakAmplitudeClassifier:NoICA', ...
            'ICA must be run before peak-amplitude classification.');
    end

    icaact   = eeg_getica(EEG);          % nComp x nTime x nTrial
    actAvg   = mean(icaact, 3);          % nComp x nTime (trial-averaged activations)
    numComps = size(EEG.icaweights, 1);

    % Peak |amplitude| (µV) of each IC's back-projection onto the scalp, on the
    % trial-averaged data (consistent with how the TEP/muscle check are scored).
    peakUv = nan(numComps, 1);
    for iC = 1:numComps
        proj       = EEG.icawinv(:, iC) * actAvg(iC, :);   % nChan x nTime, µV
        peakUv(iC) = max(abs(proj(:)));
    end

    toReject = peakUv > opts.peakThresholdUv;

    if ~isfield(EEG, 'reject') || ~isfield(EEG.reject, 'gcompreject') || ...
            numel(EEG.reject.gcompreject) ~= numComps
        EEG.reject.gcompreject = false(1, numComps);
    end
    EEG.reject.gcompreject = EEG.reject.gcompreject(:)' | toReject(:)';
    EEG = markICClass(EEG, toReject, 'HighAmp');   % category for the run report

    nestLog('AARATEP', 'Peak-amplitude check: %d / %d ICs flagged (trial-avg back-projected peak > %g µV).', ...
        sum(toReject), numComps, opts.peakThresholdUv);
end
