
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_pipelineReport
% TEST_PIPELINEREPORT  Unit tests for initPipelineReport and exportReport.
%
%   Covers: struct shape, field defaults, exportReport formatting,
%   methods-summary branch coverage (the main regression target for the
%   channel-count bug fixed in Apr 2026).
%
%   Run: runtests('tests/unit/test_pipelineReport')
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

% ── initPipelineReport — struct shape ────────────────────────────────────

function test_initReportHasRequiredFields(testCase)
report = initPipelineReport('subject01.set');
testCase.verifyTrue(isfield(report, 'inputFile'),   'Missing inputFile');
testCase.verifyTrue(isfield(report, 'processedAt'), 'Missing processedAt');
testCase.verifyTrue(isfield(report, 'steps'),       'Missing steps');
testCase.verifyTrue(isfield(report, 'channels'),    'Missing channels');
testCase.verifyTrue(isfield(report, 'trials'),      'Missing trials');
testCase.verifyTrue(isfield(report, 'ica'),         'Missing ica');
end

function test_initReportChannelFields(testCase)
report = initPipelineReport('subject01.set');
ch = report.channels;
testCase.verifyTrue(isfield(ch, 'original'),       'Missing channels.original');
testCase.verifyTrue(isfield(ch, 'nRejected'),      'Missing channels.nRejected');
testCase.verifyTrue(isfield(ch, 'nInterpolated'),  'Missing channels.nInterpolated');
testCase.verifyTrue(isfield(ch, 'final'),          'Missing channels.final');
testCase.verifyEqual(ch.original,      0);
testCase.verifyEqual(ch.nRejected,     0);
testCase.verifyEqual(ch.nInterpolated, 0);
testCase.verifyEqual(ch.final,         0);
end

function test_initReportChannelNameFields(testCase)
% Rejected/interpolated channel NAME lists default to empty cell arrays.
report = initPipelineReport('subject01.set');
ch = report.channels;
testCase.verifyTrue(isfield(ch, 'rejectedNames'),     'Missing channels.rejectedNames');
testCase.verifyTrue(isfield(ch, 'interpolatedNames'), 'Missing channels.interpolatedNames');
testCase.verifyEqual(ch.rejectedNames,     {});
testCase.verifyEqual(ch.interpolatedNames, {});
testCase.verifyTrue(isfield(ch, 'badChannelNames'), 'Missing channels.badChannelNames');
testCase.verifyEqual(ch.badChannelNames, {});
testCase.verifyTrue(isfield(ch, 'unneededNames'), 'Missing channels.unneededNames');
testCase.verifyEqual(ch.unneededNames, {});
end

function test_channelReportDistinguishesBadFromUnneeded(testCase)
% The per-file CHANNELS block lists bad-channel detection removals and
% deliberate "un-needed" removals on separate, labelled lines (not conflated).
report = initPipelineReport('test.set');
report.channels.original        = 64;
report.channels.nRejected       = 4;
report.channels.rejectedNames   = {'TP9','TP10','C4','T8'};
report.channels.unneededNames   = {'TP9','TP10'};
report.channels.badChannelNames = {'C4','T8'};
report.channels.final           = 60;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'bad channels (2): C4, T8'), 'bad-channel line');
testCase.verifyTrue(contains(txt, 'un-needed (2): TP9, TP10'), 'un-needed line');
testCase.verifyFalse(contains(txt, 'Rejected:     4 (TP9'), 'must not lump names on one line');
end

function test_initReportTrialFields(testCase)
report = initPipelineReport('subject01.set');
tr = report.trials;
testCase.verifyTrue(isfield(tr, 'original'), 'Missing trials.original');
testCase.verifyTrue(isfield(tr, 'rejected'), 'Missing trials.rejected');
testCase.verifyTrue(isfield(tr, 'final'),    'Missing trials.final');
testCase.verifyEqual(tr.original, 0);
testCase.verifyEqual(tr.rejected, 0);
testCase.verifyEqual(tr.final,    0);
end

function test_initReportIcaFields(testCase)
report = initPipelineReport('subject01.set');
testCase.verifyTrue(isfield(report.ica, 'nComponents'), 'Missing ica.nComponents');
testCase.verifyTrue(isfield(report.ica, 'nRejected'),   'Missing ica.nRejected');
testCase.verifyTrue(isfield(report.ica, 'varRemoved'),  'Missing ica.varRemoved');
testCase.verifyEqual(report.ica.nComponents, 0);
testCase.verifyEqual(report.ica.nRejected,   0);
testCase.verifyTrue(isnan(report.ica.varRemoved), 'varRemoved must init as NaN');
end

function test_initReportStepsIsEmpty(testCase)
report = initPipelineReport('subject01.set');
testCase.verifyEmpty(report.steps, 'steps should be empty at initialisation');
end

function test_initReportStoresFilename(testCase)
report = initPipelineReport('my_eeg_data.set');
testCase.verifyEqual(report.inputFile, 'my_eeg_data.set');
end

function test_initReportIcaCategoriesPresent(testCase)
report = initPipelineReport('test.set');
cats = report.ica.categories;
testCase.verifyTrue(isfield(cats, 'names'),    'Missing ica.categories.names');
testCase.verifyTrue(isfield(cats, 'nRemoved'), 'Missing ica.categories.nRemoved');
testCase.verifyEqual(numel(cats.names), 7, 'Should have 7 ICLabel categories');
testCase.verifyEqual(cats.nRemoved, zeros(1,7), 'nRemoved should start at zero');
end

% ── exportReport — basic formatting ──────────────────────────────────────

function test_exportReportReturnsText(testCase)
report = initPipelineReport('subject01.set');
report.channels.original = 64;
report.channels.final    = 64;
summaryText = exportReport(report, '');
testCase.verifyFalse(isempty(summaryText), 'summaryText must not be empty');
testCase.verifyTrue(ischar(summaryText) || isstring(summaryText), 'must be text');
end

function test_exportReportContainsFilename(testCase)
report = initPipelineReport('subject01.set');
summaryText = exportReport(report, '');
testCase.verifyTrue(contains(summaryText, 'subject01.set'), ...
    'summaryText must contain the input filename');
end

function test_exportReportChannelSummary(testCase)
report = initPipelineReport('test.set');
report.channels.original  = 64;
report.channels.nRejected = 3;
report.channels.final     = 61;
summaryText = exportReport(report, '');
testCase.verifyTrue(contains(summaryText, '64'), 'Must mention original channel count');
testCase.verifyTrue(contains(summaryText, '61'), 'Must mention final channel count');
end

function test_exportReportTrialSummary(testCase)
report = initPipelineReport('test.set');
report.trials.original = 80;
report.trials.rejected = 5;
report.trials.final    = 75;
summaryText = exportReport(report, '');
testCase.verifyTrue(contains(summaryText, '80'), 'Must mention original trial count');
testCase.verifyTrue(contains(summaryText, '75'), 'Must mention final trial count');
end

function test_exportReportSkipsSaveWhenEmptyDir(testCase)
report = initPipelineReport('test.set');
[summaryText, matPath] = exportReport(report, '');
testCase.verifyFalse(isempty(summaryText), 'summaryText must be non-empty');
% matPath may be empty if no valid output dir — that is acceptable
testCase.verifyTrue(ischar(matPath) || isstring(matPath), 'matPath must be text type');
end

function test_channelSummaryListsRejectedNames(testCase)
% The CHANNELS block names the rejected/interpolated electrodes, not just
% the counts, when the name lists are populated.
report = initPipelineReport('test.set');
report.channels.original          = 64;
report.channels.nRejected         = 2;
report.channels.rejectedNames     = {'TP7', 'FT8'};
report.channels.nInterpolated     = 2;
report.channels.interpolatedNames = {'TP7', 'FT8'};
report.channels.final             = 64;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'Rejected:     2 (TP7, FT8)'), ...
    'CHANNELS block must list rejected electrode names');
testCase.verifyTrue(contains(txt, 'Interpolated: 2 (TP7, FT8)'), ...
    'CHANNELS block must list interpolated electrode names');
end

function test_channelSummaryBackwardCompatNoNameFields(testCase)
% Legacy reports saved before the name fields existed must still format
% (counts only) without erroring.
report = initPipelineReport('test.set');
report.channels.original  = 64;
report.channels.nRejected = 3;
report.channels.final     = 61;
report.channels = rmfield(report.channels, {'rejectedNames','interpolatedNames'});
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'Rejected:     3'), 'Counts must still print');
testCase.verifyFalse(contains(txt, 'Rejected:     3 ('), 'No names when fields absent');
end

% ── exportReport — METHODS branch coverage ───────────────────────────────
% The per-file METHODS line is one concise sentence built by methodsParagraph
% (channels/epochs retained + ICA removed). The full cross-file prose lives in
% the session summary. These tests pin the per-file wording.

function test_methodsNone(testCase)
% No rejection, no interpolation → "all N channels were retained"
report = initPipelineReport('test.set');
report.channels.original      = 32;
report.channels.nRejected     = 0;
report.channels.nInterpolated = 0;
report.channels.final         = 32;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'all 32 channels were retained'), ...
    'Methods should say "all 32 channels were retained" when none were removed');
end

function test_methodsRejectionOnly(testCase)
% 3 channels rejected, none interpolated
report = initPipelineReport('test.set');
report.channels.original      = 64;
report.channels.nRejected     = 3;
report.channels.nInterpolated = 0;
report.channels.final         = 61;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, '61 of 64 channels were retained (3 removed)'), ...
    'Should report "61 of 64 channels were retained (3 removed)"');
% Must NOT claim all channels retained
testCase.verifyFalse(contains(txt, '100%'), ...
    'Must not claim 100% retained when channels were rejected');
end

function test_methodsRejectionAndInterpolation(testCase)
% 5 rejected, 3 interpolated → "5 removed; 3 interpolated"
report = initPipelineReport('test.set');
report.channels.original      = 64;
report.channels.nRejected     = 5;
report.channels.nInterpolated = 3;
report.channels.final         = 62;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, '5'), 'Should mention 5 rejected');
testCase.verifyTrue(contains(txt, '3'), 'Should mention 3 interpolated');
testCase.verifyTrue(contains(txt, 'interpolated'), 'Should use "interpolated"');
end

function test_methodsInterpolationOnly(testCase)
% 0 rejected but 4 interpolated (unusual but valid)
report = initPipelineReport('test.set');
report.channels.original      = 64;
report.channels.nRejected     = 0;
report.channels.nInterpolated = 4;
report.channels.final         = 64;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'interpolated'), 'Should mention interpolation');
testCase.verifyTrue(contains(txt, '4'), 'Should mention 4 interpolated channels');
end

function test_methodsTrialRetentionPercent(testCase)
% Trial sentence should include a percentage
report = initPipelineReport('test.set');
report.trials.original = 80;
report.trials.rejected = 8;
report.trials.final    = 72;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, '90') || contains(txt, '72') || contains(txt, '80'), ...
    'Methods trial sentence should mention counts or percentage');
end

function test_methodsICANoRejection(testCase)
% ICA ran but nothing removed → "none removed"
report = initPipelineReport('test.set');
report.ica.nComponents = 30;
report.ica.nRejected   = 0;
report.ica.nKept       = 30;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, '30'), 'Should mention 30 components');
testCase.verifyTrue(contains(txt, 'ICA identified 30 components, none removed'), ...
    'Methods should say "ICA identified 30 components, none removed"');
end

function test_methodsICAWithVariance(testCase)
% Single round, variance available
report = initPipelineReport('test.set');
report.ica.nComponents = 30;
report.ica.nRejected   = 4;
report.ica.nKept       = 26;
report.ica.varRemoved  = 18.5;
report.ica.varMin      = 2.3;
report.ica.varMax      = 7.1;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, '18'), 'Should mention variance removed (~18%)');
end

function test_methodsICAWithCategories(testCase)
% When ICLabel category data is present the report must show the breakdown.
report = initPipelineReport('test.set');
report.ica.nComponents = 25;
report.ica.nRejected   = 5;
report.ica.nKept       = 20;
% Set two non-zero category counts (Muscle and Eye)
report.ica.categories.nRemoved(2) = 3;   % Muscle
report.ica.categories.nRemoved(3) = 2;   % Eye
report.ica.categories.varShare(2) = 12.0;
report.ica.categories.varShare(3) = 6.5;
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'Muscle') || contains(lower(txt), 'muscle'), ...
    'Report must list Muscle category when components were rejected in that category');
testCase.verifyTrue(contains(txt, 'Eye') || contains(lower(txt), 'eye'), ...
    'Report must list Eye category when components were rejected in that category');
end

function test_methodsMultiRoundNoVariance(testCase)
% Multi-round TESA ICA: top-level variance fields are NaN (variance is not
% additive across ICA bases); only per-round detail should carry variance.
report = initPipelineReport('test.set');
report.ica.nComponents = 30;
report.ica.nRejected   = 8;
report.ica.nKept       = 22;
% Simulate two rounds — varRemoved stays NaN at the top level
rnd1.nComponents = 30; rnd1.nRejected = 4; rnd1.varRemoved = 15.0;
rnd1.varMin = 2.0; rnd1.varMax = 6.0;
rnd1.categories = report.ica.categories;
rnd2.nComponents = 26; rnd2.nRejected = 4; rnd2.varRemoved = NaN;
rnd2.varMin = NaN; rnd2.varMax = NaN;
rnd2.categories = report.ica.categories;
report.ica.rounds = {rnd1, rnd2};
txt = exportReport(report, '');
% Must mention multiple rounds
testCase.verifyTrue(contains(txt, '2') && contains(lower(txt), 'round'), ...
    'Multi-round report must mention round count');
% Top-level summary must NOT assert a single combined variance figure
% (because variance across different ICA bases is not additive)
testCase.verifyFalse(contains(txt, sprintf('%.1f%% ICA variance', ...
    rnd1.varRemoved + rnd2.varRemoved)), ...
    'Must not sum variance across rounds in top-level summary');
end

% ── citation block (per-file report + session summary) ───────────────────

function rec = stepRecord(name)
% Minimal complete step record (buildReportText's STEPS RUN reads these fields).
rec = struct('name', name, 'chansBefore', 0, 'chansAfter', 0, ...
             'trialsBefore', 0, 'trialsAfter', 0, 'duration', 0);
end

function test_citationDerivedFromSteps(testCase)
% Citations come from the steps that ran: a Picard step surfaces the Picard
% reference and DOI.
report = initPipelineReport('test.set');
report.steps = {stepRecord('Run ICA (Picard)')};
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'CITATION'), 'Report must include a CITATION section');
testCase.verifyTrue(contains(txt, 'Ablin'), 'Citation must name the Picard reference');
testCase.verifyTrue(contains(txt, '10.1109/TSP.2018.2844203'), 'Citation must include the DOI');
end

function test_noCitationForUncitedSteps(testCase)
% Steps with no associated method citation produce no CITATION block.
report = initPipelineReport('test.set');
report.steps = {stepRecord('Remove Baseline'), stepRecord('Re-Reference')};
txt = exportReport(report, '');
testCase.verifyFalse(contains(txt, 'CITATION'), ...
    'No CITATION section when no step maps to a cited method');
end

function test_noSpuriousSoundCitation(testCase)
% Regression: a TESA pipeline without a SOUND step must cite TESA but NOT
% Mutanen/SOUND. Previously the template citation note always mentioned SOUND.
report = initPipelineReport('test.set');
report.steps = {stepRecord('Remove ICA Components (TESA)'), ...
                stepRecord('Run ICA (Picard)')};
txt = exportReport(report, '');
testCase.verifyTrue(contains(txt, 'Rogasch'), 'TESA step must cite Rogasch');
testCase.verifyTrue(contains(txt, 'Ablin'), 'Picard step must cite Ablin');
testCase.verifyFalse(contains(txt, 'SOUND') || contains(txt, 'Mutanen'), ...
    'No SOUND/Mutanen citation when no SOUND step was used');
end

function test_summaryHasMethodsAndCitation(testCase)
% The session summary carries the aggregate METHODS prose and the union of
% method citations across files (derived from steps).
r1 = initPipelineReport('a.set');
r1.steps = {stepRecord('Remove Decay Artifact')};
r1.channels.original = 64; r1.channels.nRejected = 2; r1.channels.final = 62;
r2 = initPipelineReport('b.set');
r2.steps = {stepRecord('Interpolate Missing Data (AR-Blend)')};
r2.channels.original = 64; r2.channels.nRejected = 4; r2.channels.final = 60;
txt = summarizeReports({r1, r2});
testCase.verifyTrue(contains(txt, 'METHODS'), 'Summary must include a METHODS section');
testCase.verifyTrue(contains(txt, 'Across 2 files'), 'Summary methods must be cross-file prose');
testCase.verifyTrue(contains(txt, 'CITATION'), 'Summary must include a CITATION section');
testCase.verifyTrue(contains(txt, 'Cline C.C. et al. (2021)'), 'Summary must cite the AARATEP reference');
end

function test_summaryTalliesBadChannelElectrodes(testCase)
% The session summary tallies which electrodes the quality-based bad-channel
% steps removed across files: electrodes removed in >=2 files are listed with
% their file count; one-off removals go under "once". This is what makes a
% systematic pick (e.g. CP1/CP2 recurring) visible to the user.
r1 = initPipelineReport('a.set');
r1.channels.original = 64; r1.channels.final = 62;
r1.channels.badChannelNames = {'CP1', 'FT10'};
r2 = initPipelineReport('b.set');
r2.channels.original = 64; r2.channels.final = 63;
r2.channels.badChannelNames = {'CP1'};
r3 = initPipelineReport('c.set');
r3.channels.original = 64; r3.channels.final = 64;
r3.channels.badChannelNames = {};
txt = summarizeReports({r1, r2, r3});
testCase.verifyTrue(contains(txt, 'Bad-channel removals by electrode (3 files):'), ...
    'Summary must include the electrode tally header');
testCase.verifyTrue(contains(txt, 'CP1 (2/3)'), ...
    'Recurrent electrode must show how many files it was removed in');
testCase.verifyTrue(contains(txt, 'once: FT10'), ...
    'One-off removals must be listed under "once"');
end

function test_summaryNoTallyWhenNoBadChannels(testCase)
% No tally block when no quality-based bad-channel removals occurred (e.g. only
% deliberate "Remove un-needed Channels"), so the section stays clean.
r1 = initPipelineReport('a.set'); r1.channels.original = 64; r1.channels.final = 64;
r2 = initPipelineReport('b.set'); r2.channels.original = 64; r2.channels.final = 64;
txt = summarizeReports({r1, r2});
testCase.verifyFalse(contains(txt, 'Bad-channel removals by electrode'), ...
    'Tally must be omitted when there are no bad-channel removals');
end

function test_summaryShowsIntentionalRemovalsDistinctly(testCase)
% Intentional "un-needed" removals are shown in the summary (not omitted) and
% kept on their own line, separate from bad-channel detection. Uniform removals
% (every file) appear without a file-count tag.
r1 = initPipelineReport('a.set'); r1.channels.original = 64; r1.channels.final = 61;
r1.channels.unneededNames = {'TP9','TP10'}; r1.channels.badChannelNames = {'C4'};
r2 = initPipelineReport('b.set'); r2.channels.original = 64; r2.channels.final = 61;
r2.channels.unneededNames = {'TP9','TP10'}; r2.channels.badChannelNames = {'C5'};
txt = summarizeReports({r1, r2});
testCase.verifyTrue(contains(txt, 'Intentionally removed (un-needed):'), 'un-needed line present');
testCase.verifyTrue(contains(txt, 'TP9') && contains(txt, 'TP10'), 'both un-needed names shown');
testCase.verifyFalse(contains(txt, 'TP9 (') || contains(txt, 'TP10 ('), ...
    'uniform un-needed removals carry no per-file count tag');
testCase.verifyTrue(contains(txt, 'Bad-channel removals by electrode'), ...
    'bad-channel tally still present and separate');
end

% ── methods narrative (full parameterized prose) ─────────────────────────────

function rec = stepRecP(name, params)
% Step record carrying parameters (as processOneFile now stores) so the methods
% narrative can describe the step.
rec = struct('name', name, 'params', params, 'chansBefore', 0, 'chansAfter', 0, ...
             'trialsBefore', 0, 'trialsAfter', 0, 'duration', 0);
end

function r = reportWithPipeline(fname)
% A report whose steps carry params for a small TMS-style pipeline.
r = initPipelineReport(fname);
r.steps = {stepRecP('Epoching',                    struct('timelim',[-1 1],'types',{{'TMS'}})), ...
           stepRecP('Remove TMS Artifacts (TESA)', struct('cutTimesTMS',[-2 10])), ...
           stepRecP('Frequency Filter (TESA)',     struct('type','bandpass','high',1,'low',80,'ord',4)), ...
           stepRecP('Re-Reference',                struct('ref','[]'))};
r.channels.original = 63; r.channels.final = 61; r.channels.nRejected = 2;
r.trials.original = 100;  r.trials.final = 90;   r.trials.rejected = 10;
end

function test_methodsNarrativeIsParameterized(testCase)
txt = methodsNarrative(reportWithPipeline('s.set'));
testCase.verifyTrue(contains(txt, 'using EEGLAB and the TESA toolbox'), 'software sentence');
testCase.verifyTrue(contains(txt, '-1000 to 1000 ms'), 'epoch window present');
testCase.verifyTrue(contains(txt, '1 to 80 Hz'),       'filter cutoffs present');
testCase.verifyTrue(contains(txt, 'common average'),   'reference present');
testCase.verifyTrue(contains(txt, '61 of 63 channels'),'outcome counts present');
end

function test_methodsNarrativeFallsBackWithoutParams(testCase)
% A report whose steps carry no params degrades to the brief outcomes-only note.
r = initPipelineReport('s.set');
r.steps = {stepRecord('Epoching'), stepRecord('Re-Reference')};
r.channels.original = 63; r.channels.final = 61; r.channels.nRejected = 2;
txt = methodsNarrative(r);
testCase.verifyTrue(contains(txt, 'preprocessed using nestapp'), 'brief fallback prose');
testCase.verifyFalse(contains(txt, 'band-pass'), 'no parameterized clauses in fallback');
end

function test_aggregateRichSharedPipeline(testCase)
r1 = reportWithPipeline('a.set');
r2 = reportWithPipeline('b.set'); r2.channels.final = 60; r2.channels.nRejected = 3;
txt = methodsParagraphAggregate({r1, r2});
testCase.verifyTrue(contains(txt, '1 to 80 Hz'),          'shared pipeline prose present');
testCase.verifyTrue(contains(txt, 'Across 2 files'),      'aggregated counts present');
testCase.verifyTrue(contains(txt, 'mean +/- SD across files'), 'spread annotation present');
end

function test_aggregateMixedPipelineOmitsProse(testCase)
% Files that ran different step sequences fall back to counts-only (no shared
% pipeline prose), but still report across-file counts.
r1 = reportWithPipeline('a.set');
r2 = reportWithPipeline('b.set');
r2.steps = {stepRecP('Re-Sample', struct('freq',1000))};   % divergent sequence
txt = methodsParagraphAggregate({r1, r2});
testCase.verifyTrue(contains(txt, 'Across 2 files'), 'counts still reported');
testCase.verifyFalse(contains(txt, '1 to 80 Hz'),    'no shared prose for mixed pipelines');
end
