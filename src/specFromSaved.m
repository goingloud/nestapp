
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [spec, warnings] = specFromSaved(data, registry)
% SPECFROMSAVED Load a PipelineSpec from a saved pipeline .mat.
%   [spec, warnings] = SPECFROMSAVED(data, registry)
%
%   data must contain a 'spec' field. Returns a struct array of PipelineStep
%   ({name, params}). Unknown steps are included with a warning.

warnings = {};

if ~isfield(data, 'spec')
    spec = repmat(struct('name','','params',struct()), 0, 1);
    warnings{end+1} = 'File is not in the current format. Re-save the pipeline from the app.';
    return
end

spec = data.spec;

% Migration reads each step's parameters; a spec saved before params existed
% (or hand-built) may not carry the field at all, and indexing it would turn a
% loadable-with-warnings pipeline into a hard error.
if ~isempty(spec) && ~isfield(spec, 'params')
    [spec.params] = deal(struct());
end

for k = 1:numel(spec)
    % Migrate legacy step names AND parameters (some renames also changed the
    % parameter set) so old saved pipelines keep resolving against the current
    % registry. Migrations that made a judgement call report it, so the user
    % sees what changed rather than silently running something else.
    [spec(k).name, spec(k).params, note] = ...
        canonicalStepName(spec(k).name, spec(k).params);
    if ~isempty(note)
        warnings{end+1} = sprintf('Step %d migrated: %s', k, note); %#ok<AGROW>
    end
    if ~any(strcmp({registry.name}, spec(k).name))
        warnings{end+1} = sprintf('Unknown step "%s" (not in registry)', spec(k).name); %#ok<AGROW>
    end
end
end
