% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function saveRoiPreset(name, labels)
% SAVEROIPRESET  Store a named ROI in preferences, or delete one.
%   SAVEROIPRESET(name, labels) saves labels under name, replacing any preset
%   of that name.
%
%   SAVEROIPRESET(name, {}) deletes the saved preset called name. A built-in
%   that had been overridden reverts to its shipped definition, because
%   roiPresets only overrides a built-in while a saved entry of that name
%   exists.
%
%   See also: roiPresets, savedRoiPresets, roiPicker

name = char(name);
if isempty(strtrim(name))
    error('nestapp:emptyPresetName', 'An ROI preset needs a name.');
end
if ischar(labels) || isstring(labels); labels = cellstr(labels); end

saved = savedRoiPresets();
if isempty(labels)
    saved(strcmp({saved.name}, name)) = [];
else
    saved = upsertByName(saved, struct('name', name, 'labels', {labels(:)'}));
end
setpref('nestapp', 'roiPresets', saved);
end
