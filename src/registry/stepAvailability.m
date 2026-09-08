
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [ok, unmet] = stepAvailability(regEntry, exts)
% STEPAVAILABILITY  Can this step run on this machine, right now?
%   [ok, unmet] = STEPAVAILABILITY(regEntry) evaluates every requirement the
%   step declares and returns whether all are satisfied. unmet is a struct
%   array of the ones that are not, each with:
%       .fn      the function that could not be resolved
%       .plugin  the display name of what provides it
%       .note    what the user should do about it
%       .kind    'version' (plugin too old) or 'missing' (function absent).
%                Callers that need to tell those apart should read this rather
%                than pattern-match the note - the install note for a
%                version-gated step mentions the version too, so the strings
%                are not distinguishable.
%
%   [ok, unmet] = STEPAVAILABILITY(regEntry, exts) additionally skips
%   format-specific requirements (req(...,'fileExt')) when no selected file
%   has that extension.
%
%   THE point of this function is that there is only one of it. Availability
%   was previously answered in two disconnected ways - never at list time, and
%   at run time by checkStepDependencies - and a third notion was about to be
%   added for version gating. Both callers now ask the same question of the
%   same code:
%       availableSteps        -> what the picker offers
%       checkStepDependencies -> what blocks a run before it starts
%
%   Three kinds of requirement, in increasing strictness:
%     plain        which(fn) must resolve
%     feature      a license-gated toolbox function. which() is not enough:
%                  which('fit') stays non-empty without the Curve Fitting
%                  Toolbox because it falls through to @gmdistribution/fit.
%     minVersion   the providing plugin must declare at least this version.
%                  Read from the plugin, never probed for - see tesaVersion.
%
%   See also: tesaVersion, availableSteps, checkStepDependencies, stepRegistry

if nargin < 2, exts = {}; end

unmet = struct('fn', {}, 'plugin', {}, 'note', {}, 'kind', {});

reqs = regEntry.requires;
for j = 1:numel(reqs)
    r = reqs(j);

    % Format-specific loaders only matter when such a file is selected.
    if isFieldSet(r, 'fileExt') && ~isempty(r.fileExt)
        if isempty(exts) || ~any(strcmpi(exts, r.fileExt))
            continue
        end
    end

    % Version gate first: a too-old plugin is a clearer answer than the
    % "missing function" the which() check would otherwise report.
    if isFieldSet(r, 'minVersion')
        [meets, have, want] = versionSatisfied(r);
        if ~meets
            unmet(end+1) = struct('fn', r.fn, 'plugin', r.plugin, ...
                'note', sprintf(['Requires %s %s or later; %s is installed. ' ...
                                 'Update the plugin to use this step.'], ...
                                r.plugin, want, have), ...
                'kind', 'version'); %#ok<AGROW>
            continue
        end
    end

    if isFieldSet(r, 'feature')
        [isAvail, note] = toolboxFnAvailable(r);
        if ~isAvail
            unmet(end+1) = struct('fn', r.fn, 'plugin', r.plugin, ...
                'note', note, 'kind', 'missing'); %#ok<AGROW>
        end
        continue
    end

    if isempty(which(r.fn))
        unmet(end+1) = struct('fn', r.fn, 'plugin', r.plugin, ...
            'note', r.installNote, 'kind', 'missing'); %#ok<AGROW>
    end
end

ok = isempty(unmet);
end

% ── helpers ─────────────────────────────────────────────────────────────────
function [meets, haveStr, wantStr] = versionSatisfied(r)
% Compare the installed plugin's declared version against r.minVersion.
want    = parseVersion(r.minVersion);
wantStr = versionString(want);

% Only TESA declares a version today. An unknown provider cannot be checked,
% so treat it as satisfied rather than blocking a step over a rule we have no
% way to evaluate - the which() probe below still catches a genuinely absent
% function.
if ~strcmpi(r.plugin, 'TESA')
    meets = true; haveStr = 'unknown';
    return
end

have    = tesaVersion();
haveStr = versionString(have);
if isequal(have, [0 0 0])
    haveStr = 'none';
end
% Elementwise: [1 2 0] >= [1 2 0] passes, [1 1 1] >= [1 2 0] does not.
meets = ~isVersionLess(have, want);
end

function tf = isVersionLess(a, b)
tf = false;
for k = 1:3
    if a(k) < b(k); tf = true;  return; end
    if a(k) > b(k); tf = false; return; end
end
end

function v = parseVersion(str)
if isnumeric(str); v = [str(:)' 0 0 0]; v = v(1:3); return; end
parts = str2double(strsplit(char(str), '.'));
parts(isnan(parts)) = 0;
v = [parts(:)' 0 0 0];
v = v(1:3);
end

function s = versionString(v)
s = sprintf('%d.%d.%d', v(1), v(2), v(3));
end

function tf = isFieldSet(r, name)
tf = isfield(r, name) && ~isempty(r.(name));
end

function [isAvail, note] = toolboxFnAvailable(r)
% Curve Fitting has a dedicated probe that also repairs a mis-set path; any
% other feature falls back to which() plus a license test.
if strcmpi(r.feature, 'Curve_Fitting_Toolbox')
    [isAvail, note] = ensureCurveFittingFit();
else
    isAvail = ~isempty(which(r.fn)) && license('test', r.feature) == 1;
    note    = r.installNote;
end
end
