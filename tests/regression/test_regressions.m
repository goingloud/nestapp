function tests = test_regressions
% TEST_REGRESSIONS  Regression tests for confirmed bugs that have been fixed.
%
%   Each test pins a specific fix so the bug cannot silently reappear.
%   Strategy:
%     (a) Source-code checks — read the actual .m file and assert that the
%         bad pattern is absent or the good pattern is present.
%     (b) Functional checks — exercise the code path that was broken and
%         assert correct output.
%
%   If a test fails it means the specific bug has been reintroduced.
%
%   Run: runtests('tests/regression/test_regressions')
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

% ── M0 bug fixes ──────────────────────────────────────────────────────────

function test_saveNewSetAssignsFname(testCase)
% BUG: replace(fname,' ','_') return value was discarded.
% FIX: fname = replace(fname,' ','_')
src   = fileread(fullfile(srcRoot(), 'runPipeline.m'));
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if contains(L, 'replace(fname') && ~startsWith(L, '%')
        testCase.verifyTrue(startsWith(L, 'fname'), ...
            sprintf(['M0-B1 regression — line %d: replace(fname,...) must assign ' ...
                     'its result back to fname.\n  Got: %s'], k, L));
    end
end
end

function test_noInputCallsInRunPipeline(testCase)
% BUG: input('...') calls blocked GUI execution.
% FIX: replaced with uiconfirm dialogs.
src = fileread(fullfile(srcRoot(), 'runPipeline.m'));
% Allow input() only inside comments; bare input( in live code is the bug.
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end   % skip comment lines
    testCase.verifyEmpty(regexp(L, '\binput\s*\(', 'match'), ...
        sprintf(['M0-B4 regression — line %d: input() calls block GUI execution. ' ...
                 'Use uiconfirm instead.\n  Got: %s'], k, L));
end
end

% ── Methods summary channel count fix (Apr 2026) ─────────────────────────

function test_methodsSummaryUsesNRejectedNotFinCh(testCase)
% BUG: methods text said "N/N retained" even when channels were removed and
%      later interpolated, because finCh == origCh after interpolation.
% FIX: methods text now uses nRejected and nInterpolated directly.
report = initPipelineReport('test.set');
report.channels.original      = 64;
report.channels.nRejected     = 5;
report.channels.nInterpolated = 3;
report.channels.final         = 62;

txt = exportReport(report, '');

% The old (broken) text would say "64/64 retained" or "100%"
% The new (correct) text must mention the rejection and/or interpolation
testCase.verifyFalse( ...
    contains(txt, '64/64') || ...
    (contains(txt, '100%') && contains(txt, 'retained')), ...
    'Methods text must not claim 100% retention when channels were rejected');
testCase.verifyTrue(contains(txt, '5') || contains(txt, 'bad'), ...
    'Methods text must mention the 5 rejected channels');
end

function test_methodsInterpolationAppears(testCase)
% When interpolation occurred, the methods text must mention it.
report = initPipelineReport('test.set');
report.channels.original      = 64;
report.channels.nRejected     = 4;
report.channels.nInterpolated = 4;
report.channels.final         = 64;

txt = exportReport(report, '');
testCase.verifyTrue(contains(lower(txt), 'interpolat'), ...
    'Methods text must mention interpolation when channels were interpolated');
end

% ── No input() in nestapp.m ───────────────────────────────────────────────

function test_noInputCallsInNestapp(testCase)
% All interactive prompts must use MATLAB UI dialogs, not command-line input().
src   = fileread(fullfile(srcRoot(), 'nestapp.m'));
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    testCase.verifyEmpty(regexp(L, '\binput\s*\(', 'match'), ...
        sprintf(['Regression — nestapp.m line %d: input() found. ' ...
                 'Must use uiconfirm/uialert instead.\n  Got: %s'], k, L));
end
end

% ── Workspace pollution guards ────────────────────────────────────────────

function test_noAssignInBaseInRunPipeline(testCase)
% assignin('base',...) pollutes the user's MATLAB workspace unconditionally.
% This test pins the removal of those calls.
src = fileread(fullfile(srcRoot(), 'runPipeline.m'));
% Allow the string in comments only
lines = strsplit(src, newline);
for k = 1:numel(lines)
    L = strtrim(lines{k});
    if startsWith(L, '%'); continue; end
    testCase.verifyEmpty(regexp(L, "assignin\s*\(\s*'base'", 'match'), ...
        sprintf(['Regression — runPipeline.m line %d: assignin(''base'',...) ' ...
                 'found. Remove workspace pollution.\n  Got: %s'], k, L));
end
end

% ── Circular dependency guard ─────────────────────────────────────────────

function test_runPipelineDoesNotCallUpdateReportsTab(testCase)
% runPipeline.m must not call app.updateReportsTab() directly.
% That creates a circular import dependency: the standalone function calls
% back into the nestapp class that invoked it.
src = fileread(fullfile(srcRoot(), 'runPipeline.m'));
testCase.verifyEmpty(regexp(src, 'app\.updateReportsTab', 'match'), ...
    ['Regression — runPipeline.m calls app.updateReportsTab(). ' ...
     'Pass a callback instead to break the circular dependency.']);
end

% ── EEG cache invalidation ────────────────────────────────────────────────

function test_selectDataButton2ResetsEEGLoaded(testCase)
% BUG: EEG_SelectedTEPFiles_Loaded was never reset on new file selection,
%      so the old EEG data was silently reused.
% FIX: SelectDataButton_2Pushed resets the flag.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
% Find the SelectDataButton_2 callback body and check it contains the reset
idx = strfind(src, 'SelectDataButton_2Pushed');
testCase.verifyFalse(isempty(idx), 'SelectDataButton_2Pushed must exist in nestapp.m');
% Extract a window of text after the callback definition
window = src(idx(1):min(idx(1)+2000, numel(src)));
testCase.verifyTrue( ...
    contains(window, 'EEG_SelectedTEPFiles_Loaded') && ...
    (contains(window, '= false') || contains(window, '= 0')), ...
    'SelectDataButton_2Pushed must reset EEG_SelectedTEPFiles_Loaded');
end

% ── Dynamic button access guard ───────────────────────────────────────────

function test_electrodeButtonAccessHasIspropGuard(testCase)
% BUG: app.([upper(label),'Button']) crashes for non-standard electrode names.
% FIX: Guard with isprop(app, propName) before accessing.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
% Verify isprop guard exists somewhere near the dynamic access pattern
hasGuard   = contains(src, 'isprop(app');
hasPattern = contains(src, ",'Button'])");
if hasPattern
    testCase.verifyTrue(hasGuard, ...
        ['Regression — dynamic electrode button access exists but no isprop guard found. ' ...
         'Non-standard electrode names will crash the app.']);
end
end

% ── pipelineDirty cleared after save ─────────────────────────────────────

function test_savePipelineClearsDirtyFlag(testCase)
% BUG: uisave does not return the chosen path, so pipelineDirty was never cleared.
% FIX: SavePipelineButtonPushed uses uiputfile and clears pipelineDirty.
src = fileread(fullfile(srcRoot(), 'nestapp.m'));
% Find SavePipelineButtonPushed
idx = strfind(src, 'SavePipelineButtonPushed');
testCase.verifyFalse(isempty(idx), 'SavePipelineButtonPushed must exist');
window = src(idx(1):min(idx(1)+1500, numel(src)));
testCase.verifyTrue(contains(window, 'pipelineDirty') && ...
    (contains(window, '= false') || contains(window, '= 0')), ...
    'SavePipelineButtonPushed must clear pipelineDirty after successful save');
end
