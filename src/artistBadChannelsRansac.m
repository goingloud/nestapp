
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function EEG = artistBadChannelsRansac(EEG, opts)
% ARTISTBADCHANNELSRANSAC  RANSAC-based bad-channel rejection (ARTIST stage 2).
%   EEG = ARTISTBADCHANNELSRANSAC(EEG, opts) flags channels whose RANSAC
%   predictability falls below a correlation threshold and removes them via
%   pop_select.
%
%   When the montage carries 3-D channel coordinates, detection is delegated to
%   clean_rawdata's CLEAN_CHANNELS: it reconstructs each channel by
%   spherical-spline interpolation from a random subset of the OTHER channels
%   (true RANSAC) and rejects channels their neighbours predict poorly. Without
%   coordinates we fall back to a cruder proxy that predicts every channel from
%   the mean of a random subset; that proxy has no spatial model, so it
%   over-rejects peripheral/posterior channels and is only a last resort.
%
%   Reference:
%     Wu W. et al. (2018). ARTIST: A fully automated artifact rejection
%     algorithm for single-pulse TMS-EEG data. Hum Brain Mapp 39(4):1607.
%     doi:10.1002/hbm.23938. §2.2.1 (stage 2, RANSAC channel rejection).
%
%   Inputs:
%     EEG   - EEGLAB struct with channel locations and epoched data.
%     opts  - struct with fields:
%               corrThreshold       (default 0.8)  min correlation to the RANSAC
%                                                   reconstruction (clean_channels
%                                                   CorrelationThreshold).
%               ransacSubset        (default 0.25) subset fraction.
%               ransacIter          (default 50)   number of RANSAC samples.
%               ransacPercentile    (default 0.75) proxy fallback only.
%               ransacEpochFraction (default 0.40) proxy fallback only.
%
%   Output:
%     EEG with bad channels removed (names in EEG.etc.artistBadChannels).

    arguments
        EEG  struct
        opts.corrThreshold       (1,1) double = 0.8
        opts.freqThreshold       (1,1) double = 0.02
        opts.ransacSubset        (1,1) double = 0.25
        opts.ransacIter          (1,1) double = 50
        opts.ransacPercentile    (1,1) double = 0.75
        opts.ransacEpochFraction (1,1) double = 0.40
    end

    if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
        error('artistBadChannelsRansac:NoChanlocs', ...
            'Channel locations are required for RANSAC bad-channel detection.');
    end

    if size(EEG.data, 3) < 2
        warning('artistBadChannelsRansac:NotEpoched', ...
            'Data is not epoched; RANSAC rejection skipped.');
        return
    end

    nChan = size(EEG.data, 1);

    % Prefer true RANSAC (spherical-spline neighbour reconstruction) when the
    % montage carries 3-D coordinates; fall back to the proxy otherwise.
    if hasSphericalLocs(EEG) && ~isempty(which('clean_channels'))
        try
            badChannels = ransacViaCleanChannels(EEG, opts);
            method = 'clean_channels';
        catch ME
            warning('artistBadChannelsRansac:CleanChannelsFailed', ...
                'clean_channels failed (%s); using the subset-mean proxy.', ME.message);
            badChannels = ransacViaSubsetMean(EEG, opts);
            method = 'subset-mean proxy (clean_channels failed)';
        end
    else
        nestLog('ARTIST', ['RANSAC: no 3-D channel coordinates - using the ' ...
            'subset-mean proxy, which over-rejects peripheral channels.']);
        badChannels = ransacViaSubsetMean(EEG, opts);
        method = 'subset-mean proxy (no coordinates)';
    end

    if isempty(badChannels)
        nestLog('ARTIST', 'RANSAC bad-channel rejection (%s): no channels removed.', method);
        EEG.etc.artistBadChannels = {};
        return
    end

    badNames = {EEG.chanlocs(badChannels).labels};
    nestLog('ARTIST', 'RANSAC bad-channel rejection (%s): removing %d / %d channels (%s).', ...
        method, numel(badChannels), nChan, strjoin(badNames, ', '));

    EEG = pop_select(EEG, 'nochannel', badChannels);
    EEG.etc.artistBadChannels = badNames;
end

% ── local helpers ─────────────────────────────────────────────────────────────

function tf = hasSphericalLocs(EEG)
% True when chanlocs carry usable 3-D coordinates (required by clean_channels).
    cl = EEG.chanlocs;
    tf = all(isfield(cl, {'X', 'Y', 'Z'})) && ~all(cellfun(@isempty, {cl.X}));
end

function bad = ransacViaCleanChannels(EEG, opts)
% Decide which channels are bad with clean_rawdata's RANSAC. clean_channels
% expects continuous data, so we present a (channels x time*trials) view; it is
% used only to choose channels - the caller applies the removal to the epoched
% EEG. clean_channels reseeds the RNG internally, so the choice is reproducible.
    [nChan, nTime, nTrial] = size(EEG.data);
    sig        = EEG;
    sig.data   = reshape(EEG.data, nChan, nTime * nTrial);
    sig.pnts   = nTime * nTrial;
    sig.trials = 1;
    sig.xmax   = sig.xmin + (sig.pnts - 1) / sig.srate;
    sig.times  = (0:sig.pnts - 1) / sig.srate * 1000;

    % Positional signature: clean_channels(sig, CorrThresh, LineNoise, WinLen,
    % MaxBrokenTime, NumSamples, SubsetSize). [] keeps the clean_channels
    % default for the criteria we do not expose.
    clean = clean_channels(sig, opts.corrThreshold, [], [], [], ...
                           opts.ransacIter, opts.ransacSubset);

    keptLabels = {clean.chanlocs.labels};
    bad = find(~ismember({EEG.chanlocs.labels}, keptLabels));
end

function bad = ransacViaSubsetMean(EEG, opts)
% Fallback proxy, used only when 3-D coordinates are unavailable. Predicts every
% channel from the mean of a random subset (no spatial interpolation), so it
% systematically over-rejects peripheral/posterior channels - a last resort.
    [nChan, nTime, nTrial] = size(EEG.data);
    subsetSize   = max(2, round(opts.ransacSubset * nChan));
    nEpochsToUse = max(1, round(opts.ransacEpochFraction * nTrial));
    epochIdx     = randperm(nTrial, nEpochsToUse);
    X = reshape(EEG.data(:, :, epochIdx), nChan, nTime * nEpochsToUse);

    rng(42, 'twister');  % reproducibility per project CLAUDE.md.
    badCounts = zeros(nChan, 1);
    for iter = 1:opts.ransacIter
        subset  = randperm(nChan, subsetSize);
        predVec = mean(X(subset, :), 1)';
        for iChan = 1:nChan
            if ismember(iChan, subset)
                continue
            end
            if corr(X(iChan, :)', predVec) < opts.corrThreshold
                badCounts(iChan) = badCounts(iChan) + 1;
            end
        end
    end
    bad = find(badCounts / opts.ransacIter > opts.ransacPercentile);
end
