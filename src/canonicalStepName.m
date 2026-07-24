
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
    case 'Flag ICA Components (AARATEP Peak)'
        % De-registered as a step: it is our own interpretation of a threshold
        % the 2021 paper states without giving a formula, and it is absent from
        % the maintained AARATEP code - so it is not something nestapp should
        % offer as a first-class step. The function stays on the path, and
        % pipelines that used it keep working by calling it directly.
        %
        % Migrated rather than left to break: ten saved pipelines use this
        % step, so rewriting one .mat would have left nine of them failing to
        % load. Carrying the threshold across matters - dropping it would
        % silently substitute the default for whatever the pipeline chose.
        thresh = 15;
        if isfield(params, 'peakThresholdUv') && ~isempty(params.peakThresholdUv)
            thresh = params.peakThresholdUv;
        end
        name   = 'Manual Command';
        params = struct( ...
            'command', sprintf( ...
                'EEG = aaratepPeakAmplitudeClassifier(EEG, ''peakThresholdUv'', %g);', thresh), ...
            'description', sprintf( ...
                'AARATEP peak-amplitude IC flag (%g uV) - was a step, now a direct call', thresh));
        note = sprintf(['Flag ICA Components (AARATEP Peak) -> Manual Command ' ...
                        '(threshold %g uV preserved); the step was de-registered ' ...
                        'but the function still runs'], thresh);

    case 'Flag ICA Components (AARATEP Muscle)'
        % Retired as a step: our port of an AARATEP muscle heuristic that
        % overlaps TESA's own IC muscle detection (pop_tesa_compselect). De-
        % registered so nestapp does not advertise a second, in-house muscle
        % classifier - but, like the Peak flag, the function stays on the path
        % and saved pipelines keep working by calling it directly. Window and
        % threshold carry across so a pipeline runs what it asked for.
        w1 = 11; w2 = 30; thr = 8;
        if isfield(params,'winStartMs')      && ~isempty(params.winStartMs);      w1  = params.winStartMs;      end
        if isfield(params,'winEndMs')        && ~isempty(params.winEndMs);        w2  = params.winEndMs;        end
        if isfield(params,'muscleThreshold') && ~isempty(params.muscleThreshold); thr = params.muscleThreshold; end
        name   = 'Manual Command';
        params = struct( ...
            'command', sprintf(['EEG = aaratepMuscleClassifier(EEG, ''winStartMs'', %g, ' ...
                '''winEndMs'', %g, ''muscleThreshold'', %g);'], w1, w2, thr), ...
            'description', sprintf('AARATEP muscle IC flag ([%g %g] ms, x%g) - was a step, now a direct call', w1, w2, thr));
        note = sprintf(['Flag ICA Components (AARATEP Muscle) -> Manual Command ' ...
                        '(window [%g %g] ms, threshold %g preserved); the step was ' ...
                        'de-registered but the function still runs'], w1, w2, thr);

    case 'Modified Bandpass Filter (AARATEP)'
        % De-registered: TESA 1.2 ships tesa_modifiedbandpassfilter, a port of
        % the same Cline function whose output is bit-identical for matched
        % settings. Map onto the TESA step so pipelines run the maintained copy.
        % The old step widened the artifact window by artifactMultiplier before
        % filtering; the TESA step has no multiplier, so bake it into the window.
        lo = 1; hi = []; aS = -2; aE = 12; mult = 3; ext = 0.5;
        if isfield(params,'lowCutoff')             && ~isempty(params.lowCutoff);             lo   = params.lowCutoff;             end
        if isfield(params,'highCutoff')            && ~isempty(params.highCutoff);            hi   = params.highCutoff;            end
        if isfield(params,'artifactStartMs')       && ~isempty(params.artifactStartMs);       aS   = params.artifactStartMs;       end
        if isfield(params,'artifactEndMs')         && ~isempty(params.artifactEndMs);         aE   = params.artifactEndMs;         end
        if isfield(params,'artifactMultiplier')    && ~isempty(params.artifactMultiplier);    mult = params.artifactMultiplier;    end
        if isfield(params,'piecewiseTimeToExtend') && ~isempty(params.piecewiseTimeToExtend); ext  = params.piecewiseTimeToExtend; end
        if isequal(hi, 0); hi = []; end            % 0 meant "no low-pass"; TESA uses []
        name   = 'Modified Bandpass Filter (TESA)';
        params = struct( ...
            'lowCutoff',       lo, ...
            'highCutoff',      hi, ...
            'filterMethod',    'butterworth', ...
            'artifactStartMs', aS * mult, ...
            'artifactEndMs',   aE * mult, ...
            'extendMs',        ext * 1000, ...
            'filtOrder',       4, ...
            'filtType',        'auto');
        note = sprintf(['Modified Bandpass Filter (AARATEP) -> (TESA); artifact ' ...
                        'window x%g baked into [%g %g] ms, extend %g ms - same ' ...
                        'output (TESA ports the same function)'], mult, aS*mult, aE*mult, ext*1000);

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
