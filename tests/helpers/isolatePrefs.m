% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function isolatePrefs(testCase, keys)
% ISOLATEPREFS  Detach a test from the user's real preferences, then restore.
%   ISOLATEPREFS(testCase, 'roiPresets')
%   ISOLATEPREFS(testCase, {'lastPipelineFolder', 'recentPipelines'})
%
%   Clears the named nestapp preferences for the duration of the test and puts
%   the real values back on teardown - including removing one the test created
%   where none existed, which is the case a naive save/restore gets wrong.
%
%   PREFERENCES ARE LIVE USER STATE, and a test touching them is wrong in both
%   directions. It READS the developer's own settings, so "the dropdown opens
%   on the F3 cluster" is false on any machine where someone saved a preset;
%   and it WRITES them, which is not something a test suite may do to
%   somebody's configuration. The app's own save handlers set
%   lastPipelineFolder and push onto recentPipelines, so running the GUI suite
%   without this quietly edits the user's recent-files menu.
%
%   GENERALISED FROM isolateRoiPresets AT THE CUTOVER. That helper did exactly
%   this for one hardcoded key, and the eeglab_gui tests had grown a private
%   second copy for two different keys - one fact, two implementations, which
%   is the shape this rewrite keeps finding and removing. Taking the keys as an
%   argument makes it one.
%
%   See also: scratchDir, roiPresets, saveRoiPreset

if ischar(keys) || isstring(keys); keys = cellstr(keys); end

for k = 1:numel(keys)
    key   = keys{k};
    had   = ispref('nestapp', key);
    saved = [];
    if had; saved = getpref('nestapp', key); end
    testCase.addTeardown(@() restoreOne(key, had, saved));
    if had
        rmpref('nestapp', key);
    end
end
end

function restoreOne(key, had, saved)
if had
    setpref('nestapp', key, saved);
elseif ispref('nestapp', key)
    % The test created a preference the user did not have. Leaving it behind
    % would be the suite writing to their settings by omission.
    rmpref('nestapp', key);
end
end
