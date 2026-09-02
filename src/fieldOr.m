% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function v = fieldOr(s, name, default)
% FIELDOR  A struct field's value, or a default when it is absent or empty.
%   v = FIELDOR(s, name, default)
%
%   Empty counts as absent, the same convention fillDefaults uses: callers
%   throughout this codebase build structs field by field and leave a field as
%   [] to mean "you choose", so treating [] as a real value would make
%   struct('level', []) behave differently from omitting level entirely.
%
%   Reads a saved artifact whose shape has grown over time. Every Explore
%   result format has gained fields - plotParams, subjectConfident, info.roi,
%   info.level - and a .mat saved before one existed simply lacks it. That is
%   not an error, so the readers ask this rather than guarding each field with
%   its own isfield chain.
%
%   Promoted from a file-local helper. It had been written out identically in
%   exploreResults and exploreStateFromResults, and a third hand-rolled copy
%   was about to appear in the app class - at which point the isfield-vs-empty
%   convention was being decided independently in three places.
%
%   See also: fillDefaults, exploreResults, exploreStateFromResults

if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
