function tests = test_batchTEPExtract
% TEST_BATCHTEPEXTRACT  Unit tests for batchTEPExtract.m.
%
%   All tests use a synthetic loadFcn so EEGLAB file I/O is not required.
%   TESA (tesa_peakanalysis) must be on the path, as tepPeakFinder calls it.
%
%   Run: runtests('tests/unit/test_batchTEPExtract')
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

% ── helpers ────────────────────────────────────────────────────────────────

function EEG = makeEEG(nChan, nTime, nTrials, labels, times)
% Build a minimal synthetic EEG struct.
EEG.nbchan  = nChan;
EEG.trials  = nTrials;
EEG.times   = times;
EEG.chanlocs = struct('labels', labels);
% Synthetic clean waveform with canonical TEP-like components at known latencies.
% Gaussian bumps at N45(−), P60(+), N100(−), P180(+) for detectability.
base = zeros(nChan, nTime);
for k = 1:nChan
    base(k,:) = syntheticTEP(times);
end
EEG.data = repmat(base, 1, 1, nTrials) + 0.1 * randn(nChan, nTime, nTrials);
end

function w = syntheticTEP(times)
% Gaussian bumps at the four most-prominent canonical TEP components.
w  = -3 * gauss(times, 45, 6);   % N45 neg
w  = w + 4 * gauss(times, 60, 7); % P60 pos
w  = w - 5 * gauss(times, 100, 12); % N100 neg
w  = w + 4 * gauss(times, 180, 20); % P180 pos
end

function g = gauss(t, mu, sigma)
g = exp(-0.5 * ((t - mu) / sigma).^2);
end

function EEG = makeEpochedEEG(labels)
% Convenience: 500 Hz epoch from −100 to 300 ms, 4 channels.
times = -100 : 2 : 300;   % 201 samples
if nargin < 1
    labels = {'FC1','FC3','C1','C3','F3','F4','P3','P4'};
end
nChan = numel(labels);
rng(42);
EEG = makeEEG(nChan, numel(times), 40, labels, times);
end

function loadFcn = wrapEEG(EEG)
% Returns a loadFcn that always returns the same EEG regardless of path.
loadFcn = @(~) EEG;
end

% ── tests ──────────────────────────────────────────────────────────────────

function test_outputTableHasCorrectColumns(testCase)
% Results table must have exactly the columns in the spec.
EEG     = makeEpochedEEG();
roiElec = {'FC1','FC3','C1','C3'};
[T, ~]  = batchTEPExtract({'dummy.set'}, roiElec, ...
    'loadFcn', wrapEEG(EEG));
expectedCols = {'file','roi_electrodes','component','polarity','found', ...
    'latency_ms','amplitude_uv','win_start_ms','win_end_ms', ...
    'nom_latency_ms','n_trials','n_channels_roi'};
testCase.verifyEqual(T.Properties.VariableNames, expectedCols, ...
    'Output table must have exactly the specified column names');
end

function test_sixRowsPerFile(testCase)
% Default 6-component config: one file → 6 rows.
EEG = makeEpochedEEG();
[T, ~] = batchTEPExtract({'sub01.set'}, {'FC1','C1'}, ...
    'loadFcn', wrapEEG(EEG));
testCase.verifyEqual(height(T), 6, 'Default config must produce 6 rows per file');
end

function test_twoFilesTwelveRows(testCase)
% Two files → 12 rows.
EEG = makeEpochedEEG();
[T, ~] = batchTEPExtract({'s1.set','s2.set'}, {'FC1','C1'}, ...
    'loadFcn', wrapEEG(EEG));
testCase.verifyEqual(height(T), 12, 'Two files must produce 12 rows');
end

function test_foundColumnIsNumeric(testCase)
% 'found' must be double 0/1 so Excel/R can filter numerically.
EEG = makeEpochedEEG();
[T, ~] = batchTEPExtract({'s.set'}, {'FC1','C1'}, 'loadFcn', wrapEEG(EEG));
testCase.verifyClass(T.found, 'double', '''found'' column must be double');
testCase.verifyTrue(all(T.found == 0 | T.found == 1), ...
    '''found'' must contain only 0 or 1');
end

function test_nanRowsForMissingROI(testCase)
% When no ROI electrode exists in the file, rows must be NaN and not crash.
EEG = makeEpochedEEG({'Cz','Fz','Pz'});  % ROI electrodes not in this set
roiElec = {'FC1','FC3'};
[T, warns] = batchTEPExtract({'s.set'}, roiElec, 'loadFcn', wrapEEG(EEG));
testCase.verifyEqual(height(T), 6, 'Must still produce 6 NaN rows for missing ROI');
testCase.verifyTrue(all(isnan(T.latency_ms)), 'latency_ms must be NaN for missing ROI');
testCase.verifyTrue(all(T.n_channels_roi == 0), 'n_channels_roi must be 0 for missing ROI');
testCase.verifyFalse(isempty(warns), 'A warning must be returned for missing ROI');
end

function test_skipNonEpochedFile(testCase)
% Continuous data (trials==1) must be skipped with a warning.
EEG = makeEpochedEEG();
EEG.trials = 1;  % make it look continuous
[T, warns] = batchTEPExtract({'s.set'}, {'FC1','C1'}, 'loadFcn', wrapEEG(EEG));
testCase.verifyEqual(height(T), 6, 'Must produce 6 NaN rows for non-epoched file');
testCase.verifyTrue(all(T.found == 0), 'found must be 0 for skipped file');
testCase.verifyFalse(isempty(warns), 'A warning must be returned for non-epoched file');
end

function test_partialROIWarning(testCase)
% File with 2 of 4 requested ROI channels → n_channels_roi=2 and warning.
EEG = makeEpochedEEG({'FC1','C1','Cz','Pz'});  % only FC1 and C1 match
roiElec = {'FC1','FC3','C1','C3'};             % FC3,C3 absent
[T, warns] = batchTEPExtract({'s.set'}, roiElec, 'loadFcn', wrapEEG(EEG));
testCase.verifyEqual(T.n_channels_roi(1), 2, ...
    'n_channels_roi must reflect the number of ROI channels actually found');
testCase.verifyFalse(isempty(warns), 'Partial ROI must produce a warning');
end

function test_loadErrorGraceful(testCase)
% If loadFcn throws for one file, NaN rows are added and processing continues.
EEG = makeEpochedEEG();
% Use filename to decide: 'bad' → throw, anything else → good EEG
mixedLoad = @(fp) loadByName(fp, EEG);
[T, warns] = batchTEPExtract({'bad.set','good.set'}, {'FC1','C1'}, ...
    'loadFcn', mixedLoad);
testCase.verifyEqual(height(T), 12, 'Must produce rows for both files even if one fails');
testCase.verifyFalse(isempty(warns), 'Load failure must produce a warning');
goodRows = T(strcmp(T.file, 'good'), :);
testCase.verifyFalse(isempty(goodRows), 'Second file rows must be present');
end

function test_csvRoundTrip(testCase)
% Write CSV and read it back — numeric values must match to 4 decimal places.
EEG = makeEpochedEEG();
csvPath = [tempname, '.csv'];
cleanup = onCleanup(@() deleteIfExists(csvPath));
[Torig, ~] = batchTEPExtract({'s.set'}, {'FC1','C1'}, ...
    'loadFcn', wrapEEG(EEG), 'csvPath', csvPath);
testCase.verifyTrue(exist(csvPath,'file') == 2, 'CSV file must be created');
Tread = readtable(csvPath, 'TextType', 'string');
testCase.verifyEqual(height(Tread), height(Torig), 'Row count must match after round-trip');
% Numeric columns that have valid data (found==1)
foundMask = Torig.found == 1;
if any(foundMask)
    testCase.verifyEqual(Tread.latency_ms(foundMask), Torig.latency_ms(foundMask), ...
        'AbsTol', 1e-3, 'latency_ms must survive CSV round-trip');
end
end

function test_deterministicOutput(testCase)
% Same inputs, same rng state → identical results table.
rng(42);
EEG = makeEpochedEEG();
rng(42);
[T1, ~] = batchTEPExtract({'s.set'}, {'FC1','C1'}, 'loadFcn', wrapEEG(EEG));
rng(42);
EEG = makeEpochedEEG();
rng(42);
[T2, ~] = batchTEPExtract({'s.set'}, {'FC1','C1'}, 'loadFcn', wrapEEG(EEG));
testCase.verifyEqual(T1.latency_ms, T2.latency_ms, 'AbsTol', 1e-9, ...
    'batchTEPExtract must be deterministic given fixed rng state');
end

function test_consistencyWithTepPeakFinder(testCase)
% Per-file result must match a direct tepPeakFinder call on the same waveform.
if isempty(which('tesa_peakanalysis'))
    testCase.assumeFail('TESA not available — skipping consistency check');
end
rng(42);
EEG = makeEpochedEEG({'FC1','C1'});
roiElec = {'FC1','C1'};

% Compute what batchTEPExtract should produce
[T, ~] = batchTEPExtract({'s.set'}, roiElec, 'loadFcn', wrapEEG(EEG));

% Compute the reference directly
roiIdx   = find(ismember({EEG.chanlocs.labels}, roiElec));
roiData  = mean(EEG.data(roiIdx, :, :), 1);
waveform = mean(roiData, 3);
waveform = smoothdata(waveform, 'movmean', 5);
refPeaks = tepPeakFinder(waveform, EEG.times);

% Compare found/latency for each component
for ci = 1:numel(refPeaks)
    pk   = refPeaks(ci);
    row  = T(strcmp(T.component, pk.name), :);
    testCase.verifyEqual(row.found(1), double(pk.found), ...
        sprintf('%s: found must match direct tepPeakFinder call', pk.name));
    if pk.found
        testCase.verifyEqual(row.latency_ms(1), pk.latencyMs, 'AbsTol', 1e-6, ...
            sprintf('%s: latency_ms must match direct tepPeakFinder call', pk.name));
    end
end
end

% ── teardown helpers ───────────────────────────────────────────────────────

function deleteIfExists(path)
if exist(path, 'file'); delete(path); end
end

function E = loadByName(fp, goodEEG)
% Return goodEEG for any path not containing 'bad', throw for 'bad'.
[~, nm] = fileparts(fp);
if strcmp(nm, 'bad')
    error('test:loadFail', 'Simulated load failure');
end
E = goodEEG;
end
