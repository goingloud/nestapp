
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
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

function p = nestappFile()
p = fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m');
end

% ── 3.2 SavePipeline uses uiputfile ──────────────────────────────────────

function test_savePipelineUsesUiputfile(testCase)
% uisave does not return the chosen path, making it impossible to clear
% pipelineDirty or update pipelineName after a save.
src = fileread(nestappFile());
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
src = fileread(nestappFile());
idx = strfind(src, 'SavePipelineButtonPushed');
testCase.verifyFalse(isempty(idx), 'SavePipelineButtonPushed must exist');
window = src(idx(1) : min(idx(1)+1500, numel(src)));
testCase.verifyTrue( ...
    contains(window, 'pipelineDirty') && ...
    (contains(window, '= false') || contains(window, '= 0')), ...
    'Phase 3: SavePipelineButtonPushed must clear pipelineDirty on success');
end

function test_savePipelineUpdatesPipelineName(testCase)
src = fileread(nestappFile());
idx = strfind(src, 'SavePipelineButtonPushed');
testCase.verifyFalse(isempty(idx), 'SavePipelineButtonPushed must exist');
window = src(idx(1) : min(idx(1)+1500, numel(src)));
testCase.verifyTrue(contains(window, 'pipelineName'), ...
    'Phase 3: SavePipelineButtonPushed must update pipelineName after saving');
end
