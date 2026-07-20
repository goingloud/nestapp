
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [name, params, note] = canonicalStepName(name, params)
% CANONICALSTEPNAME  Map a legacy pipeline-step name to its current name.
%   name = CANONICALSTEPNAME(name) returns the canonical (current) name for a
%   step, rewriting historical names that have since been renamed. Unknown /
%   already-current names pass through unchanged.
%
%   [name, params, note] = CANONICALSTEPNAME(name, params) additionally
%   migrates the step's PARAMETERS, for renames where the parameters moved
%   too. note is a human-readable description of what was migrated ('' when
%   nothing was), for the caller to surface to the user.
%
%   This keeps saved user pipelines and old templates working after a step is
%   renamed: specFromSaved rewrites names on load, and processOneFile applies
%   it again before dispatch as a safety net. Add a row here whenever a step's
%   display name changes.
%
%   A pure rename goes in the aliases table below. A rename that also changes
%   the parameter set needs a case in migrateParams - a name-only alias would
%   silently drop or misapply parameters, which on an ICA step means quietly
%   running a different algorithm than the saved pipeline asked for.
%
%   See also: specFromSaved, processOneFile, stepRegistry

if nargin < 2, params = struct(); end
note = '';

if ~ischar(name) && ~(isstring(name) && isscalar(name))
    return
end
name = char(name);

% Pure renames. Each row: {oldName, newName}.
aliases = {
    'Remove Recording Noise (SOUND)', 'Source-Informed Sensor Cleaning (SOUND)'
    };

hit = strcmp(aliases(:, 1), name);
if any(hit)
    name = aliases{find(hit, 1), 2};
    return
end

[name, params, note] = migrateParams(name, params);
end

% ── parameter-aware migrations ───────────────────────────────────────────────
function [name, params, note] = migrateParams(name, params)
note = '';

switch name
    case 'Run ICA'
        % 'Run ICA' chose its algorithm through an `icatype` parameter and
        % passed everything to pop_runica. It is now three steps, one per
        % engine, each carrying only the parameters that engine accepts.
        %
        % The engine MUST come from icatype. Aliasing the name alone would
        % silently run FastICA for a pipeline that asked for infomax or
        % Picard - a different decomposition, no error, plausible output.
        icatype = 'fastica';                     % the old step's default
        if isfield(params, 'icatype') && ~isempty(params.icatype)
            icatype = lower(strtrim(char(params.icatype)));
        end

        switch icatype
            case 'fastica'
                name   = 'Run ICA (FastICA)';
                % approach / g / stabilization carry over unchanged.
                params = rmfieldIfPresent(params, 'icatype');
                note   = 'Run ICA -> Run ICA (FastICA)';

            case 'runica'
                name = 'Run ICA (Infomax)';
                % The old dispatch stripped these before calling pop_runica
                % for runica (they crash its parser), so dropping them here
                % preserves behaviour exactly.
                params = rmfieldIfPresent(params, ...
                    {'icatype', 'approach', 'g', 'stabilization'});
                % The old step never passed `extended`, so it inherited
                % pop_runica's own default; the new step makes the choice
                % explicit and defaults to extended infomax. Flag it rather
                % than assume the old implicit default matched.
                if ~isfield(params, 'extended')
                    params.extended = 'on';
                end
                note = ['Run ICA (icatype=runica) -> Run ICA (Infomax); ' ...
                        'extended set to ''on'' (previously left to the ' ...
                        'pop_runica default) - confirm this matches intent'];

            case 'picard'
                name   = 'Run ICA (Picard)';
                params = rmfieldIfPresent(params, ...
                    {'icatype', 'approach', 'g', 'stabilization'});
                note   = 'Run ICA (icatype=picard) -> Run ICA (Picard)';

            otherwise
                % Includes binica, which has no equivalent step. Leave the
                % name alone so the caller's "unknown step" warning fires and
                % the user resolves it, rather than us picking an engine.
                note = sprintf( ...
                    ['Run ICA used icatype="%s", which has no equivalent ' ...
                     'step. Choose one of the Run ICA (FastICA/Infomax/' ...
                     'Picard) steps manually.'], icatype);
        end
end
end

function s = rmfieldIfPresent(s, names)
% rmfield errors on a field that is not there; saved specs vary in which
% optional parameters they carry.
if ischar(names), names = {names}; end
present = names(isfield(s, names));
if ~isempty(present)
    s = rmfield(s, present);
end
end
