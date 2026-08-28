% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_aaratepHarvest
% TEST_AARATEPHARVEST  Folding an AARATEP run's own outputs back into nestapp.
%
%   The orchestrator returns only the cleaned EEG. Everything else it produces
%   is files: a provenance struct saved beside the result, QC images, and
%   three intermediate datasets. Without this harvest the report shows no ICA
%   (so methodsNarrative, gated on nComponents > 0, omits ICA from the methods
%   paragraph entirely), no bad channels (AARATEP interpolates them back so
%   the count never moves), and no figures at all.
%
%   Run: runtests('tests/unit/test_aaratepHarvest')
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

function [dir_, prefix] = fakeRun(testCase)
% An output folder shaped like a real AARATEP run: result + md, the three
% unconditional intermediates, and its QC images.
prefix = 'PreprocessedResults';
dir_ = fullfile(tempdir, ['nestapp_aaratep_', char(matlab.lang.internal.uuid())]);
mkdir(dir_);
testCase.addTeardown(@() rmdir(dir_, 's'));

EEG = struct('data', single(zeros(4, 10)), 'nbchan', 4); %#ok<NASGU>
md  = defaultMd();                                       %#ok<NASGU>
save(fullfile(dir_, [prefix '.mat']), 'EEG', 'md');
for suffix = {'_preSOUND', '_preDecayRemoval', '_preICARejection'}
    save(fullfile(dir_, [prefix suffix{1} '.mat']), 'EEG', 'md');
end
for img = {'_QC_EarlyChannelRejection', '_QC_DecayFitAndRemoval', ...
           '_QC_ClassifiedComponents', '_Plot_TEPTimtopo'}
    imwrite(uint8(zeros(4, 4, 3)), fullfile(dir_, [prefix img{1} '.png']));
end
end

function md = defaultMd()
md = struct('pipelineVersion', '2.1.1', ...
            'earlyRejectedChannels', [2 4], ...
            'eyeICA_numComp', 30, 'eyeICA_numRejComp', 2, ...
            'ICA_numComp', 30, 'ICA_numRejComp', 7, ...
            'didRemoveDecay', true);
end

function r = blankReport()
r = initPipelineReport('subj01.set');
end

% ── provenance ────────────────────────────────────────────────────────────

function test_icaCountsReachTheReport(testCase)
% Both passes count: without this the methods paragraph never mentions ICA.
[d, pfx] = fakeRun(testCase);
[report, info] = aaratepHarvest(blankReport(), d, pfx);

testCase.verifyTrue(info.mdFound);
testCase.verifyEqual(report.ica.nComponents, 60, 'eye pass + main pass');
testCase.verifyEqual(report.ica.nRejected,   9);
testCase.verifyEqual(report.ica.nKept,       51);
end

function test_methodsParagraphNowMentionsICA(testCase)
% The whole point of reading md: methodsNarrative gates the ICA sentence on
% nComponents > 0, so before the harvest an AARATEP run silently produced a
% methods paragraph with no ICA in it.
[d, pfx] = fakeRun(testCase);
before = blankReport();
before.steps = {stepRec('AARATEP Pipeline (whole)')};
after = aaratepHarvest(before, d, pfx);
after.steps = before.steps;

testCase.verifyFalse(contains(methodsNarrative(before), 'independent components'), ...
    'Precondition: without md the paragraph omits ICA');
testCase.verifyTrue(contains(methodsNarrative(after), 'independent components'), ...
    'After the harvest the methods paragraph reports the ICA removal');
end

function test_badChannelsAreNamedAndCountedAsInterpolated(testCase)
% AARATEP interpolates them back, so this must not read as a rejection - the
% data is still there.
[d, pfx] = fakeRun(testCase);
opts = struct('channelLabels', {{'Fp1', 'Fp2', 'Cz', 'Pz'}});
report = aaratepHarvest(blankReport(), d, pfx, opts);

testCase.verifyEqual(sort(report.channels.badChannelNames), {'Fp2', 'Pz'});
testCase.verifyEqual(report.channels.nInterpolated, 2);
testCase.verifyEqual(report.channels.nRejected, 0, ...
    'Interpolated channels must not be counted as rejected');
end

function test_channelIndicesSurviveWithoutLabels(testCase)
[d, pfx] = fakeRun(testCase);
report = aaratepHarvest(blankReport(), d, pfx);
testCase.verifyEqual(sort(report.channels.badChannelNames), {'#2', '#4'});
end

function test_versionIsRecorded(testCase)
[d, pfx] = fakeRun(testCase);
report = aaratepHarvest(blankReport(), d, pfx);
testCase.verifyEqual(report.aaratepVersion, '2.1.1');
end

% ── figures ───────────────────────────────────────────────────────────────

function test_qcImagesBecomeReportFigures(testCase)
[d, pfx] = fakeRun(testCase);
[report, info] = aaratepHarvest(blankReport(), d, pfx);

testCase.verifyNumElements(info.figures, 4);
testCase.verifyNumElements(report.quality.figures, 4);
testCase.verifyTrue(all(cellfun(@(f) exist(f, 'file') == 2, report.quality.figures)), ...
    'Every registered figure must actually exist');
end

function test_figuresAppendRatherThanReplace(testCase)
% nestapp's own QC images may already be registered from a Quality Gate.
[d, pfx] = fakeRun(testCase);
before = blankReport();
before.quality = struct('figures', {{'existing.png'}});
report = aaratepHarvest(before, d, pfx);
testCase.verifyEqual(report.quality.figures{1}, 'existing.png');
testCase.verifyNumElements(report.quality.figures, 5);
end

% ── tidying ───────────────────────────────────────────────────────────────

function test_intermediatesAreKeptByDefault(testCase)
[d, pfx] = fakeRun(testCase);
[~, info] = aaratepHarvest(blankReport(), d, pfx);
testCase.verifyEmpty(info.removed, 'Default must keep everything');
testCase.verifyEqual(exist(fullfile(d, [pfx '_preSOUND.mat']), 'file'), 2);
end

function test_intermediatesRemovedWhenAsked(testCase)
[d, pfx] = fakeRun(testCase);
opts = struct('keepIntermediates', false);
[~, info] = aaratepHarvest(blankReport(), d, pfx, opts);

testCase.verifyNumElements(info.removed, 3);
testCase.verifyGreaterThan(info.bytesFreed, 0);
for suffix = {'_preSOUND', '_preDecayRemoval', '_preICARejection'}
    testCase.verifyEqual(exist(fullfile(d, [pfx suffix{1} '.mat']), 'file'), 0, ...
        sprintf('%s should be gone', suffix{1}));
end
testCase.verifyEqual(exist(fullfile(d, [pfx '.mat']), 'file'), 2, ...
    'The result itself must survive');
end

function test_finalMatIsReportedButNeverDeletedHere(testCase)
% The result is the caller's to drop, and only once the .set that replaces it
% exists - a step between here and Save New Set can still abort the file. This
% function reports the path and leaves it alone.
[d, pfx] = fakeRun(testCase);
[report, info] = aaratepHarvest(blankReport(), d, pfx);

testCase.verifyEqual(info.droppableFinalMat, fullfile(d, [pfx '.mat']), ...
    'The droppable path must be reported to the caller');
testCase.verifyEqual(exist(fullfile(d, [pfx '.mat']), 'file'), 2, ...
    'and the file must still be there');
testCase.verifyFalse(ismember(fullfile(d, [pfx '.mat']), info.removed));
testCase.verifyEqual(report.ica.nComponents, 60, ...
    'Its metadata is read before the caller can drop it');
end

function test_nothingIsDroppableWithoutMetadata(testCase)
% No md means nothing was harvested from it, so it is not safe to drop -
% deleting would lose the only copy of the result.
d = fullfile(tempdir, ['nestapp_aaratep_', char(matlab.lang.internal.uuid())]);
mkdir(d);
testCase.addTeardown(@() rmdir(d, 's'));
EEG = struct('data', 1); %#ok<NASGU>
save(fullfile(d, 'PreprocessedResults.mat'), 'EEG');

[~, info] = aaratepHarvest(blankReport(), d, 'PreprocessedResults');
testCase.verifyEmpty(info.droppableFinalMat, ...
    'Without metadata the result must not be offered up for deletion');
testCase.verifyEmpty(info.removed);
testCase.verifyEqual(exist(fullfile(d, 'PreprocessedResults.mat'), 'file'), 2);
end

% ── robustness ────────────────────────────────────────────────────────────

function test_missingFolderIsHarmless(testCase)
report = blankReport();
[out, info] = aaratepHarvest(report, fullfile(tempdir, 'no_such_aaratep_dir'), 'x');
testCase.verifyFalse(info.mdFound);
testCase.verifyEqual(out.ica.nComponents, report.ica.nComponents);
end

function test_emptyOutputDirIsHarmless(testCase)
[~, info] = aaratepHarvest(blankReport(), '', 'x');
testCase.verifyFalse(info.mdFound);
testCase.verifyEmpty(info.figures);
end

% ── helpers ───────────────────────────────────────────────────────────────

function rec = stepRec(name)
rec = struct('name', name, 'params', struct(), 'chansBefore', 64, ...
             'chansAfter', 64, 'trialsBefore', 100, 'trialsAfter', 100, ...
             'duration', 0);
end
