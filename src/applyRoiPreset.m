% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [selected, missing] = applyRoiPreset(labels, enabled, wanted)
% APPLYROIPRESET  Turn a named electrode set into a selection mask.
%   [selected, missing] = APPLYROIPRESET(labels, enabled, wanted) switches on
%   every electrode the preset names that the data actually offers, and reports
%   the ones it could not.
%
%   missing is the point. Applying a five-electrode ROI when only three are
%   available quietly changes what the preset means - the near-coil cluster
%   minus F5 is a different measurement, not a smaller one - so the caller is
%   given the shortfall to say out loud.
%
%   See also: roiSelectionState, roiPresets, roiPicker

if ischar(wanted) || isstring(wanted); wanted = cellstr(wanted); end
wanted = wanted(:)';

selected = ismember(lower(labels), lower(wanted)) & enabled;
missing  = wanted(~ismember(lower(wanted), lower(labels(enabled))));
end
