
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_stepCharacterization
% TEST_STEPCHARACTERIZATION  Pin what each pipeline step currently does.
%
%   These are characterization tests, not correctness tests. They do not
%   assert that a step is right - they assert that it still does exactly what
%   it did when the golden was recorded. That is the safety net for
%   restructuring the step layer: most of these steps had no test naming them
%   at all, and their output is plausible either way, so a refactor could
%   silently change results with nothing to catch it.
%
%   Each case runs a step through the REAL dispatch path (processOneFile on a
%   saved .set), because the dispatch is what a refactor rewrites. Calling the
%   underlying function directly would test the part that is not changing.
%
%   Goldens live in tests/characterization/golden/<step>.json - JSON, not
%   .mat, so that a changed golden is readable in a diff. If a test fails,
%   read the diff before regenerating: the whole point is that a change here
%   is a decision, not a formality.
%
%   To (re)record after an INTENDED behaviour change:
%       recordGoldens            % all cases
%       recordGoldens('Step A')  % one case
%
%   Run: runtests('tests/characterization/test_stepCharacterization')
tests = functiontests(localfunctions);
end

% ── setup ───────────────────────────────────────────────────────────────────

function setupOnce(testCase)
if ~exist('eeglab', 'file')
    testCase.assumeFail('EEGLAB not on path - skipping characterization tests');
end
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
addpath(fullfile(r, 'tests', 'helpers'));

global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>
evalc('[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab(''nogui'');');

testCase.TestData.tmpDir = tempname;
mkdir(testCase.TestData.tmpDir);
testCase.addTeardown(@() rmdir(testCase.TestData.tmpDir, 's'));
end

function r = repoRoot()
r = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function d = goldenDir()
d = fullfile(fileparts(mfilename('fullpath')), 'golden');
if ~exist(d, 'dir'); mkdir(d); end
end

% The case table lives in characterizationCases.m, shared with recordGoldens,
% so a step cannot be pinned under one configuration and verified under
% another.

% ── the test ────────────────────────────────────────────────────────────────

function test_stepsMatchRecordedBehaviour(testCase)
cases = characterizationCases();
reg   = stepRegistry();
failures = {};

for i = 1:size(cases, 1)
    name      = cases{i, 1};
    kind      = cases{i, 2};
    overrides = cases{i, 3};
    prereqs   = cases{i, 4};

    if ~any(strcmp({reg.name}, name))
        failures{end+1} = sprintf('%s: not in the registry', name); %#ok<AGROW>
        continue
    end

    try
        actual = runStepDigest(testCase, name, kind, overrides, reg, prereqs);
    catch err
        failures{end+1} = sprintf('%s: errored - %s', name, err.message); %#ok<AGROW>
        continue
    end

    gf = fullfile(goldenDir(), [safeName(name) '.json']);
    if ~exist(gf, 'file')
        failures{end+1} = sprintf(['%s: no golden recorded. Run ' ...
            'recordGoldens(''%s'') to create it.'], name, name); %#ok<AGROW>
        continue
    end

    expected = jsondecode(fileread(gf));
    [same, why] = digestsMatch(expected, actual);
    if ~same
        failures{end+1} = sprintf('%s: behaviour changed - %s', name, why); %#ok<AGROW>
    end
end

testCase.verifyEmpty(failures, sprintf('\n  %s\n', strjoin(failures, sprintf('\n  '))));
end

function test_fixturesAreDeterministic(testCase)
% The goldens are meaningless if the input drifts between runs.
for kind = {'continuous', 'epoched', 'epochedPulses', 'epochedICA'}
    a = eegDigest(charFixture(kind{1}));
    b = eegDigest(charFixture(kind{1}));
    testCase.verifyTrue(isequal(a, b), ...
        sprintf('charFixture(''%s'') is not reproducible', kind{1}));
end
end

% ── machinery ───────────────────────────────────────────────────────────────

function d = runStepDigest(testCase, name, kind, overrides, reg, prereqs)
% Build the fixture, run [Load Data, <step>] through processOneFile, digest
% the resulting EEG. Uses the global EEG that processOneFile operates on.
global EEG %#ok<GVMIS>

fx      = charFixture(kind);
fname   = [safeName(name) '.set'];
tmpDir  = testCase.TestData.tmpDir;
setPath = fullfile(tmpDir, fname);
evalc('pop_saveset(fx, ''filename'', fname, ''filepath'', tmpDir);');

spec = makePipelineStep('Load Data', reg);
for j = 1:numel(prereqs)
    spec(end+1) = makePipelineStep(prereqs{j}, reg); %#ok<AGROW>
end
step = makePipelineStep(name, reg);
keys = fieldnames(overrides);
for k = 1:numel(keys)
    step.params.(keys{k}) = overrides.(keys{k});
end
spec(end+1) = step;

rng(42, 'twister');   % any step with a stochastic component
opts = struct('pipelineName', 'characterization', 'fileIndex', 1);
evalc('processOneFile(spec, setPath, opts);');

d = eegDigest(EEG);
end

function [same, why] = digestsMatch(expected, actual)
% Compare field by field and name the first difference - a bare "not equal"
% on a 20-field struct is not a useful failure message.
same = true; why = '';
fn = fieldnames(actual);
for i = 1:numel(fn)
    f = fn{i};
    if ~isfield(expected, f)
        same = false; why = sprintf('golden has no field "%s"', f); return
    end
    a = actual.(f); e = expected.(f);
    if numel(a) ~= numel(e) || ~all(abs(double(a(:)) - double(e(:))) < 1e-6 | ...
            (isnan(double(a(:))) & isnan(double(e(:)))))
        same = false;
        why = sprintf('%s: expected %s, got %s', f, brief(e), brief(a));
        return
    end
end
end

function s = brief(v)
v = double(v(:))';
if isempty(v); s = '[]'; return; end
if numel(v) > 4
    s = sprintf('[%.6g %.6g ... %.6g] (%d vals)', v(1), v(2), v(end), numel(v));
else
    s = ['[' strjoin(arrayfun(@(x) sprintf('%.6g', x), v, 'UniformOutput', false), ' ') ']'];
end
end

function s = safeName(name)
s = regexprep(name, '[^A-Za-z0-9]+', '_');
s = regexprep(s, '_+$', '');
end
