
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function isAvailable = electrodeAvailability(elecList, labelSets)
% ELECTRODEAVAILABILITY  Electrodes present in every selected file.
%   isAvailable = ELECTRODEAVAILABILITY(elecList, labelSets) returns a logical
%   row vector, one entry per electrode in elecList, that is true when that
%   electrode's label appears in EVERY label set in labelSets. Electrodes that
%   are missing from at least one file (or, when no files are selected, none)
%   are unavailable - the Visualizing tab greys those buttons out.
%
%   Inputs:
%     elecList  - cellstr of the app's known electrode labels (one per button).
%     labelSets - 1xN cell, each cell a cellstr of channel labels for one
%                 selected file. May be empty (no files selected).
%
%   Output:
%     isAvailable - 1xnumel(elecList) logical; true where the electrode is
%                   common to all files (and therefore clickable).
%
%   Matching is case-sensitive, mirroring the historical LoadLabels behaviour
%   (elecList entries are expected to match the EEG channel labels exactly).

    elecList = elecList(:)';   % normalise to a row for consistent output shape

    % Intersect down to the labels shared by every file. With no files the
    % common set stays the full elecList, so every electrode is available.
    common = elecList;
    for i = 1:numel(labelSets)
        common = intersect(common, labelSets{i});
    end

    isAvailable = ismember(elecList, common);
end
