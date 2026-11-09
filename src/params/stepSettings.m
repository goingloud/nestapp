% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = stepSettings(step, registry)
% STEPSETTINGS  A pipeline step's registry entry, typed settings and problems.
%   s = STEPSETTINGS(step) / STEPSETTINGS(step, registry) for a spec element
%   (name, params). Returns a struct:
%     entry        the registry entry (canonical name), or [] if none
%     typed        true for a schema-2 step
%     params       the settings, migrated to typed values (migrateStepParams)
%     problems     what would stop it running (paramProblems)
%     problemKeys  the settings those problems involve
%
%   The one place a step is looked up, migrated and checked, shared by the
%   Cleaning tab, the pre-flight check and the dispatch, so the three cannot
%   disagree about a step (a legacy name, say).
%
%   See also: migrateStepParams, paramProblems, toUpstream

if nargin < 2 || isempty(registry), registry = stepRegistry(); end
s = struct('entry', [], 'typed', false, 'params', step.params, ...
    'problems', {{}}, 'problemKeys', {{}});
e = registry(strcmp({registry.name}, canonicalStepName(step.name)));
if ~isscalar(e), return; end
s.entry = e;
s.typed = e.schema >= 2;
if ~s.typed, return; end
s.params = migrateStepParams(e, step.params);
[s.problems, s.problemKeys] = paramProblems(e, s.params);
end
