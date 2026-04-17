function tests = test_stepRegistry
% TEST_STEPREGISTRY  Unit tests for stepRegistry schema and consistency.
%
%   Verifies that every step has required fields, params are well-formed,
%   and the registry is consistent with pipelineTemplates step names.
%
%   Run: runtests('tests/unit/test_stepRegistry')
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

% ── struct shape ──────────────────────────────────────────────────────────

function test_registryReturnsStructArray(testCase)
steps = stepRegistry();
testCase.verifyTrue(isstruct(steps), 'stepRegistry must return a struct');
testCase.verifyGreaterThan(numel(steps), 0, 'Must return at least one step');
end

function test_allStepsHaveRequiredFields(testCase)
steps = stepRegistry();
requiredFields = {'name', 'defaults', 'info', 'params'};
for i = 1:numel(steps)
    for fi = 1:numel(requiredFields)
        testCase.verifyTrue(isfield(steps(i), requiredFields{fi}), ...
            sprintf('Step %d missing field "%s"', i, requiredFields{fi}));
    end
end
end

function test_allStepNamesNonEmpty(testCase)
steps = stepRegistry();
for i = 1:numel(steps)
    testCase.verifyFalse(isempty(steps(i).name), ...
        sprintf('Step %d has empty name', i));
end
end

function test_allStepNamesUnique(testCase)
steps = stepRegistry();
names = {steps.name};
testCase.verifyEqual(numel(names), numel(unique(names)), ...
    'All step names must be unique');
end

function test_40StepsPresent(testCase)
% Registry should have 40 steps: the original 39 plus "Remove Bad Trials" added in M1.
steps = stepRegistry();
testCase.verifyEqual(numel(steps), 40, ...
    sprintf('Expected 40 steps, got %d', numel(steps)));
end

% ── defaults field ────────────────────────────────────────────────────────

function test_allDefaultsAreStructs(testCase)
steps = stepRegistry();
for i = 1:numel(steps)
    testCase.verifyTrue(isstruct(steps(i).defaults), ...
        sprintf('Step "%s" defaults must be a struct', steps(i).name));
end
end

% ── info field ────────────────────────────────────────────────────────────

function test_allInfoStringsNonEmpty(testCase)
steps = stepRegistry();
for i = 1:numel(steps)
    info = steps(i).info;
    testCase.verifyFalse(isempty(strtrim(info)), ...
        sprintf('Step "%s" has empty info string', steps(i).name));
end
end

function test_allInfoStringsAreText(testCase)
steps = stepRegistry();
for i = 1:numel(steps)
    info = steps(i).info;
    testCase.verifyTrue(ischar(info) || isstring(info), ...
        sprintf('Step "%s" info must be char or string', steps(i).name));
end
end

% ── params field ──────────────────────────────────────────────────────────

function test_paramsIsStructArrayOrEmpty(testCase)
steps = stepRegistry();
for i = 1:numel(steps)
    p = steps(i).params;
    testCase.verifyTrue(isstruct(p) || isempty(p), ...
        sprintf('Step "%s" params must be struct array or empty', steps(i).name));
end
end

function test_paramStructsHaveKeyAndFriendlyName(testCase)
steps = stepRegistry();
for i = 1:numel(steps)
    p = steps(i).params;
    if isempty(p); continue; end
    for pi = 1:numel(p)
        testCase.verifyTrue(isfield(p, 'key'), ...
            sprintf('Step "%s" param %d missing "key"', steps(i).name, pi));
        testCase.verifyTrue(isfield(p, 'friendlyName'), ...
            sprintf('Step "%s" param %d missing "friendlyName"', steps(i).name, pi));
    end
end
end

% ── consistency with pipelineTemplates ───────────────────────────────────

function test_allTemplateStepNamesInRegistry(testCase)
% Every step referenced by a template must exist in the registry.
steps     = stepRegistry();
allNames  = {steps.name};
templates = pipelineTemplates();
for ti = 1:numel(templates)
    t = templates(ti);
    for si = 1:numel(t.steps)
        testCase.verifyTrue(ismember(t.steps{si}, allNames), ...
            sprintf('Template "%s" step "%s" not in stepRegistry', ...
                t.name, t.steps{si}));
    end
end
end

% ── key steps present ─────────────────────────────────────────────────────

function test_loadDataStepPresent(testCase)
steps = stepRegistry();
names = {steps.name};
testCase.verifyTrue(ismember('Load Data', names), '"Load Data" must be in registry');
end

function test_saveNewSetStepPresent(testCase)
steps = stepRegistry();
names = {steps.name};
testCase.verifyTrue(ismember('Save New Set', names), '"Save New Set" must be in registry');
end

function test_epochingStepPresent(testCase)
steps = stepRegistry();
names = {steps.name};
testCase.verifyTrue(ismember('Epoching', names), '"Epoching" must be in registry');
end
