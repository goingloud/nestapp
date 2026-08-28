% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [presets, builtinNames] = roiPresets()
% ROIPRESETS  Named electrode sets the ROI picker offers.
%   [presets, builtinNames] = ROIPRESETS() returns a struct array with .name
%   and .labels, built-ins first and then any the user has saved.
%
%   Built-ins are the two clusters this project actually uses:
%
%     'F3 cluster (default)'  AF3 F1 F3 FC1 FC3 - what the Visualizing tab has
%                             always started with, preserved so the app opens
%                             on the same ROI it used to.
%     'Near-coil (F3)'        AF3 F5 F3 FC5 FC3 - the near-coil ROI used to
%                             check the early-window pedestal, which GMFA is
%                             blind to. Reconstructing it by clicking five of
%                             69 buttons every session is exactly the friction
%                             presets exist to remove.
%
%   User presets live in the 'nestapp' preference group under 'roiPresets', as
%   a struct array of the same shape. A saved preset whose name matches a
%   built-in replaces it, so the defaults can be corrected without editing
%   code.
%
%   builtinNames lists the shipped names, so the UI can mark a preset as
%   user-defined (and offer to delete it) without guessing.
%
%   See also: roiPicker, saveRoiPreset, roiMontageLayout

presets = struct( ...
    'name',   {'F3 cluster (default)', 'Near-coil (F3)'}, ...
    'labels', {{'AF3', 'F1', 'F3', 'FC1', 'FC3'}, ...
               {'AF3', 'F5', 'F3', 'FC5', 'FC3'}});
builtinNames = {presets.name};

saved = getpref('nestapp', 'roiPresets', struct('name', {}, 'labels', {}));
if isempty(saved) || ~isfield(saved, 'name'); return; end

for i = 1:numel(saved)
    k = find(strcmp({presets.name}, saved(i).name), 1);
    if isempty(k)
        presets(end+1) = saved(i); %#ok<AGROW>
    else
        presets(k) = saved(i);     % a user override wins over the built-in
    end
end
end
