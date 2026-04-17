function tests = test_computeTEPQuality
% TEST_COMPUTETEPQUALITY  Unit tests for the five-axis TEP quality vector.
%
%   Tests each axis independently using synthetic EEG structs, then checks
%   the overall output contract (required fields, valid ranges).
%   No EEGLAB installation required — all inputs are hand-built structs.
%
%   Run: runtests('tests/unit/test_computeTEPQuality')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
addpath(repoRoot());
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── synthetic data helpers ────────────────────────────────────────────────

function EEG = makeEEG(nTrials, nCh, times)
% Build a minimal EEG struct with reproducible noise data.
if nargin < 3
    times = -200:2:500;   % −200 to 500 ms, 2-ms steps (500 ms pre-stim)
end
nT          = numel(times);
EEG.trials  = nTrials;
EEG.nbchan  = nCh;
EEG.times   = times;
EEG.srate   = 1000 / mean(diff(times));
rng(42);
EEG.data    = randn(nCh, nT, nTrials);
% Minimal chanlocs: all at z=0, spread along x-axis
for k = 1:nCh
    EEG.chanlocs(k).labels = sprintf('E%d', k);
    EEG.chanlocs(k).X = (k - nCh/2) * 10;
    EEG.chanlocs(k).Y = 0;
    EEG.chanlocs(k).Z = 0;
end
end

function EEG = addTEPSignal(EEG, peakMs, amplitude)
% Inject a Gaussian TEP signal at peakMs milliseconds.
% Gaussian centred at peakMs ms, sigma = 8 ms, amplitude-scaled
sig = amplitude * exp(-0.5*((EEG.times - peakMs)/8).^2);
for tr = 1:EEG.trials
    EEG.data(:, :, tr) = EEG.data(:, :, tr) + repmat(sig, EEG.nbchan, 1);
end
end

function report = makeReport(nOrigTrials, nOrigCh, nRejCh, nIntpCh)
report = initPipelineReport('test.set');
report.trials.original   = nOrigTrials;
report.trials.final      = nOrigTrials;
report.channels.original      = nOrigCh;
report.channels.nRejected     = nRejCh;
report.channels.nInterpolated = nIntpCh;
report.channels.final         = nOrigCh - nRejCh;
end

% ── output contract ───────────────────────────────────────────────────────

function test_outputHasRequiredTopFields(testCase)
EEG    = makeEEG(30, 10);
report = makeReport(30, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(isfield(q, 'retention'),         'Missing retention axis');
testCase.verifyTrue(isfield(q, 'artifactReduction'), 'Missing artifactReduction axis');
testCase.verifyTrue(isfield(q, 'bgRestoration'),     'Missing bgRestoration axis');
testCase.verifyTrue(isfield(q, 'reproducibility'),   'Missing reproducibility axis');
testCase.verifyTrue(isfield(q, 'aepLikeness'),       'Missing aepLikeness axis');
testCase.verifyTrue(isfield(q, 'version'),           'Missing version field');
end

function test_eachAxisHasRequiredSubfields(testCase)
EEG    = makeEEG(30, 10);
report = makeReport(30, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
axes = {q.retention, q.artifactReduction, q.bgRestoration, q.reproducibility, q.aepLikeness};
requiredFields = {'value', 'status', 'interpretation', 'status_detail'};
for ai = 1:numel(axes)
    ax = axes{ai};
    for fi = 1:numel(requiredFields)
        testCase.verifyTrue(isfield(ax, requiredFields{fi}), ...
            sprintf('Axis %d missing field "%s"', ai, requiredFields{fi}));
    end
end
end

function test_emptyEEGreturnsDefaultStruct(testCase)
% computeTEPQuality must not crash on empty/invalid input.
q = computeTEPQuality([], [], struct());
testCase.verifyTrue(isstruct(q), 'Must return a struct even for empty EEG');
end

function test_continuousDataReturnsDefaultStruct(testCase)
EEG        = makeEEG(1, 10);   % single trial = continuous
report     = makeReport(0, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(isstruct(q), 'Must return struct for continuous data');
end

% ── Axis 1: Retention ─────────────────────────────────────────────────────

function test_retentionOneWhenNothingRejected(testCase)
EEG    = makeEEG(30, 10);
report = makeReport(30, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyEqual(q.retention.value, 1.0, 'AbsTol', 0.01, ...
    'Retention must be 1.0 when nothing rejected');
end

function test_retentionAccountsForTrialLoss(testCase)
EEG           = makeEEG(20, 10);   % 20 trials remain
EEG.trials    = 20;
report        = makeReport(40, 10, 0, 0);  % started with 40
report.trials.final = 20;
q = computeTEPQuality(EEG, [], report);
% trial retention = 0.5, channel retention = 1.0 → combined = 0.5
testCase.verifyEqual(q.retention.value, 0.5, 'AbsTol', 0.01, ...
    'Retention must reflect trial loss');
end

function test_retentionSkippedWhenNoOriginalTrialCount(testCase)
EEG    = makeEEG(20, 10);
report = makeReport(0, 10, 0, 0);   % original = 0 → can't compute retention
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(isnan(q.retention.value) || strcmp(q.retention.status, 'skipped'), ...
    'Retention must be NaN or skipped when original trial count unavailable');
end

function test_retentionUsesNRejectedNotFinalCount(testCase)
% Regression: before fix, finCh/origCh was always 1.0 because interpolation
% restores channel count. Now uses nRejected + nInterpolated directly.
EEG    = makeEEG(30, 62);
EEG.nbchan = 62;
report = makeReport(30, 64, 5, 3);  % 5 rejected, 3 interpolated → 8 bad
report.channels.final = 62;
q = computeTEPQuality(EEG, [], report);
% channelRetention = (64 - 8) / 64 = 0.875; trialRetention = 1.0
testCase.verifyEqual(q.retention.value, 0.875, 'AbsTol', 0.01, ...
    'Channel retention must account for both rejected and interpolated');
end

% ── Axis 2: Artifact Reduction ────────────────────────────────────────────

function test_artifactReductionSkippedWhenNoEEGraw(testCase)
EEG    = makeEEG(20, 10);
report = makeReport(20, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(strcmp(q.artifactReduction.status, 'skipped'), ...
    'Artifact reduction must be skipped when EEGraw is []');
end

function test_artifactReductionSkippedWhenEEGrawEmpty(testCase)
EEG    = makeEEG(20, 10);
EEGraw = struct();   % invalid struct
report = makeReport(20, 10, 0, 0);
q = computeTEPQuality(EEG, EEGraw, report);
testCase.verifyTrue(strcmp(q.artifactReduction.status, 'skipped') || ...
    isnan(q.artifactReduction.value), ...
    'Artifact reduction must skip for malformed EEGraw');
end

% ── Axis 3: Background Restoration ───────────────────────────────────────

function test_bgRestorationSkippedWhenShortBaseline(testCase)
% Times start at -100 ms — less than the 200 ms minimum required.
times  = -100:2:500;
EEG    = makeEEG(20, 10, times);
report = makeReport(20, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(strcmp(q.bgRestoration.status, 'skipped') || isnan(q.bgRestoration.value), ...
    'Background restoration should skip when pre-stim < 200 ms');
end

function test_bgRestorationHasWarningInQualityStruct(testCase)
% When baseline is short, quality struct should note the warning.
times  = -100:2:500;
EEG    = makeEEG(20, 10, times);
report = makeReport(20, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(isfield(q, 'baselineWarning'), ...
    'quality struct must have baselineWarning field');
end

% ── Axis 4: Reproducibility ───────────────────────────────────────────────

function test_reproducibilityWarningWhenFewTrials(testCase)
% Fewer than 20 trials → warning status.
EEG    = makeEEG(10, 10);   % only 10 trials
report = makeReport(10, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(strcmp(q.reproducibility.status, 'warning') || ...
    strcmp(q.reproducibility.status, 'skipped'), ...
    'Reproducibility must warn when fewer than 20 trials');
end

function test_reproducibilityHighForCleanSignal(testCase)
% Clean signal with many trials → split-half r should be reasonably high.
EEG    = makeEEG(60, 10);
EEG    = addTEPSignal(EEG, 60, 15);   % strong P60 signal
report = makeReport(60, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
if strcmp(q.reproducibility.status, 'ok') || strcmp(q.reproducibility.status, 'warning')
    testCase.verifyGreaterThan(q.reproducibility.value, 0.2, ...
        'Split-half r should be > 0.2 for a repeatable signal');
end
end

function test_reproducibilityBoundedMinusOneToOne(testCase)
EEG    = makeEEG(40, 10);
EEG    = addTEPSignal(EEG, 50, 10);
report = makeReport(40, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
if ~isnan(q.reproducibility.value)
    testCase.verifyGreaterThanOrEqual(q.reproducibility.value, -1.0);
    testCase.verifyLessThanOrEqual(q.reproducibility.value, 1.0);
end
end

% ── Axis 5: AEP-Likeness ──────────────────────────────────────────────────

function test_aepLikenessSkippedWhenNoVertexChannels(testCase)
% Electrode labels do not include Cz, FCz, Fz → skip.
EEG    = makeEEG(30, 5);   % channels are E1..E5, not vertex labels
report = makeReport(30, 5, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(strcmp(q.aepLikeness.status, 'skipped') || isnan(q.aepLikeness.value), ...
    'AEP-Likeness must skip when no standard vertex channels present');
end

function test_aepLikenessStatusDetailMentionsSham(testCase)
% The status_detail must mention that sham data is needed for full assessment.
EEG    = makeEEG(30, 5);
report = makeReport(30, 5, 0, 0);
q = computeTEPQuality(EEG, [], report);
% This applies even when the axis is skipped
if ~isempty(q.aepLikeness.status_detail)
    testCase.verifyTrue(contains(lower(q.aepLikeness.status_detail), 'sham'), ...
        'status_detail should mention sham data requirement');
end
end

% ── version string ────────────────────────────────────────────────────────

function test_versionStringPresent(testCase)
EEG    = makeEEG(20, 10);
report = makeReport(20, 10, 0, 0);
q = computeTEPQuality(EEG, [], report);
testCase.verifyTrue(isfield(q, 'version'), 'quality struct must have version field');
testCase.verifyFalse(isempty(q.version), 'version must not be empty');
end
