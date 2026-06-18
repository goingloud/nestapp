
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function curve = tepFieldCurve(data, roiIdx, plotType)
% TEPFIELDCURVE  Per-file Visualizing-tab curve: TEP, GMFP or LMFP.
%   curve = TEPFIELDCURVE(data, roiIdx, plotType) reduces an epoched EEG data
%   array (channels x time x trials) to a single time series, after averaging
%   across trials:
%     'TEP'  - mean amplitude across the ROI electrodes (signed waveform).
%     'GMFP' - global mean field power: the standard deviation across ALL
%              electrodes at each timepoint.
%     'LMFP' - local mean field power: the same measure restricted to the ROI.
%
%   GMFP is identical to TESA's GMFA. We deliberately mirror TESA's exact
%   definition rather than maintain a separate derivation:
%       tesa_tepextract.m: EEG.GMFA.(name).tseries = std(mean(EEG.data,3))
%   i.e. the default (N-1) standard deviation across channels of the
%   trial-averaged data. Keeping the one-line formula here (instead of calling
%   tesa_tepextract) avoids its side effects - it mutates the EEG struct,
%   writes EEG.GMFA, prints to the console, and has no ROI-restricted variant -
%   while producing numerically identical GMFP. LMFP applies the same formula
%   to the ROI subset, for which TESA has no built-in function.
%
%   Inputs:
%     data     - channels x time x trials numeric array (EEG.data).
%     roiIdx   - indices of the ROI electrodes (used by 'TEP' and 'LMFP').
%     plotType - 'TEP', 'GMFP' or 'LMFP' (case-insensitive).
%
%   Output:
%     curve - 1 x time row vector.

    trialAvg = mean(data, 3, 'omitnan');   % channels x time (TESA: mean(EEG.data,3))

    switch upper(string(plotType))
        case "GMFP"
            curve = std(trialAvg, 0, 1, 'omitnan');
        case "LMFP"
            curve = std(trialAvg(roiIdx, :), 0, 1, 'omitnan');
        otherwise   % 'TEP'
            curve = mean(trialAvg(roiIdx, :), 1, 'omitnan');
    end
end
