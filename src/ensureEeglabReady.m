% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [ok, msg] = ensureEeglabReady()
% ENSUREEEGLABREADY  Put EEGLAB and its plugins on the path, once per session.
%   [ok, msg] = ENSUREEEGLABREADY() runs eeglab('nogui') if it has not already
%   run in this MATLAB session, and returns whether EEGLAB is now usable. msg
%   is '' when ok, and a user-facing explanation when not.
%
%   Why this exists: adding the EEGLAB root to the path is NOT enough. EEGLAB
%   ships its functions in subfolders and its plugins in plugins/<name>, and
%   nothing resolves until eeglab() itself runs the path setup and the plugin
%   scan. On a cold MATLAB, with only the root added:
%
%       which('pop_loadset')          -> ''
%       which('pop_tesa_filtbutter')  -> ''
%
%   That matters because availableSteps decides what the picker offers by
%   probing which() for each step's requirements. Asking before EEGLAB has
%   initialised hides every plugin-backed step - 32 of 54 on a stock install -
%   and hides them the same way it hides a genuinely missing plugin, so the
%   user is told nothing is installed when everything is.
%
%   Readiness is judged by the PLUGINLIST global rather than by remembering
%   that we called eeglab: PLUGINLIST is written by the plugin scan, so it is
%   the state we actually depend on, and it stays correct when EEGLAB was
%   initialised by something other than us (a prior run, the console, a test).
%
%   The call is silenced with evalc: eeglab('nogui') prints a banner and a
%   line per plugin, which is noise in a GUI session and drowns the app's own
%   startup logging.
%
%   See also: availableSteps, stepAvailability, loadPrefs, runPipelineCore

ok  = true;
msg = '';

global PLUGINLIST %#ok<GVMIS>
if ~isempty(PLUGINLIST)
    return
end

% The Preferences path is where the user points nestapp at their install; it
% is only added if EEGLAB is not already reachable, so an eeglab the user put
% on the path themselves wins over a stale pref.
if isempty(which('eeglab'))
    eeglabPath = getpref('nestapp', 'eeglabPath', '');
    if ~isempty(eeglabPath) && isfolder(eeglabPath)
        addpath(eeglabPath);
    end
end

if isempty(which('eeglab'))
    ok  = false;
    msg = ['EEGLAB was not found on the MATLAB path. Set its folder in ' ...
           'File > Preferences; until then, steps that need EEGLAB or its ' ...
           'plugins cannot be offered.'];
    return
end

try
    evalc('eeglab nogui');
catch ME
    ok  = false;
    msg = sprintf(['EEGLAB could not be initialised: %s\nVerify the EEGLAB ' ...
                   'path in File > Preferences.'], ME.message);
end
end
