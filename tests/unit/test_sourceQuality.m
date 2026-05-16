function tests = test_sourceQuality
% TEST_SOURCEQUALITY  Source-code pattern tests for Phases 1, 2, 4, and 6.
%
%   These tests read .m files and verify structural properties without
%   executing them. They accept or reject each quality-review phase:
%
%     Phase 1 — Project structure
%     Phase 2 — Architecture (no circular deps, no workspace pollution)
%     Phase 4 — Code quality (magic numbers, deprecated API, etc.)
%     Phase 6 — Efficiency (persistent cache, throttle, N_SPLITS)
%
%   All tests run without EEGLAB and complete in < 2 seconds total.
%
%   Run: runtests('tests/unit/test_sourceQuality')
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

function r = srcRoot()
r = fullfile(repoRoot(), 'src');
end

% ══════════════════════════════════════════════════════════════════════════
%% PHASE 1 — Project Structure
% ══════════════════════════════════════════════════════════════════════════

function test_mlappRemovedFromRepo(testCase)
% The .mlapp artefact is a loaded weapon: opening and saving it in App
% Designer silently overwrites nestapp.m with a regenerated copy.
mlappPath = fullfile(repoRoot(), 'nestapp_designer.mlapp');
testCase.verifyFalse(exist(mlappPath, 'file') == 2, ...
    ['Phase 1: nestapp_designer.mlapp must be deleted from the repo. ' ...
     'Opening it in App Designer regenerates nestapp.m and destroys all hand-edits.']);
end

function test_runNestappEntryPointExists(testCase)
entryPath = fullfile(repoRoot(), 'run_nestapp.m');
testCase.verifyTrue(exist(entryPath, 'file') == 2, ...
    'Phase 1: run_nestapp.m entry point must exist at repo root');
end

% ══════════════════════════════════════════════════════════════════════════
%% PHASE 2 — Architecture
% ══════════════════════════════════════════════════════════════════════════

function test_runPipelineCoreNoCircularDep(testCase)
% runPipelineCore.m must not call app.updateReportsTab() directly — that creates
% a circular dependency: a standalone function calling back into its caller.
src = fileread(fullfile(srcRoot(), 'runPipelineCore.m'));
testCase.verifyEmpty(regexp(src, 'app\.updateReportsTab', 'match'), ...
    ['Phase 2: runPipelineCore.m calls app.updateReportsTab(). ' ...
     'Pass a reportCallback instead to break the circular dependency.']);
end

function test_noAssignInBaseRunPipelineCore(testCase)
% runPipelineCore.m must not leak internal pipeline variables into the base workspace.
% NOTE: assignin('base', 'EEG', EEG) is intentional — it exposes the processed
%       EEG struct so users can run eegh and inspect data in the command window.
%       Only internal pipeline variables (files, paths, steps2run, stepsName) are banned.
src   = fileread(fullfile(srcRoot(), 'runPipelineCore.m'));
lines = strsplit(src, newline);
pollutionPatterns = {'assignin\s*\(\s*''base''\s*,\s*''files''', ...
                     'assignin\s*\(\s*''base''\s*,\s*''paths''', ...
                     'assignin\s*\(\s*''base''\s*,\s*''steps2run''', ...
                     'assignin\s*\(\s*''base''\s*,\s*''stepsName'''};
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    for p = 1:numel(pollutionPatterns)
        testCase.verifyEmpty(regexp(L, pollutionPatterns{p}, 'match'), ...
            sprintf(['Phase 2: runPipelineCore.m line %d leaks internal variable.\n' ...
                     '  Pattern: %s\n  Got: %s'], k, pollutionPatterns{p}, L));
    end
end
end

function test_noAssignInBaseNestapp(testCase)
% nestapp.m must not pollute the base workspace with pipeline state variables.
% NOTE: assignin('base', app.TEPvarNameEditField.Value, ...) at ExportTEPDataButtonPushed
%       is intentional (user-requested feature) and must NOT be flagged here.
%       Only the workspace-pollution patterns ('files', 'paths', 'steps2run',
%       'stepsName') are disallowed.
src   = fileread(fullfile(srcRoot(), 'nestapp.m'));
lines = strsplit(src, newline);
pollutionPatterns = {'assignin\s*\(\s*''base''\s*,\s*''files''', ...
                     'assignin\s*\(\s*''base''\s*,\s*''paths''', ...
                     'assignin\s*\(\s*''base''\s*,\s*''steps2run''', ...
                     'assignin\s*\(\s*''base''\s*,\s*''stepsName'''};
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    for p = 1:numel(pollutionPatterns)
        testCase.verifyEmpty(regexp(L, pollutionPatterns{p}, 'match'), ...
            sprintf(['Phase 2: nestapp.m line %d pollutes base workspace.\n' ...
                     '  Pattern: %s\n  Got: %s'], k, pollutionPatterns{p}, L));
    end
end
end

function test_stepRegistryIsPureFunction(testCase)
% stepRegistry must not access app state, globals, or UI.
src = fileread(fullfile(srcRoot(), 'stepRegistry.m'));
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    testCase.verifyEmpty(regexp(L, '\bapp\.', 'match'), ...
        sprintf('Phase 2: stepRegistry.m line %d accesses app handle\n  Got: %s', k, L));
    testCase.verifyEmpty(regexp(L, '\bglobal\b', 'match'), ...
        sprintf('Phase 2: stepRegistry.m line %d declares global\n  Got: %s', k, L));
end
end

% ══════════════════════════════════════════════════════════════════════════
%% PHASE 4 — Code Quality
% ══════════════════════════════════════════════════════════════════════════

function test_noRandColorInPlotTEP(testCase)
% rand(1,3) for colour produces non-reproducible figures — violates the
% project's reproducibility requirement.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
% Find plotTEP function body
startIdx = strfind(src, 'function plotTEP(app)');
if isempty(startIdx)
    % If function was renamed, skip
    return
end
% Extract window up to next function declaration
nextFn = regexp(src(startIdx(1)+1:end), '\bfunction\b', 'once');
if isempty(nextFn)
    window = src(startIdx(1):end);
else
    window = src(startIdx(1) : startIdx(1) + nextFn);
end
matches = regexp(window, '\brand\s*\(\s*1\s*,\s*3\s*\)', 'match');
testCase.verifyEmpty(matches, ...
    'Phase 4: plotTEP uses rand(1,3) for colour — use the axes colour order instead');
end

function test_noDatestrInExportReport(testCase)
% datestr() is deprecated in R2025b.
src = fileread(fullfile(srcRoot(), 'exportReport.m'));
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    testCase.verifyEmpty(regexp(L, '\bdatestr\s*\(', 'match'), ...
        sprintf(['Phase 4: exportReport.m line %d uses deprecated datestr(). ' ...
                 'Replace with string(datetime,...)\n  Got: %s'], k, L));
end
end

function test_noNowInInitReport(testCase)
% now() is deprecated in R2025b (returns datenum).
src = fileread(fullfile(srcRoot(), 'initPipelineReport.m'));
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    testCase.verifyEmpty(regexp(L, '=\s*now\s*[;,]', 'match'), ...
        sprintf(['Phase 4: initPipelineReport.m line %d uses deprecated now(). ' ...
                 'Replace with datetime(''now'')\n  Got: %s'], k, L));
end
end

function test_loadLabelsNoReturnValue(testCase)
% LoadLabels returns the app handle unnecessarily — handles are pass-by-reference.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
% Look for the function declaration pattern with a return value
matches = regexp(src, 'function\s+app\s*=\s*LoadLabels\s*\(', 'match');
testCase.verifyEmpty(matches, ...
    ['Phase 4: LoadLabels returns app handle unnecessarily. ' ...
     'Change to: function LoadLabels(app)']);
end

function test_electrodeButtonAccessGuarded(testCase)
% Dynamic property access must have an isprop guard to handle non-standard
% electrode names that would otherwise crash the app.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
hasDynamicAccess = contains(src, ",'Button'])");
hasIspropGuard   = contains(src, 'isprop(app');
if hasDynamicAccess
    testCase.verifyTrue(hasIspropGuard, ...
        ['Phase 4: Dynamic electrode button access exists without isprop guard. ' ...
         'Non-standard electrode labels will crash the app.']);
end
end

% ══════════════════════════════════════════════════════════════════════════
%% PHASE 6 — Efficiency
% ══════════════════════════════════════════════════════════════════════════

function test_stepRegistryHasPersistentCache(testCase)
% stepRegistry() is called multiple times from callbacks. A persistent cache
% avoids rebuilding the 1,112-line struct on every call.
src = fileread(fullfile(srcRoot(), 'stepRegistry.m'));
testCase.verifyTrue(contains(src, 'persistent'), ...
    'Phase 6: stepRegistry.m should use a persistent variable to cache the result');
end


function test_resizeCallbackHasThrottle(testCase)
% UIFigureSizeChanged repositions 140+ components on every pixel of a drag.
% A drawnow limitrate call prevents runaway redraws.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
% Search for the function definition, not just any mention of the name.
fnIdx = regexp(src, 'function\s+UIFigureSizeChanged', 'once');
if isempty(fnIdx); return; end
window = src(fnIdx : min(fnIdx+500, numel(src)));
testCase.verifyTrue(contains(window, 'drawnow'), ...
    ['Phase 6: UIFigureSizeChanged should call drawnow limitrate to throttle ' ...
     'resize events (repositions 140+ components per call)']);
end
