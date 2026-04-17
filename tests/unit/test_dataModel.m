function tests = test_dataModel
% TEST_DATAMODEL  Source-code tests for Phase 3: data model & state management.
%
%   Verifies that data model improvements from the code review have been
%   applied: boolean flag naming, cache invalidation, save-pipeline path,
%   and EEGraw capture documentation.
%
%   All tests use fileread() — no EEGLAB or GUI required.
%
%   Run: runtests('tests/unit/test_dataModel')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
addpath(repoRoot());
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── 3.2 SavePipeline uses uiputfile ──────────────────────────────────────

function test_savePipelineUsesUiputfile(testCase)
% uisave does not return the chosen path, making it impossible to clear
% pipelineDirty or update pipelineName after a save.
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
idx = strfind(src, 'SavePipelineButtonPushed');
testCase.verifyFalse(isempty(idx), 'SavePipelineButtonPushed must exist');
% Check within the callback body
window = src(idx(1) : min(idx(1)+1500, numel(src)));
testCase.verifyFalse(contains(window, 'uisave('), ...
    ['Phase 3: SavePipelineButtonPushed uses uisave which cannot return the ' ...
     'chosen path. Replace with uiputfile + save().']);
testCase.verifyTrue(contains(window, 'uiputfile'), ...
    'Phase 3: SavePipelineButtonPushed must use uiputfile to get the save path');
end

function test_savePipelineClearsDirtyFlag(testCase)
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
idx = strfind(src, 'SavePipelineButtonPushed');
testCase.verifyFalse(isempty(idx), 'SavePipelineButtonPushed must exist');
window = src(idx(1) : min(idx(1)+1500, numel(src)));
testCase.verifyTrue( ...
    contains(window, 'pipelineDirty') && ...
    (contains(window, '= false') || contains(window, '= 0')), ...
    'Phase 3: SavePipelineButtonPushed must clear pipelineDirty on success');
end

function test_savePipelineUpdatesPipelineName(testCase)
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
idx = strfind(src, 'SavePipelineButtonPushed');
testCase.verifyFalse(isempty(idx), 'SavePipelineButtonPushed must exist');
window = src(idx(1) : min(idx(1)+1500, numel(src)));
testCase.verifyTrue(contains(window, 'pipelineName'), ...
    'Phase 3: SavePipelineButtonPushed must update pipelineName after saving');
end

% ── 3.3 Visualizing EEG cache invalidation ───────────────────────────────

function test_selectData2ResetsEEGLoadedFlag(testCase)
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
idx = strfind(src, 'SelectDataButton_2Pushed');
testCase.verifyFalse(isempty(idx), 'SelectDataButton_2Pushed must exist');
window = src(idx(1) : min(idx(1)+2000, numel(src)));
% Must reset the loaded flag
testCase.verifyTrue( ...
    contains(window, 'EEG_SelectedTEPFiles_Loaded') && ...
    (contains(window, '= false') || contains(window, '= 0')), ...
    ['Phase 3: SelectDataButton_2Pushed must reset EEG_SelectedTEPFiles_Loaded. ' ...
     'Without this, new file selections silently reuse stale EEG data.']);
end

function test_selectData2ClearsEEGCache(testCase)
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
idx = strfind(src, 'SelectDataButton_2Pushed');
testCase.verifyFalse(isempty(idx), 'SelectDataButton_2Pushed must exist');
window = src(idx(1) : min(idx(1)+2000, numel(src)));
testCase.verifyTrue( ...
    contains(window, 'EEGofAllSelectedFiles') && ...
    (contains(window, '= {}') || contains(window, '= []')), ...
    ['Phase 3: SelectDataButton_2Pushed must clear EEGofAllSelectedFiles. ' ...
     'Stale entries remain after selecting fewer files.']);
end

% ── 3.5 Boolean flag naming ───────────────────────────────────────────────

function test_noNumericFlagTEPCreated(testCase)
% TEPCreated = 0 / 1 should be a logical false/true with a descriptive name.
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
% Declaration should use false/true, not 0/1
declMatch = regexp(src, 'TEPCreated\s*=\s*0\s*[;,]', 'match');
testCase.verifyEmpty(declMatch, ...
    ['Phase 3: TEPCreated = 0 uses numeric 0 as boolean. ' ...
     'Replace with isTEPPlotted = false (CLAUDE.md naming convention).']);
end

function test_noNumericFlagEEGLoaded(testCase)
% EEG_SelectedTEPFiles_Loaded = 0 should be a logical with an is_ prefix.
src = fileread(fullfile(repoRoot(), 'nestapp.m'));
declMatch = regexp(src, 'EEG_SelectedTEPFiles_Loaded\s*=\s*0\s*[;,]', 'match');
testCase.verifyEmpty(declMatch, ...
    ['Phase 3: EEG_SelectedTEPFiles_Loaded = 0 uses numeric 0 as boolean. ' ...
     'Replace with isEEGLoaded = false.']);
end

% ── 3.4 EEGraw capture is documented ─────────────────────────────────────

function test_EEGrawCaptureIsDocumented(testCase)
% The implicit contract "EEGraw is captured in the Epoching case, before
% artifact rejection" must be explained with a comment so future developers
% don't accidentally move or remove it.
src = fileread(fullfile(repoRoot(), 'runPipeline.m'));
% Find the EEGraw = EEG assignment
idx = regexp(src, 'EEGraw\s*=\s*EEG\s*[;,]', 'once');
testCase.verifyFalse(isempty(idx), ...
    'runPipeline.m must assign EEGraw = EEG somewhere (for computeTEPQuality Axis 2)');
% Check that there is a comment within 5 lines before the assignment
contextStart = max(1, idx - 400);
context = src(contextStart:idx);
testCase.verifyTrue(contains(context, '%'), ...
    ['Phase 3: EEGraw = EEG assignment has no explanatory comment. ' ...
     'Document the capture contract: when it runs and why it must precede rejection.']);
end
