function peaks = tepPeakFinder(waveform, times, compDefs)
% TEPPEAKFINDER  Detect TMS-EEG components in a grand-mean TEP waveform.
%
%   peaks = tepPeakFinder(waveform, times) uses the default canonical
%   component windows (Rogasch et al. 2013; Farzan 2016).
%
%   peaks = tepPeakFinder(waveform, times, compDefs) uses the search
%   windows defined in compDefs, a struct array with fields:
%     .name        — component label string (e.g. 'N15')
%     .polarity    — 'neg' or 'pos'
%     .nomLatency  — nominal peak latency in ms
%     .winStart    — search window start in ms
%     .winEnd      — search window end in ms
%
%   Inputs
%     waveform  1×T numeric vector — the ROI-averaged grand-mean TEP (µV)
%     times     1×T numeric vector — corresponding time points (ms)
%     compDefs  (optional) struct array — custom component definitions
%
%   Output
%     peaks     1×N struct array with fields:
%                 name        — component label
%                 polarity    — 'neg' or 'pos'
%                 latencyMs   — detected peak latency in ms (NaN if not found)
%                 amplitudeUV — detected peak amplitude in µV (NaN if not found)
%                 found       — logical scalar
%
%   Implementation: delegates to tesa_peakanalysis when TESA is on the path;
%   falls back to a findpeaks-based implementation (Signal Processing Toolbox)
%   when TESA is unavailable. Results are equivalent for typical TEP waveforms.
%
%   See also: nestapp, overlayTEPComponents, populateTEPComponentTable

if nargin < 3 || isempty(compDefs)
    % Default canonical windows (Rogasch 2013 Clin Neurophysiol; Farzan 2016)
    compDefs = struct( ...
        'name',       {'N15',  'P30',  'N45',  'P60',  'N100', 'P180'}, ...
        'polarity',   {'neg',  'pos',  'neg',  'pos',  'neg',  'pos'}, ...
        'nomLatency', {15,     30,     45,     60,     100,    180}, ...
        'winStart',   {5,      22,     38,     50,     80,     140}, ...
        'winEnd',     {28,     50,     65,     90,     140,    260});
end

waveform = waveform(:)';
times    = times(:)';

% Pre-allocate output
blank = struct('name','','polarity','','latencyMs',NaN,'amplitudeUV',NaN,'found',false);
peaks = repmat(blank, 1, numel(compDefs));
for k = 1:numel(compDefs)
    peaks(k).name     = compDefs(k).name;
    peaks(k).polarity = compDefs(k).polarity;
end

if ~isempty(which('tesa_peakanalysis'))
    peaks = detectWithTESA(peaks, waveform, times, compDefs);
else
    peaks = detectWithFindpeaks(peaks, waveform, times, compDefs);
end
end

%% ---- TESA path ---------------------------------------------------------------

function peaks = detectWithTESA(peaks, waveform, times, compDefs)
% Delegate to tesa_peakanalysis via a minimal EEG stub.
COMP_POL = {compDefs.polarity};

EEGstub.times          = times;
EEGstub.ROI.R1.tseries = waveform;

isNeg = strcmp(COMP_POL, 'neg');
isPos = strcmp(COMP_POL, 'pos');

negDefs = compDefs(isNeg);
posDefs = compDefs(isPos);

NEG_PEAKS = [negDefs.nomLatency];
POS_PEAKS = [posDefs.nomLatency];
NEG_WINS  = buildWinMatrix(negDefs);
POS_WINS  = buildWinMatrix(posDefs);

% evalc suppresses per-peak fprintf messages from tesa_peakanalysis.
try
    if ~isempty(NEG_PEAKS)
        EEGstub = evalTESA(EEGstub, 'negative', NEG_PEAKS, NEG_WINS);
    end
    if ~isempty(POS_PEAKS)
        EEGstub = evalTESA(EEGstub, 'positive', POS_PEAKS, POS_WINS);
    end
catch ME
    warning('tepPeakFinder:tesaFailed', ...
        'tesa_peakanalysis failed (%s) — falling back to findpeaks.', ME.message);
    peaks = detectWithFindpeaks(peaks, waveform, times, compDefs);
    return
end

for k = 1:numel(compDefs)
    compName = compDefs(k).name;
    if ~isfield(EEGstub.ROI.R1, compName)
        continue
    end
    c = EEGstub.ROI.R1.(compName);
    peaks(k).found       = strcmp(c.found, 'yes');
    peaks(k).latencyMs   = c.lat;
    peaks(k).amplitudeUV = c.amp;
end
end

function EEGout = evalTESA(EEGin, direction, peakVec, winMat)
% Wrapper that calls tesa_peakanalysis and captures its text output.
EEGout = tesa_peakanalysis(EEGin, 'ROI', direction, peakVec, winMat);
end

%% ---- findpeaks fallback -------------------------------------------------------

function peaks = detectWithFindpeaks(peaks, waveform, times, compDefs)
% Per-component peak search using Signal Processing Toolbox findpeaks.
% Finds the largest local maximum (positive) or minimum (negative) within
% each component's search window. A point is a local extremum if it is
% more prominent than 5% of the signal range in that window.
SIGNAL_RANGE = max(waveform) - min(waveform);
MIN_PROM     = max(0.05 * SIGNAL_RANGE, 0.1);   % µV; avoids noise spikes

for k = 1:numel(compDefs)
    cd    = compDefs(k);
    tMask = times >= cd.winStart & times <= cd.winEnd;
    if sum(tMask) < 3
        continue
    end
    seg  = waveform(tMask);
    tSeg = times(tMask);

    if strcmp(cd.polarity, 'neg')
        [pkVals, pkIdx] = findpeaks(-seg, 'MinPeakProminence', MIN_PROM);
        pkVals = -pkVals;
    else
        [pkVals, pkIdx] = findpeaks(seg, 'MinPeakProminence', MIN_PROM);
    end

    if isempty(pkVals)
        continue
    end

    % Take the largest absolute peak in the window
    [~, best]              = max(abs(pkVals));
    peaks(k).found         = true;
    peaks(k).latencyMs     = tSeg(pkIdx(best));
    peaks(k).amplitudeUV   = pkVals(best);
end
end

%% ---- helpers -----------------------------------------------------------------

function W = buildWinMatrix(defs)
W = zeros(numel(defs), 2);
for k = 1:numel(defs)
    W(k, :) = [defs(k).winStart, defs(k).winEnd];
end
end
