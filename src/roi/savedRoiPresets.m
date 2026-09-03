% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function saved = savedRoiPresets()
% SAVEDROIPRESETS  The user's stored ROI presets, normalised.
%   saved = SAVEDROIPRESETS() reads the 'roiPresets' preference and always
%   returns a struct array with .name and .labels - empty when there is
%   nothing stored, or when what is stored predates those fields.
%
%   The read-and-normalise pair had three spellings across three files, each
%   with its own idea of what a legacy or corrupt value means. One reader, so
%   there is one answer.
%
%   See also: roiPresets, saveRoiPreset

saved = getpref('nestapp', 'roiPresets', struct('name', {}, 'labels', {}));
if isempty(saved) || ~isfield(saved, 'name') || ~isfield(saved, 'labels')
    saved = struct('name', {}, 'labels', {});
end
end
