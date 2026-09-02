
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function idx = roiChannelIndex(channelLabels, roiElectrodes)
% ROICHANNELINDEX  Channel indices matching an ROI, case-insensitively.
%   idx = ROICHANNELINDEX(channelLabels, roiElectrodes) returns the column
%   indices into channelLabels (a cellstr of EEG channel labels) of the
%   electrodes named in roiElectrodes. Matching ignores case because EEG
%   montages vary in label case (e.g. a file's 'Fp1' vs a requested 'FP1').
%
%   See also: tepFieldCurve, groupCurves, electrodeAvailability
    idx = find(ismember(lower(channelLabels), lower(roiElectrodes)));
end
