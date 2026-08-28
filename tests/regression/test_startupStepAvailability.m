% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_startupStepAvailability
% TEST_STARTUPSTEPAVAILABILITY  The picker must not hide installed steps.
%
%   On a cold MATLAB the app used to open with most of its steps missing.
%   populateStepsTree asks availableSteps what is installed, availableSteps
%   probes which() for each requirement, and nothing EEGLAB provides resolves
%   until eeglab() has run its plugin scan - which startupFcn did not do, and
%   which even loadPrefs' addpath of the EEGLAB root does not accomplish. 32
%   of 54 listed steps were withheld as "unavailable" on a stock install.
%
%   The order check below is the assertion that would have failed then. It is
%   a source check because the fault is a sequence inside one method: by the
%   time a launched app can be inspected, EEGLAB is up and the tree is right,
%   and a suite running in a session that already has EEGLAB loaded cannot
%   reproduce the cold start at all. The live checks pin the end state.
%
%   Run: runtests('tests/regression/test_startupStepAvailability')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function requireDesktop(testCase)
if ~usejava('desktop')
    testCase.assumeFail('No display - skipping GUI test');
end
end

% ── the ordering that broke ───────────────────────────────────────────────

function test_eeglabIsInitialisedBeforeTheTreeIsBuilt(testCase)
src = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m'));
body = startupBody(testCase, src);

iInit = strfind(body, 'initEeglab(app)');
iTree = strfind(body, 'populateStepsTree(app)');
testCase.assertNotEmpty(iInit, 'startupFcn must initialise EEGLAB');
testCase.assertNotEmpty(iTree, 'startupFcn must build the step tree');
testCase.verifyLessThan(iInit(1), iTree(1), ...
    'EEGLAB must be up before the picker asks which() what is installed');

% initEeglab finds the EEGLAB folder through the saved preference, so the
% prefs have to be applied before it runs.
iPrefs = strfind(body, 'loadPrefs(app)');
testCase.assertNotEmpty(iPrefs, 'startupFcn must apply saved preferences');
testCase.verifyLessThan(iPrefs(1), iInit(1), ...
    'The EEGLAB path pref must be applied before EEGLAB is initialised');
testCase.verifyNumElements(iPrefs, 1, ...
    'One loadPrefs call - a second, later one would mask a bad order');
end

function body = startupBody(testCase, src)
% The text of startupFcn, up to the next method.
i = strfind(src, 'function startupFcn(app)');
testCase.assertNotEmpty(i, 'startupFcn not found in nestapp.m');
rest = src(i(1):end);
j = strfind(rest, sprintf('\n        function '));
if isempty(j)
    body = rest;
else
    body = rest(1:j(1));
end
end

% ── the end state ─────────────────────────────────────────────────────────

function test_launchedAppOffersItsInstalledPluginSteps(testCase)
requireDesktop(testCase);
app = nestapp;
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
