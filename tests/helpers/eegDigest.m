
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
        [d.dataSum, d.dataMean, d.dataStd, d.dataMin, d.dataMax] = deal(NaN);
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
    [d.dataSum, d.dataMean, d.dataStd, d.dataMin, d.dataMax] = deal(NaN);
    d.dataSamples = [];
end

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
