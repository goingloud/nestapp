
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [ok, msg] = checkStepDependencies(stepNames, filePaths)
% CHECKSTEPDEPENDENCIES  Verify required plugins are on the MATLAB path.
%
%   [ok, msg] = checkStepDependencies(stepNames, filePaths)
%
%   Inputs
%     stepNames  - cell array of step name strings (app.SelectedListBox.Items)
%     filePaths  - cell array of full file paths being processed (app.file).
%                  Used to filter format-specific loaders (e.g. bva-io only
%                  checked when .vhdr files are selected).
%
%   Outputs
%     ok   - true if all dependencies are satisfied
%     msg  - formatted message listing missing plugins ('' when ok=true)
%
%   Checks are done via which(), so the function must be called after
%   EEGLAB has been added to the path (i.e. after app startup).

if nargin < 2
    filePaths = {};
end

% Build extension set from file paths for format-specific dep filtering.
[~,~,extList] = cellfun(@fileparts, filePaths, 'UniformOutput', false);
exts = unique(lower(extList));

steps    = stepRegistry();
nameList = {steps.name};

% Vendored AARATEP helpers ship with nestapp under third_party/ but are only
% added to the path lazily during step dispatch. Add them now - only when a
% selected step actually needs them - so the which() probes below see the
% bundled functions instead of reporting them as missing plugins. Gating
% avoids a ~280-file genpath walk on every non-AARATEP pre-flight.
%
% Which steps need them is DERIVED from the registry (a requirement whose
% function is a vendored c_* helper), not from a hand-kept list beside it.
% The previous list named three steps while five needed the path, so
% "Modified Bandpass Filter (AARATEP)" and both "Detect Bad Channels" steps
% were reported as missing a plugin that ships in the box - blocking runs
% that would have worked.
if anyStepNeedsVendoredHelper(stepNames, steps, nameList)
    try
        ensureAaratepOnPath();
    catch
        % If the vendored tree is genuinely absent, the which() checks
        % below report the AARATEP steps as missing with the bundled note.
    end
end

% missing: containers.Map keyed by plugin display name
missing = containers.Map('KeyType','char','ValueType','any');

for i = 1:numel(stepNames)
    idx = find(strcmp(nameList, stepNames{i}), 1);
    if isempty(idx); continue; end
    % One resolver answers this for both the picker and the pre-flight, so a
    % step cannot be offered in the list and then rejected here (or the
    % reverse). See stepAvailability.
    if isempty(filePaths); checkExts = {}; else; checkExts = exts; end
    [avail, unmet] = stepAvailability(steps(idx), checkExts);
    if avail; continue; end
    for j = 1:numel(unmet)
        missing = addMissing(missing, unmet(j).plugin, unmet(j).note, ...
                             stepNames{i}, unmet(j).fn);
    end
end

if isempty(missing)
    ok  = true;
    msg = '';
    return
end

ok    = false;
lines = {'Missing plugins - install before running:', ''};
pluginNames = keys(missing);
for i = 1:numel(pluginNames)
    plugin = pluginNames{i};
    entry  = missing(plugin);
    usedBy = strjoin(unique(entry.steps), ', ');
    lines{end+1} = sprintf('  %s', plugin);                          %#ok<AGROW>
    lines{end+1} = sprintf('    Steps:   %s', usedBy);               %#ok<AGROW>
    lines{end+1} = sprintf('    Install: %s', entry.installNote);    %#ok<AGROW>
    lines{end+1} = '';                                                %#ok<AGROW>
end
msg = strjoin(lines, newline);
end

% ── helpers ───────────────────────────────────────────────────────────────────
function tf = anyStepNeedsVendoredHelper(stepNames, steps, nameList)
% True when any selected step declares a requirement on a vendored AARATEP
% helper. Those are the c_* functions under third_party/aaratep; every other
% requirement resolves from the normal MATLAB path.
tf = false;
for i = 1:numel(stepNames)
    k = find(strcmp(nameList, stepNames{i}), 1);
    if isempty(k); continue; end
    rq = steps(k).requires;
    for j = 1:numel(rq)
        if isfield(rq(j), 'fn') && ~isempty(rq(j).fn) && ...
                startsWith(rq(j).fn, 'c_')
            tf = true; return
        end
    end
end
end

function missing = addMissing(missing, plugin, note, stepName, fn)
% Record one unsatisfied requirement under its plugin display name.
if ~isKey(missing, plugin)
    missing(plugin) = struct('installNote', note, 'steps', {{}}, 'fns', {{}});
end
entry = missing(plugin);
entry.steps{end+1} = stepName;
entry.fns{end+1}   = fn;
missing(plugin)    = entry;
end
