% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function labels = partialElectrodes(cache, modalLabels)
% PARTIALELECTRODES  Electrodes SOME loaded file carries that the montage does not.
%   labels = PARTIALELECTRODES(cache, modalLabels)
%
%   cache        loadReducedSets output; only entries with .ok are considered
%   modalLabels  the montage the curves are computed on (res.channelLabels)
%
%   groupCurves computes on the MODAL montage and excludes files recorded on a
%   different cap, so res.channelLabels reports exactly what can be averaged.
%   That leaves an electrode present in 30 of 32 files looking identical to one
%   present in none, and they are not the same: including the first makes the
%   ROI mean a different set of channels in different files, which is a
%   methodological choice, while the second cannot be averaged at all.
%
%   Kept out of the app class because it is a statement about label sets, not
%   about widgets - the ROI picker is one caller, and a script asking "what did
%   the modal montage cost me" is another.
%
%   See also: groupCurves, roiSelectionState, roiPicker, loadReducedSets

labels = {};
if isempty(cache) || ~isfield(cache, 'ok'); return; end
ok = cache([cache.ok]);
if isempty(ok); return; end

everything = unique([ok.labels], 'stable');
labels = everything(~ismember(lower(everything), lower(modalLabels)));
end
