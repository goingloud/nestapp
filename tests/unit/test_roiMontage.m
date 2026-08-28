% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_roiMontage
% TEST_ROIMONTAGE  The montage table and the ROI presets.
%
%   roiMontageLayout holds the positions the 69 uibutton blocks in
%   createComponents encoded (they are still there; this is a staged
%   replacement). The risk in extracting them is a transcription error: an
%   electrode dropped, renamed, re-cased, or nudged off the head image. These
%   tests pin the count, the exact spelling against electrodeList, and the
%   bounds.
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
addpath(fullfile(r, 'tests', 'helpers'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function isolatePresets(testCase)
% Shared with tests/ui/test_roiPicker - presets are a live user preference and
% neither file may read or write the real ones.
isolateRoiPresets(testCase);
end

% ── the montage table ─────────────────────────────────────────────────────

function test_everyElectrodeSurvivedTheExtraction(testCase)
layout = roiMontageLayout();
testCase.verifyNumElements(layout, 69, ...
    'the head diagram had 69 electrode buttons');
testCase.verifyEqual(numel(unique({layout.label})), 69, 'labels must be unique');
end

function test_labelsAreExactlyTheElectrodeList(testCase)
% electrodeList is the single source of spelling. The comparison is EXACT, not
% case-insensitive: the two lists disagreed on case for a long time (FPZ vs
% FPz) precisely because every matcher in the app ignores case, so only an
% exact test can catch the next drift.
layout = roiMontageLayout();
testCase.verifyEqual(sort({layout.label}), sort(electrodeList()), ...
    'the montage must name exactly the electrodes electrodeList declares');
end

function test_electrodeListStillAgreesWithTheAppsProperty(testCase)
% nestapp.elecList is still its own literal until the Explore tab lands; this
% keeps the two from drifting in the meantime.
src = fileread(fullfile(repoRoot(), 'src', '@nestapp', 'nestapp.m'));
tok = regexp(src, 'elecList\s*=\s*\{(.*?)\}\s*;', 'tokens', 'once', 'dotall');
testCase.assertNotEmpty(tok, 'could not find elecList in nestapp.m');
fromApp = regexp(tok{1}, '''([^'']+)''', 'tokens');
fromApp = cellfun(@(c) c{1}, fromApp, 'UniformOutput', false);
testCase.verifyEqual(sort(fromApp), sort(electrodeList()));
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
saveRoiPreset('My ROI', {'Cz', 'Pz'});
p = roiPresets();
k = find(strcmp({p.name}, 'My ROI'), 1);
testCase.assertNotEmpty(k);
testCase.verifyEqual(p(k).labels, {'Cz', 'Pz'});

saveRoiPreset('My ROI', {});
testCase.verifyEmpty(find(strcmp({roiPresets().name}, 'My ROI'), 1)); %#ok<FNDSB>
end

function test_userPresetOverridesABuiltinAndDeletingReverts(testCase)
isolatePresets(testCase);
saveRoiPreset('Near-coil (F3)', {'Cz'});
p = roiPresets();
k = find(strcmp({p.name}, 'Near-coil (F3)'), 1);
testCase.verifyEqual(p(k).labels, {'Cz'}, 'a saved preset must win');
testCase.verifyNumElements(p, 2, 'an override must not add a duplicate entry');

saveRoiPreset('Near-coil (F3)', {});
p = roiPresets();
k = find(strcmp({p.name}, 'Near-coil (F3)'), 1);
testCase.verifyEqual(sort(p(k).labels), sort({'AF3', 'F5', 'F3', 'FC5', 'FC3'}), ...
    'deleting an override reverts to the shipped definition');
end

function test_provenanceIsReportedPerPreset(testCase)
% The UI gates deletion on this, and answering it here is what keeps the view
% from needing its own look at the preference store.
isolatePresets(testCase);
saveRoiPreset('Mine', {'Cz'});
p = roiPresets();
testCase.verifyFalse(p(strcmp({p.name}, 'F3 cluster (default)')).userDefined);
testCase.verifyTrue(p(strcmp({p.name}, 'Mine')).userDefined);
end

function test_anOverriddenBuiltinIsMarkedUserDefined(testCase)
isolatePresets(testCase);
saveRoiPreset('Near-coil (F3)', {'Cz'});
p = roiPresets();
testCase.verifyTrue(p(strcmp({p.name}, 'Near-coil (F3)')).userDefined, ...
    'an override is deletable, and deleting it reverts to the built-in');
end

function test_emptyPresetNameIsRejected(testCase)
isolatePresets(testCase);
testCase.verifyError(@() saveRoiPreset('  ', {'Cz'}), 'nestapp:emptyPresetName');
end
