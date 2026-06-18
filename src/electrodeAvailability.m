
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
%   Matching is case-INsensitive: EEG montages vary in case (e.g. a file's
%   'Fp1' versus the button label 'FP1'), and a case-sensitive compare would
%   wrongly grey a present electrode. This mirrors the IgnoreCase the
%   bad-channel protection path already uses.

    elecList = elecList(:)';   % normalise to a row for consistent output shape

    % An electrode is available when it appears in EVERY file. With no files
    % the mask stays all-true, so every electrode is available.
    isAvailable = true(1, numel(elecList));
    elecLower   = lower(elecList);
    for i = 1:numel(labelSets)
        isAvailable = isAvailable & ismember(elecLower, lower(labelSets{i}));
    end
end
