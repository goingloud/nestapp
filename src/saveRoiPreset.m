% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function saveRoiPreset(name, labels)
% SAVEROIPRESET  Store a named ROI in preferences, or delete one.
%   SAVEROIPRESET(name, labels) saves labels under name, replacing any preset
%   of that name.
%
%   SAVEROIPRESET(name, {}) deletes the saved preset called name. A built-in
%   that was overridden reverts to its shipped definition, because roiPresets
%   only overrides a built-in when a saved entry of the same name exists.
%
%   Presets are per-user preferences rather than part of a session file: an ROI
%   like the near-coil cluster is a habit of whoever is analysing, and should
%   be there in a fresh session without loading anything.
%
%   See also: roiPresets, roiPicker

name = char(name);
if isempty(strtrim(name))
    error('nestapp:emptyPresetName', 'An ROI preset needs a name.');
end
if ischar(labels) || isstring(labels); labels = cellstr(labels); end

saved = getpref('nestapp', 'roiPresets', struct('name', {}, 'labels', {}));
if isempty(saved) || ~isfield(saved, 'name')
    saved = struct('name', {}, 'labels', {});
end

k = find(strcmp({saved.name}, name), 1);
if isempty(labels)
    if ~isempty(k); saved(k) = []; end
else
    entry = struct('name', name, 'labels', {labels(:)'});
    if isempty(k)
        saved(end+1) = entry;
    else
        saved(k) = entry;
    end
end

setpref('nestapp', 'roiPresets', saved);
end
