function tests = test_pipelineTemplates
% TEST_PIPELINETEMPLATES  Unit tests for pipelineTemplates.
%
%   Verifies that each template has the correct struct shape, that all step
%   names exist in stepRegistry, and that key ordering constraints hold.
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

function allNames = validStepNames()
% Return the canonical list of step names from stepRegistry.
steps = stepRegistry();
allNames = {steps.name};
end

% ── struct shape ─────────────────────────────────────────────────────────

function test_returnStructArray(testCase)
templates = pipelineTemplates();
testCase.verifyTrue(isstruct(templates), 'pipelineTemplates must return a struct');
testCase.verifyGreaterThan(numel(templates), 0, 'Must return at least one template');
end

function test_allTemplatesHaveRequiredFields(testCase)
templates = pipelineTemplates();
for i = 1:numel(templates)
    t = templates(i);
    testCase.verifyTrue(isfield(t, 'name'),      sprintf('Template %d missing name', i));
    testCase.verifyTrue(isfield(t, 'steps'),     sprintf('Template %d missing steps', i));
    testCase.verifyTrue(isfield(t, 'overrides'), sprintf('Template %d missing overrides', i));
end
end

function test_threeTemplatesExist(testCase)
templates = pipelineTemplates();
testCase.verifyEqual(numel(templates), 3, 'Expected exactly 3 templates');
end

% ── template names ───────────────────────────────────────────────────────

function test_tmsEEGTemplateExists(testCase)
templates = pipelineTemplates();
names = {templates.name};
testCase.verifyTrue(any(contains(names, 'TMS-EEG')), ...
    'Must have a TMS-EEG template');
end

function test_restingStateTemplateExists(testCase)
templates = pipelineTemplates();
names = {templates.name};
testCase.verifyTrue(any(contains(names, 'Resting')), ...
    'Must have a Resting-State template');
end

function test_minimalTemplateExists(testCase)
templates = pipelineTemplates();
names = {templates.name};
testCase.verifyTrue(any(contains(names, 'Minimal')), ...
    'Must have a Minimal template');
end

% ── step validity ─────────────────────────────────────────────────────────

function test_allTmsEEGStepsInRegistry(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'TMS-EEG'));
allNames = validStepNames();
for i = 1:numel(t.steps)
    testCase.verifyTrue(ismember(t.steps{i}, allNames), ...
        sprintf('TMS-EEG step "%s" not found in stepRegistry', t.steps{i}));
end
end

function test_allRestingStateStepsInRegistry(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Resting'));
allNames = validStepNames();
for i = 1:numel(t.steps)
    testCase.verifyTrue(ismember(t.steps{i}, allNames), ...
        sprintf('Resting-State step "%s" not found in stepRegistry', t.steps{i}));
end
end

function test_allMinimalStepsInRegistry(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Minimal'));
allNames = validStepNames();
for i = 1:numel(t.steps)
    testCase.verifyTrue(ismember(t.steps{i}, allNames), ...
        sprintf('Minimal step "%s" not found in stepRegistry', t.steps{i}));
end
end

% ── step counts ──────────────────────────────────────────────────────────

function test_tmsEEGHasAtLeast5Steps(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'TMS-EEG'));
testCase.verifyGreaterThanOrEqual(numel(t.steps), 5, ...
    'TMS-EEG template must have at least 5 steps');
end

function test_restingStateHasAtLeast5Steps(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Resting'));
testCase.verifyGreaterThanOrEqual(numel(t.steps), 5, ...
    'Resting-State template must have at least 5 steps');
end

function test_minimalHasAtLeast3Steps(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Minimal'));
testCase.verifyGreaterThanOrEqual(numel(t.steps), 3, ...
    'Minimal template must have at least 3 steps');
end

% ── overrides shape ───────────────────────────────────────────────────────

function test_overridesLengthMatchesSteps(testCase)
templates = pipelineTemplates();
for i = 1:numel(templates)
    t = templates(i);
    testCase.verifyEqual(numel(t.overrides), numel(t.steps), ...
        sprintf('Template "%s": overrides length (%d) must equal steps length (%d)', ...
            t.name, numel(t.overrides), numel(t.steps)));
end
end

% ── key ordering constraints ─────────────────────────────────────────────

function test_tmsEEGLoadDataIsFirst(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'TMS-EEG'));
testCase.verifyEqual(t.steps{1}, 'Load Data', ...
    'TMS-EEG template must start with Load Data');
end

function test_tmsEEGSaveNewSetIsLast(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'TMS-EEG'));
testCase.verifyEqual(t.steps{end}, 'Save New Set', ...
    'TMS-EEG template must end with Save New Set');
end

function test_tmsEEGFindPulsesBeforeRemove(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'TMS-EEG'));
findIdx   = find(strcmp(t.steps, 'Find TMS Pulses (TESA)'),    1);
removeIdx = find(strcmp(t.steps, 'Remove TMS Artifacts (TESA)'), 1);
testCase.verifyTrue(~isempty(findIdx) && ~isempty(removeIdx), ...
    'Must have both Find and Remove TMS Pulses steps');
testCase.verifyLessThan(findIdx, removeIdx, ...
    'Find TMS Pulses must come before Remove TMS Artifacts');
end

function test_restingStateHasLoadDataFirst(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Resting'));
testCase.verifyEqual(t.steps{1}, 'Load Data', ...
    'Resting-State template must start with Load Data');
end

% ── parameter overrides ───────────────────────────────────────────────────

function test_restingStateHasHPFOverride(testCase)
% HPF should be 0.5 Hz (wider than default 1 Hz for resting-state).
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Resting'));
% Find the Frequency Filter step
filterIdx = find(strcmp(t.steps, 'Frequency Filter'), 1);
testCase.verifyFalse(isempty(filterIdx), 'Resting-State must have Frequency Filter step');
ov = t.overrides{filterIdx};
testCase.verifyTrue(isfield(ov, 'locutoff'), 'HPF override must set locutoff');
testCase.verifyEqual(ov.locutoff, 0.5, 'Resting-State HPF should be 0.5 Hz');
end

function test_minimalHasHPFOverride(testCase)
templates = pipelineTemplates();
t = templates(contains({templates.name}, 'Minimal'));
filterIdx = find(strcmp(t.steps, 'Frequency Filter'), 1);
testCase.verifyFalse(isempty(filterIdx), 'Minimal must have Frequency Filter step');
ov = t.overrides{filterIdx};
testCase.verifyTrue(isfield(ov, 'locutoff'), 'HPF override must set locutoff');
testCase.verifyEqual(ov.locutoff, 0.5, 'Minimal HPF should be 0.5 Hz');
end
