% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_startupPicker
% TEST_STARTUPPICKER  A launched app offers the steps that are installed.
%
%   The end-state half of the cold-start regression. On a cold MATLAB the
%   picker used to open with 32 of 54 steps missing, because availableSteps
%   probes which() and nothing EEGLAB provides resolves until eeglab() has run
%   its plugin scan. startupFcn now initialises EEGLAB first; the ORDER is
%   pinned by a source check in tests/regression/test_startupStepAvailability,
%   and this pins the result.
%
%   Lives in tests/ui because it constructs the app: a real uifigure takes
%   focus, so this must not run in the default suite.
%
%   Run: runtests('tests/ui/test_startupPicker')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
if ~usejava('desktop')
    testCase.assumeFail('No display - skipping GUI test');
end
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── tests ─────────────────────────────────────────────────────────────────

function test_launchedAppOffersItsInstalledPluginSteps(testCase)
app = nestapp;   % setupOnce has already skipped this file if there is no display
testCase.addTeardown(@() delete(app));
drawnow;

global PLUGINLIST %#ok<GVMIS>
testCase.verifyNotEmpty(PLUGINLIST, ...
    'Launching the app must leave EEGLAB initialised');

offered = app.info.keys;
plugged = pluginBackedSteps();
testCase.assumeNotEmpty(plugged, 'No EEGLAB plugin steps installed here');
testCase.verifyEmpty(setdiff(plugged, offered), ...
    'Every installed plugin-backed step must appear in the picker');
end

function names = pluginBackedSteps()
% Registry steps whose requirements resolve into an EEGLAB plugins folder -
% i.e. exactly the ones a missed eeglab() init would have hidden.
marker = [filesep 'plugins' filesep];
reg    = stepRegistry();
names  = {};
for i = 1:numel(reg)
    if isfield(reg(i), 'listed') && ~isempty(reg(i).listed) && ~reg(i).listed
        continue
    end
    if ~stepAvailability(reg(i)); continue; end
    reqs = reg(i).requires;
    for j = 1:numel(reqs)
        % Format-specific loaders are not probed at list time, so a step
        % gated on one is not necessarily offered - skip those requirements.
        if isfield(reqs(j), 'fileExt') && ~isempty(reqs(j).fileExt)
            continue
        end
        w = which(reqs(j).fn);
        if ~isempty(w) && contains(w, marker)
            names{end+1} = reg(i).name; %#ok<AGROW>
            break
        end
    end
end
end
