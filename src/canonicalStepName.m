
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function name = canonicalStepName(name)
% CANONICALSTEPNAME  Map a legacy pipeline-step name to its current name.
%   name = CANONICALSTEPNAME(name) returns the canonical (current) name for a
%   step, rewriting historical names that have since been renamed. Unknown /
%   already-current names pass through unchanged.
%
%   This keeps saved user pipelines and old templates working after a step is
%   renamed: specFromSaved rewrites names on load, and processOneFile applies
%   it again before dispatch as a safety net. Add a row here whenever a step's
%   display name changes.
%
%   See also: specFromSaved, processOneFile, stepRegistry

% Each row: {oldName, newName}.
aliases = {
    'Remove Recording Noise (SOUND)', 'Source-Informed Sensor Cleaning (SOUND)'
    };

if ~ischar(name) && ~(isstring(name) && isscalar(name))
    return
end
hit = strcmp(aliases(:, 1), char(name));
if any(hit)
    name = aliases{find(hit, 1), 2};
end
end
