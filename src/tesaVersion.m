
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [v, source] = tesaVersion(forceRefresh)
% TESAVERSION  Version of the TESA plugin currently on the MATLAB path.
%   v = TESAVERSION() returns a 1x3 numeric [major minor patch]. Returns
%   [0 0 0] when TESA is not on the path at all.
%
%   [v, source] = TESAVERSION() also returns where the number came from:
%   'vers' (the declaration inside eegplugin_tesa.m), 'folder' (parsed from
%   the plugin directory name), or 'none'.
%
%   TESAVERSION(true) re-reads instead of using the cached value. The result
%   is cached because it is consulted for every step in the registry.
%
%   The cache is held by pathMemo, keyed on eegplugin_tesa, so it is discarded
%   whenever that stops resolving OR resolves somewhere new. The old persistent
%   was invalidated by nothing but this flag, so a plugin swapped mid-session -
%   or a path reset - kept reporting the version that was installed first.
%
%   IMPORTANT - this reads the DECLARED version and never probes for
%   functions. Feature-probing looks equivalent and is not: nestapp shipped
%   vendored copies of pop_tesa_robustdetrend and pop_tesa_modifiedbandpassfilter
%   in src/, so exist('pop_tesa_robustdetrend') was true on a machine with
%   TESA 1.1.1 installed. A probe would have reported 1.2 and offered steps
%   the plugin cannot run. Those copies are gone, but the hazard returns the
%   moment anything is vendored again, so the rule stands.
%
%   See also: stepAvailability, checkStepDependencies, stepRegistry

if nargin < 1, forceRefresh = false; end
if forceRefresh
    pathMemo('eegplugin_tesa', []);
end

res    = pathMemo('eegplugin_tesa', @readVersion);
v      = res.v;
source = res.source;
end

% ── helpers ─────────────────────────────────────────────────────────────────

function res = readVersion()
v = [0 0 0];
source = 'none';

% Not installed leaves the [0 0 0] / 'none' defaults above, so the parsing is
% guarded rather than returned around - one construction site at the end.
pluginFile = which('eegplugin_tesa');
if ~isempty(pluginFile)
    % Preferred: the version the plugin declares about itself.
    try
        txt = fileread(pluginFile);
        tok = regexp(txt, "vers\s*=\s*'tesa([0-9]+(?:\.[0-9]+)*)'", 'tokens', 'once');
        if ~isempty(tok)
            v = parseVersion(tok{1});
            source = 'vers';
        end
    catch
        % Unreadable file - fall through to the folder name.
    end

    % Fallback: EEGLAB installs plugins into a version-stamped directory
    % (plugins/TESA1.1.1), which survives a plugin whose vers line was edited
    % or removed.
    if isequal(v, [0 0 0])
        [~, leaf] = fileparts(fileparts(pluginFile));
        tok = regexp(leaf, '^TESA[_-]?([0-9]+(?:\.[0-9]+)*)$', 'tokens', 'once', 'ignorecase');
        if ~isempty(tok)
            v = parseVersion(tok{1});
            source = 'folder';
        end
    end
end

res = struct('v', v, 'source', source);
end

function v = parseVersion(str)
% '1.2' -> [1 2 0]; '1.1.1' -> [1 1 1]. Missing components are zero, so
% comparisons against a 3-element minimum always work elementwise.
parts = str2double(strsplit(str, '.'));
parts(isnan(parts)) = 0;
v = [parts(:)' 0 0 0];
v = v(1:3);
end
