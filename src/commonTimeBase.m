% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [t, idx, info] = commonTimeBase(times, labels)
% COMMONTIMEBASE  One time vector every file can be compared on.
%   [t, idx, info] = COMMONTIMEBASE(times) takes a cell array of per-file time
%   vectors (ms) and returns the time base they share, plus the indices that
%   crop each file onto it.
%
%   This exists because the app used to have no answer to the question. The
%   loader assigned the app's time base inside its loop, so the app's
%   idea of time was whatever the LAST file happened to have. Files with a
%   different epoch length or sample rate were then plotted and averaged
%   against the wrong time axis - silently, because the curves still have the
%   same number of points as the axis they are drawn on only by coincidence,
%   and are simply wrong when they do not.
%
%   Policy, in order of severity:
%
%     Sample rate differs      -> error. Resampling changes the data, so it is
%                                 the caller's decision to make deliberately
%                                 upstream, not something to do behind their
%                                 back mid-comparison.
%     Epoch extent differs     -> crop to the overlap and say so in info. This
%                                 is common and harmless (a -1000..1000 ms file
%                                 next to a -500..500 ms one), as long as the
%                                 result reports what it did.
%     No overlap at all        -> error; there is nothing to compare.
%
%   Inputs:
%     times  - 1xN cell of numeric time vectors, in milliseconds.
%     labels - optional 1xN cellstr naming each file, used in error messages so
%              the user is told WHICH file disagrees.
%
%   Outputs:
%     t    - 1xM common time vector (ms).
%     idx  - 1xN cell; idx{i} indexes times{i} onto t, so curve_i(idx{i}) is
%            aligned to t.
%     info - .cropped   true when the extent was narrowed
%            .range     [tMin tMax] of the result
%            .fs        the shared sample rate (Hz)
%            .nDropped  1xN samples dropped from each input
%
%   See also: groupCurves, tepFieldCurve

if nargin < 2 || isempty(labels)
    labels = arrayfun(@(k) sprintf('file %d', k), 1:numel(times), ...
                      'UniformOutput', false);
end

t    = [];
idx  = {};
info = struct('cropped', false, 'range', [NaN NaN], 'fs', NaN, 'nDropped', []);

if isempty(times); return; end

n  = numel(times);
dt = zeros(1, n);
for i = 1:n
    v = times{i}(:)';
    if numel(v) < 2
        error('nestapp:timeBaseTooShort', ...
              '%s has fewer than two samples, so it has no time base.', labels{i});
    end
    dt(i) = median(diff(v));
end

% Sample rate: compare against the first, with a tolerance that is loose enough
% for float noise in a stored times vector and far tighter than any real rate
% difference (1000 vs 500 Hz is a factor of two).
TOL = 1e-6;
bad = find(abs(dt - dt(1)) > TOL * max(abs(dt(1)), 1), 1);
if ~isempty(bad)
    error('nestapp:sampleRateMismatch', ...
        ['%s is sampled at %.4g Hz but %s is at %.4g Hz. Resample them to a ' ...
         'common rate before comparing - doing it here would silently alter ' ...
         'the data behind the comparison.'], ...
        labels{1}, 1000 / dt(1), labels{bad}, 1000 / dt(bad));
end

% Overlapping extent.
starts = cellfun(@(v) v(1),   times);
stops  = cellfun(@(v) v(end), times);
lo     = max(starts);
hi     = min(stops);
if hi <= lo
    [~, iEarly] = min(stops);
    [~, iLate]  = max(starts);
    error('nestapp:noTimeOverlap', ...
        ['%s ends at %.4g ms and %s starts at %.4g ms, so the selected files ' ...
         'share no common time range.'], ...
        labels{iEarly}, stops(iEarly), labels{iLate}, starts(iLate));
end

% Use the first file's grid, cropped to the overlap, as the reference; every
% other file is matched onto it by nearest sample. With equal sample rates the
% grids differ only by their offset, so this is an index shift, not resampling.
ref  = times{1}(:)';
keep = ref >= lo - TOL & ref <= hi + TOL;
t    = ref(keep);

% Map each file onto t by arithmetic, not by search. The sample rates are
% already known to agree, so the grids differ only by offset and the nearest
% sample is round((t - v(1))/dt) + 1.
%
% The obvious min(abs(v(:) - t(:)')) instead builds an nV-by-nT matrix per
% file: at 2000 samples that is 31 MB of temporaries each, and it dominated
% this function, which dominated the whole re-render path. Measured over 12
% real files, 36.3 ms became 0.8 ms for bit-identical indices - and this runs
% on every ROI, mode and window change, so it is the difference between a
% redraw that feels instant and one that does not.
idx      = cell(1, n);
nDropped = zeros(1, n);
for i = 1:n
    v = times{i}(:)';
    if numel(v) == numel(t) && v(1) == t(1)
        idx{i} = 1:numel(t);          % the common case: nothing to map
    else
        k      = round((t - v(1)) / dt(1)) + 1;
        idx{i} = min(max(k, 1), numel(v));   % clamp against rounding at the ends
    end
    nDropped(i) = numel(v) - numel(t);
end

info.cropped  = any(nDropped > 0);
info.range    = [t(1) t(end)];
info.fs       = 1000 / dt(1);
info.nDropped = nDropped;
end
