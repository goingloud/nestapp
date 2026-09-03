
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function d = eegDigest(EEG)
% EEGDIGEST  Compact, comparable fingerprint of an EEG struct.
%   d = EEGDIGEST(EEG) returns a struct of scalars summarising the dataset's
%   shape and its numeric content. Used by the characterization tests to pin
%   what a pipeline step currently does, so a refactor that changes behaviour
%   is caught rather than silently accepted.
%
%   Why scalars and not a hash: a hash tells you only that something changed.
%   These fields tell you WHAT changed - a differing trials count reads very
%   differently from a differing dataStd - which is the difference between a
%   five-minute diagnosis and an afternoon.
%
%   Values are rounded to 9 significant digits. Tighter than that and
%   last-bit floating-point noise makes the comparison flap; looser and a real
%   change can hide inside the rounding.
%
%   No field is ever NaN. Goldens round-trip through JSON, and jsonencode
%   writes NaN as null, which jsondecode reads back as [] - so a NaN would
%   silently change shape between recording and comparison. "Absent" is 0; the
%   count fields (dataNumel, nROI, nGMFA) distinguish absent from genuinely
%   zero.
%
%   See also: test_stepCharacterization, charFixture

d = struct();

% ---- shape -------------------------------------------------------------
d.nbchan = numField(EEG, 'nbchan');
d.pnts   = numField(EEG, 'pnts');
d.trials = numField(EEG, 'trials');
d.srate  = sig(numField(EEG, 'srate'));
d.xmin   = sig(numField(EEG, 'xmin'));
d.xmax   = sig(numField(EEG, 'xmax'));

d.nChanlocs = 0;
if isfield(EEG, 'chanlocs'); d.nChanlocs = numel(EEG.chanlocs); end
d.nEvents = 0;
if isfield(EEG, 'event'); d.nEvents = numel(EEG.event); end

% ---- numeric content ---------------------------------------------------
% Statistics over the whole data array. Sum and std catch amplitude changes;
% min/max catch clipping and interpolation; the sampled values catch a
% reordering that leaves the aggregate statistics untouched.
if isfield(EEG, 'data') && ~isempty(EEG.data)
    x = double(EEG.data(:));
    finite = x(isfinite(x));
    d.dataNumel   = numel(x);
    d.dataNaNs    = sum(isnan(x));
    if isempty(finite)
        [d.dataSum, d.dataMean, d.dataStd, d.dataMin, d.dataMax] = deal(0);
    else
        d.dataSum  = sig(sum(finite));
        d.dataMean = sig(mean(finite));
        d.dataStd  = sig(std(finite));
        d.dataMin  = sig(min(finite));
        d.dataMax  = sig(max(finite));
    end
    d.dataSamples = sig(sampleAcross(x));
else
    d.dataNumel = 0; d.dataNaNs = 0;
    [d.dataSum, d.dataMean, d.dataStd, d.dataMin, d.dataMax] = deal(0);
    d.dataSamples = [];
end

% ---- TEP analysis results ---------------------------------------------
% The TEP steps (Extract TEP, Find TEP Peaks, Peak Output) do not touch
% EEG.data at all - they write EEG.ROI / EEG.GMFA. Without these fields their
% goldens would pin nothing and pass even if extraction broke entirely.
[d.nROI, d.roiTseriesSum, d.nROIPeaks, d.roiPeakLatSum, d.roiPeakAmpSum] = ...
    analysisSummary(EEG, 'ROI');
[d.nGMFA, d.gmfaTseriesSum, d.nGMFAPeaks, d.gmfaPeakLatSum, d.gmfaPeakAmpSum] = ...
    analysisSummary(EEG, 'GMFA');

% ---- ICA ---------------------------------------------------------------
d.nICAComps = 0;
if isfield(EEG, 'icaweights') && ~isempty(EEG.icaweights)
    d.nICAComps = size(EEG.icaweights, 1);
end
d.nFlaggedComps = 0;
if isfield(EEG, 'reject') && isfield(EEG.reject, 'gcompreject') && ...
        ~isempty(EEG.reject.gcompreject)
    d.nFlaggedComps = sum(logical(EEG.reject.gcompreject(:)));
end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function v = numField(s, name)
if isfield(s, name) && ~isempty(s.(name)) && isnumeric(s.(name))
    v = double(s.(name));
    v = v(1);
else
    v = 0;
end
end

function [n, tsum, nPeaks, latSum, ampSum] = analysisSummary(EEG, field)
% Summarise EEG.ROI / EEG.GMFA: how many analyses, the total of their time
% series, and the count and aggregate latency/amplitude of detected peaks.
% TESA names peak sub-structs by polarity and latency (P40, N80, ...), so they
% are found by shape - a struct carrying lat and amp - rather than by name.
n = 0; tsum = 0; nPeaks = 0; latSum = 0; ampSum = 0;
if ~isfield(EEG, field) || ~isstruct(EEG.(field)) || isempty(EEG.(field))
    return
end
names = fieldnames(EEG.(field));
n = numel(names);
tAcc = 0; latAcc = 0; ampAcc = 0;
for i = 1:n
    a = EEG.(field).(names{i});
    if ~isstruct(a); continue; end
    if isfield(a, 'tseries')
        t = a.tseries;
        if iscell(t); t = [t{:}]; end
        v = double(t(:));
        tAcc = tAcc + sum(v(isfinite(v)));
    end
    sub = fieldnames(a);
    for j = 1:numel(sub)
        pk = a.(sub{j});
        if isstruct(pk) && isfield(pk, 'lat') && isfield(pk, 'amp')
            nPeaks = nPeaks + 1;
            latAcc = latAcc + nanSum(pk.lat);
            ampAcc = ampAcc + nanSum(pk.amp);
        end
    end
end
tsum = sig(tAcc); latSum = sig(latAcc); ampSum = sig(ampAcc);
end

function s = nanSum(v)
if iscell(v); v = [v{:}]; end
v = double(v(:));
v = v(isfinite(v));
if isempty(v); s = 0; else; s = sum(v); end
end

function v = sampleAcross(x)
% Sixteen values spread across the array. Evenly spaced rather than the first
% N, so a change confined to (say) the last trial cannot slip past.
n = numel(x);
if n == 0; v = []; return; end
idx = unique(round(linspace(1, n, min(16, n))));
v = x(idx)';
end

function y = sig(x)
% Round to 9 significant digits, elementwise, NaN/Inf-safe.
y = x;
m = isfinite(x) & x ~= 0;
if any(m(:))
    e = floor(log10(abs(x(m))));
    y(m) = round(x(m) .* 10.^(8 - e)) ./ 10.^(8 - e);
end
end
