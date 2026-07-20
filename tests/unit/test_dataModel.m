
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

function body = functionBody(src, name)
% Return a method's full body text, from its declaration to the start of the
% next method at class-method indent (8 spaces). '' when not found.
%
% Prefer this over src(idx:idx+N): a fixed character budget silently
% truncates as a method grows, so an assertion can start passing or failing
% for reasons unrelated to the behaviour it is checking.
body = '';
decl = ['function ' name '('];
idx  = strfind(src, decl);
if isempty(idx); return; end
rest = src(idx(1):end);
% Skip the declaration line so its own "function" keyword isn't the match.
nl   = find(rest == newline, 1);
if isempty(nl); body = rest; return; end
stop = regexp(rest(nl:end), '\n {8}function ', 'once');
if isempty(stop)
    body = rest;
else
    body = rest(1 : nl + stop - 1);
end
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

% ── 3.3 Visualizing EEG cache invalidation ───────────────────────────────

% These two assert an invariant - picking a new file set must invalidate
% everything derived from the previous one, or the Visualize tab silently
% plots the old files' EEG. They used to scan a fixed 2000-character window
% after the handler and require the assignments to appear inline. That broke
% when the invalidation was (correctly) moved into applyTEPSelection, a
% helper shared by the listbox, Select-all and new-file-set paths so they
% cannot diverge: the code was right, the window just could not reach it.
% Follow the delegation chain instead, and read whole function bodies rather
% than a character budget that silently truncates as methods grow.

function test_selectData2InvalidatesViaSharedHelper(testCase)
src = fileread(nestappFile());
handler = functionBody(src, 'SelectDataButton_2Pushed');
testCase.verifyNotEmpty(handler, 'SelectDataButton_2Pushed must exist');
testCase.verifyTrue(contains(handler, 'setTEPFileList'), ...
    ['SelectDataButton_2Pushed must route a new file set through ' ...
     'setTEPFileList, which is what invalidates the derived EEG state.']);

setList = functionBody(src, 'setTEPFileList');
testCase.verifyNotEmpty(setList, 'setTEPFileList must exist');
testCase.verifyTrue(contains(setList, 'applyTEPSelection'), ...
    ['setTEPFileList must call applyTEPSelection for a new file set. ' ...
     'Without it, new selections silently reuse stale EEG data.']);
end

function test_applyTEPSelectionResetsEEGLoadedFlag(testCase)
src = fileread(nestappFile());
body = functionBody(src, 'applyTEPSelection');
testCase.verifyNotEmpty(body, 'applyTEPSelection must exist');
testCase.verifyTrue( ...
    contains(body, 'EEG_SelectedTEPFiles_Loaded') && ...
    (contains(body, '= false') || contains(body, '= 0')), ...
    ['applyTEPSelection must reset EEG_SelectedTEPFiles_Loaded. ' ...
     'Without this, new file selections silently reuse stale EEG data.']);
end

function test_applyTEPSelectionClearsEEGCache(testCase)
src = fileread(nestappFile());
body = functionBody(src, 'applyTEPSelection');
testCase.verifyNotEmpty(body, 'applyTEPSelection must exist');
testCase.verifyTrue( ...
    contains(body, 'EEGofAllSelectedFiles') && ...
    (contains(body, '= {}') || contains(body, '= []')), ...
    ['applyTEPSelection must clear EEGofAllSelectedFiles. ' ...
     'Stale entries remain after selecting fewer files.']);
end

% ── 3.5 Boolean flag naming ───────────────────────────────────────────────

function test_noNumericFlagTEPCreated(testCase)
% TEPCreated = 0 / 1 should be a logical false/true with a descriptive name.
src = fileread(nestappFile());
% Declaration should use false/true, not 0/1
declMatch = regexp(src, 'TEPCreated\s*=\s*0\s*[;,]', 'match');
testCase.verifyEmpty(declMatch, ...
    ['Phase 3: TEPCreated = 0 uses numeric 0 as boolean. ' ...
     'Replace with isTEPPlotted = false (CLAUDE.md naming convention).']);
end

function test_noNumericFlagEEGLoaded(testCase)
% EEG_SelectedTEPFiles_Loaded = 0 should be a logical with an is_ prefix.
src = fileread(nestappFile());
declMatch = regexp(src, 'EEG_SelectedTEPFiles_Loaded\s*=\s*0\s*[;,]', 'match');
testCase.verifyEmpty(declMatch, ...
    ['Phase 3: EEG_SelectedTEPFiles_Loaded = 0 uses numeric 0 as boolean. ' ...
     'Replace with isEEGLoaded = false.']);
end

