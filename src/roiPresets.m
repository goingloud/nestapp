% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function presets = roiPresets()
% ROIPRESETS  Named electrode sets the ROI picker offers.
%   presets = ROIPRESETS() returns a struct array with .name, .labels and
%   .userDefined, built-ins first and then anything the user has saved.
%
%   .userDefined is what the UI needs to decide whether a preset can be
%   deleted, and it is answered here because this is where the two sources are
%   merged. A view that had to work it out would need its own look at the
%   preference store, which is exactly the coupling this function exists to
%   absorb.
%
%   Built-ins are the two clusters this project uses:
%
%     'F3 cluster (default)'  AF3 F1 F3 FC1 FC3 - what the Visualizing tab has
%                             always started with, preserved so the app opens
%                             on the ROI it always has.
%     'Near-coil (F3)'        AF3 F5 F3 FC5 FC3 - the near-coil ROI used to
%                             check the early-window pedestal, which GMFA is
%                             blind to. Rebuilding it by clicking five of 69
%                             buttons every session is the friction presets
%                             exist to remove.
%
%   User presets live in the 'nestapp' preference group under 'roiPresets'. A
%   saved preset whose name matches a built-in replaces it, so a default can be
%   corrected without editing code, and deleting the override reverts.
%
%   Per-user preferences rather than part of a session file: a named ROI is a
%   habit of whoever is analysing and should be there in a fresh session with
%   nothing loaded. The CURRENT ROI is separate - it goes in and out of
%   roiPicker as a cellstr, so a session owns that.
%
%   See also: roiPicker, saveRoiPreset, roiMontageLayout, electrodeList

presets = struct( ...
    'name',        {'F3 cluster (default)', 'Near-coil (F3)'}, ...
    'labels',      {{'AF3', 'F1', 'F3', 'FC1', 'FC3'}, ...
                    {'AF3', 'F5', 'F3', 'FC5', 'FC3'}}, ...
    'userDefined', {false, false});

saved = savedRoiPresets();
for i = 1:numel(saved)
    entry = struct('name', saved(i).name, 'labels', {saved(i).labels}, ...
                   'userDefined', true);
    presets = upsertByName(presets, entry);
end
end
