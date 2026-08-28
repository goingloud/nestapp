% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_roiMontage
% TEST_ROIMONTAGE  The montage table and the ROI presets.
%
%   roiMontageLayout replaced 637 lines of createComponents - 69 near-identical
%   uibutton blocks - with a 69-row table. The risk in that move is a
%   transcription error: an electrode dropped, renamed, or nudged off the head
%   image. These tests pin the count, the names against the app's own
%   electrode list, and the bounds.
%
%   The picker itself launches a window, so it is exercised in tests/ui.
%
%   Run: runtests('tests/unit/test_roiMontage')
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

function restorePref(had, saved)
if had
    setpref('nestapp', 'roiPresets', saved);
elseif ispref('nestapp', 'roiPresets')
    rmpref('nestapp', 'roiPresets');
end
end

function isolatePresets(testCase)
% Presets are a live user preference; never leave a test's values behind.
had   = ispref('nestapp', 'roiPresets');
saved = getpref('nestapp', 'roiPresets', struct('name', {}, 'labels', {}));
testCase.addTeardown(@() restorePref(had, saved));
if had; rmpref('nestapp', 'roiPresets'); end
end

% ── the montage table ─────────────────────────────────────────────────────

function test_everyElectrodeSurvivedTheExtraction(testCase)
layout = roiMontageLayout();
testCase.verifyNumElements(layout, 69, ...
    'the head diagram had 69 electrode buttons');
testCase.verifyEqual(numel(unique({layout.label})), 69, 'labels must be unique');
end

function test_labelsMatchTheAppsElectrodeList(testCase)
% nestapp.elecList is what the rest of the app resolves ROI names against, so
% a montage label absent from it could never be selected meaningfully.
src  = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m'));
tok  = regexp(src, 'elecList\s*=\s*\{(.*?)\}\s*;', 'tokens', 'once', 'dotall');
testCase.assertNotEmpty(tok, 'could not find elecList in nestapp.m');
elecList = regexp(tok{1}, '''([^'']+)''', 'tokens');
elecList = lower(cellfun(@(c) c{1}, elecList, 'UniformOutput', false));

layout = roiMontageLayout();
testCase.verifyEmpty(setdiff(lower({layout.label}), elecList), ...
    'montage names an electrode the app does not know');
end

function test_positionsStayOnTheHeadImage(testCase)
[layout, headSize] = roiMontageLayout();
p = vertcat(layout.pos);
testCase.verifyGreaterThanOrEqual(min(p(:, 1)), 0);
testCase.verifyGreaterThanOrEqual(min(p(:, 2)), 0);
testCase.verifyLessThanOrEqual(max(p(:, 1) + p(:, 3)), headSize(1), ...
    'a button hanging off the right of the diagram');
testCase.verifyLessThanOrEqual(max(p(:, 2) + p(:, 4)), headSize(2), ...
    'a button hanging off the top of the diagram');
end

function test_buttonsAreUniformlySized(testCase)
layout = roiMontageLayout();
p = vertcat(layout.pos);
testCase.verifyEqual(unique(p(:, 3)), 25);
testCase.verifyEqual(unique(p(:, 4)), 23);
end

function test_noTwoButtonsSitExactlyOnTopOfEachOther(testCase)
layout = roiMontageLayout();
p = vertcat(layout.pos);
testCase.verifyEqual(size(unique(p(:, 1:2), 'rows'), 1), 69, ...
    'two electrodes share a position - one would be unclickable');
end

% ── presets ───────────────────────────────────────────────────────────────

function test_defaultRoiIsPreserved(testCase)
% The app has always opened on this cluster; the picker must not change it.
isolatePresets(testCase);
p = roiPresets();
k = find(strcmp({p.name}, 'F3 cluster (default)'), 1);
testCase.assertNotEmpty(k);
testCase.verifyEqual(sort(p(k).labels), sort({'AF3', 'F1', 'F3', 'FC1', 'FC3'}));
end

function test_nearCoilPresetIsOffered(testCase)
isolatePresets(testCase);
p = roiPresets();
k = find(strcmp({p.name}, 'Near-coil (F3)'), 1);
testCase.assertNotEmpty(k);
testCase.verifyEqual(sort(p(k).labels), sort({'AF3', 'F5', 'F3', 'FC5', 'FC3'}));
end

function test_presetElectrodesAllExistInTheMontage(testCase)
isolatePresets(testCase);
layout = roiMontageLayout();
p      = roiPresets();
for i = 1:numel(p)
    testCase.verifyEmpty(setdiff(lower(p(i).labels), lower({layout.label})), ...
        sprintf('preset "%s" names an electrode not on the diagram', p(i).name));
end
end

function test_savingAndDeletingAUserPreset(testCase)
isolatePresets(testCase);
saveRoiPreset('My ROI', {'CZ', 'PZ'});
p = roiPresets();
k = find(strcmp({p.name}, 'My ROI'), 1);
testCase.assertNotEmpty(k);
testCase.verifyEqual(p(k).labels, {'CZ', 'PZ'});

saveRoiPreset('My ROI', {});
testCase.verifyEmpty(find(strcmp({roiPresets().name}, 'My ROI'), 1)); %#ok<FNDSB>
end

function test_userPresetOverridesABuiltinAndDeletingReverts(testCase)
isolatePresets(testCase);
saveRoiPreset('Near-coil (F3)', {'CZ'});
p = roiPresets();
k = find(strcmp({p.name}, 'Near-coil (F3)'), 1);
testCase.verifyEqual(p(k).labels, {'CZ'}, 'a saved preset must win');
testCase.verifyNumElements(p, 2, 'an override must not add a duplicate entry');

saveRoiPreset('Near-coil (F3)', {});
p = roiPresets();
k = find(strcmp({p.name}, 'Near-coil (F3)'), 1);
testCase.verifyEqual(sort(p(k).labels), sort({'AF3', 'F5', 'F3', 'FC5', 'FC3'}), ...
    'deleting an override reverts to the shipped definition');
end

function test_builtinNamesAreReported(testCase)
isolatePresets(testCase);
saveRoiPreset('Mine', {'CZ'});
[~, builtins] = roiPresets();
testCase.verifyEqual(builtins, {'F3 cluster (default)', 'Near-coil (F3)'}, ...
    'the UI needs to know which presets are shipped to gate deletion');
end

function test_emptyPresetNameIsRejected(testCase)
isolatePresets(testCase);
testCase.verifyError(@() saveRoiPreset('  ', {'CZ'}), 'nestapp:emptyPresetName');
end
