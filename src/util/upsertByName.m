% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = upsertByName(s, entry)
% UPSERTBYNAME  Replace the element of s named entry.name, or append it.
%   s = UPSERTBYNAME(s, entry) requires both to have a .name field.
%
%   Branchless on purpose: an index past the end appends, so replace and append
%   are one assignment rather than two paths that have to agree. The if/else
%   version of this appeared in both roiPresets and saveRoiPreset.
%
%   See also: roiPresets, saveRoiPreset

if isempty(s)
    s = entry;
    return
end
k = find(strcmp({s.name}, entry.name), 1);
if isempty(k); k = numel(s) + 1; end
s(k) = entry;
end
