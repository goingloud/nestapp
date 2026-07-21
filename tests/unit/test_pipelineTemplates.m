
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_pipelineTemplates
% TEST_PIPELINETEMPLATES  Unit tests for the built-in pipeline template .mat files.
%
%   Verifies that each template has the correct data shape, that all step
%   names exist in stepRegistry, and that key ordering constraints hold.
%   Templates are stored as .mat files in src/templates/ — this test suite
%   loads them directly without EEGLAB.
%
%   Run: runtests('tests/unit/test_pipelineTemplates')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function templates = loadTemplates(testCase)
% Load all .mat files from src/templates/ and return a struct array.
% v3 format: pipelineName (string), spec (struct array with .name/.params), version.
r        = repoRoot();
matFiles = dir(fullfile(r, 'src', 'templates', '*.mat'));
testCase.verifyFalse(isempty(matFiles), 'No template .mat files found in src/templates/');
templates = struct('name', {}, 'steps', {}, 'spec', {});
for i = 1:numel(matFiles)
    data = load(fullfile(matFiles(i).folder, matFiles(i).name));
    templates(i).name  = data.pipelineName;
    templates(i).steps = {data.spec.name};
    templates(i).spec  = data.spec;
end
end

% ── .mat file shape ────────────────────────────────────────────────────────

function test_templatesCanBeLoaded(testCase)
templates = loadTemplates(testCase);
testCase.verifyGreaterThan(numel(templates), 0, 'Must have at least one template');
end

function test_allTemplatesHaveRequiredFields(testCase)
templates = loadTemplates(testCase);
for i = 1:numel(templates)
    testCase.verifyFalse(isempty(templates(i).name), ...
        sprintf('Template %d: pipelineName must not be empty', i));
    testCase.verifyFalse(isempty(templates(i).steps), ...
        sprintf('Template %d: spec must not be empty', i));
end
end

function test_fourTemplatesShipped(testCase)
% TESA, resting-state, minimal ERP, AARATEP. ARTIST was removed (entirely
% hand-rolled from the paper, no public reference implementation) and the
% Quality-Gates variant was redundant with the Quality Gate step itself.
templates = loadTemplates(testCase);
testCase.verifyEqual(numel(templates), 4, ...
    'Expected exactly four shipped templates');
end

function test_tmsEEGTemplateExists(testCase)
templates = loadTemplates(testCase);
testCase.verifyTrue(any(strcmp({templates.name}, 'TMS-EEG / TEP (TESA)')), ...
    'Must have a TMS-EEG template');
end

function test_restingStateTemplateExists(testCase)
templates = loadTemplates(testCase);
testCase.verifyTrue(any(contains({templates.name}, 'Resting')), ...
    'Must have a Resting-State template');
end

function test_minimalTemplateExists(testCase)
templates = loadTemplates(testCase);
testCase.verifyTrue(any(contains({templates.name}, 'Minimal')), ...
    'Must have a Minimal template');
end

% Note: "all steps exist in the registry" is covered for ALL templates by
% test_stepRegistry/test_allTemplateStepNamesInRegistry, so per-template
% step-validity and minimum-step-count checks were removed as redundant.

% ── key ordering constraints ─────────────────────────────────────────────

function test_tmsEEGLoadDataIsFirst(testCase)
templates = loadTemplates(testCase);
t = templates(strcmp({templates.name}, 'TMS-EEG / TEP (TESA)'));
testCase.verifyEqual(t.steps{1}, 'Load Data', ...
    'TMS-EEG template must start with Load Data');
end

function test_tmsEEGSaveNewSetIsLast(testCase)
templates = loadTemplates(testCase);
t = templates(strcmp({templates.name}, 'TMS-EEG / TEP (TESA)'));
testCase.verifyEqual(t.steps{end}, 'Save New Set', ...
    'TMS-EEG template must end with Save New Set');
end

function test_tmsEEGFindPulsesBeforeRemove(testCase)
templates = loadTemplates(testCase);
t = templates(strcmp({templates.name}, 'TMS-EEG / TEP (TESA)'));
findIdx   = find(strcmp(t.steps, 'Find TMS Pulses (TESA)'),      1);
removeIdx = find(strcmp(t.steps, 'Remove TMS Artifacts (TESA)'), 1);
testCase.verifyTrue(~isempty(findIdx) && ~isempty(removeIdx), ...
    'Must have both Find TMS Pulses and Remove TMS Artifacts steps');
testCase.verifyLessThan(findIdx, removeIdx, ...
    'Find TMS Pulses must come before Remove TMS Artifacts');
end

function test_restingStateHasLoadDataFirst(testCase)
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'Resting'));
testCase.verifyEqual(t.steps{1}, 'Load Data', ...
    'Resting-State template must start with Load Data');
end

% ── parameter values ───────────────────────────────────────────────────────

function test_restingStateHasFrequencyFilter(testCase)
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'Resting'));
filterIdx = find(strcmp(t.steps, 'Frequency Filter'), 1);
testCase.verifyFalse(isempty(filterIdx), 'Resting-State must have Frequency Filter step');
locVal = t.spec(filterIdx).params.locutoff;
testCase.verifyGreaterThan(locVal, 0, 'Resting-State HPF locutoff must be > 0 Hz');
end

function test_minimalHasFrequencyFilter(testCase)
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'Minimal'));
filterIdx = find(strcmp(t.steps, 'Frequency Filter'), 1);
testCase.verifyFalse(isempty(filterIdx), 'Minimal must have Frequency Filter step');
locVal = t.spec(filterIdx).params.locutoff;
testCase.verifyGreaterThan(locVal, 0, 'Minimal HPF locutoff must be > 0 Hz');
end

function test_aaratepIsASingleOrchestratorStep(testCase)
% The template calls upstream's pipeline rather than reproducing it. If it
% ever grows the old per-stage steps back, the fidelity burden comes with
% them - so assert the handover explicitly.
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'AARATEP'));
testCase.verifyTrue(ismember('AARATEP Pipeline (whole)', t.steps), ...
    'The AARATEP template must call the orchestrator step');
testCase.verifyLessThan(numel(t.steps), 8, ...
    'It should be a handover, not a reproduction of the pipeline');
end

function test_aaratepFindsPulsesBeforeHandingOver(testCase)
% The orchestrator matches pulse events by type; it does not detect them. So
% pulse detection has to happen first, and the labels have to agree - a
% mismatch here would fail deep inside upstream on the first file.
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'AARATEP'));
findIdx = find(strcmp(t.steps, 'Find TMS Pulses (TESA)'), 1);
orchIdx = find(strcmp(t.steps, 'AARATEP Pipeline (whole)'), 1);
testCase.assertNotEmpty(findIdx, 'AARATEP must find pulses before handing over');
testCase.assertNotEmpty(orchIdx);
testCase.verifyLessThan(findIdx, orchIdx);

label = t.spec(findIdx).params.tmslabel;
events = cellstr(t.spec(orchIdx).params.pulseEvents);
testCase.verifyTrue(ismember(label, events), sprintf( ...
    ['The event label written by Find TMS Pulses (%s) must be one the ' ...
     'orchestrator looks for (%s)'], label, strjoin(events, ', ')));
end

function test_aaratepDoesNotEpochBeforeHandingOver(testCase)
% Upstream epochs itself and asserts on continuous input. An Epoching step in
% this template would break the run - and the dispatch guards for it, but the
% template should not be building that situation in the first place.
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'AARATEP'));
testCase.verifyFalse(ismember('Epoching', t.steps), ...
    'The orchestrator does its own epoching and needs continuous data');
end

function test_aaratepTemplateExists(testCase)
templates = loadTemplates(testCase);
testCase.verifyTrue(any(contains({templates.name}, 'AARATEP')), ...
    'Must have an AARATEP template');
end

function test_aaratepLoadDataIsFirst(testCase)
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'AARATEP'));
testCase.verifyEqual(t.steps{1}, 'Load Data', ...
    'AARATEP template must start with Load Data');
end

function test_aaratepSaveNewSetIsLast(testCase)
templates = loadTemplates(testCase);
t = templates(contains({templates.name}, 'AARATEP'));
testCase.verifyEqual(t.steps{end}, 'Save New Set', ...
    'AARATEP template must end with Save New Set');
end

function test_cleanlineNeverAfterEpoching(testCase)
templates = loadTemplates(testCase);
for i = 1:numel(templates)
    t = templates(i);
    epochIdx = find(strcmp(t.steps, 'Epoching'), 1);
    cleanIdx = find(strcmp(t.steps, 'Frequency Filter (CleanLine)'), 1);
    if isempty(epochIdx) || isempty(cleanIdx)
        continue
    end
    testCase.verifyLessThan(cleanIdx, epochIdx, sprintf( ...
        ['Template "%s" runs CleanLine after Epoching. CleanLine ' ...
         'uses sliding-window spectral fits and prompts when its ' ...
         'window spans trial boundaries. Use Frequency Filter (TESA) ' ...
         'bandstop 58-62 Hz on epoched data instead.'], t.name));
end
end

% Note: the no-CleanLine-after-Epoching guarantee is covered for ALL
% templates by test_cleanlineNeverAfterEpoching above; the per-template
% ARTIST/AARATEP CleanLine checks were removed as redundant.

% ── Paper-fidelity audit guards ──────────────────────────────────────────

