
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function m = computeWindowMeasures(curve, times, t1, t2, polarity)
% COMPUTEWINDOWMEASURES  Mean and peak of a waveform over a time window.
%   m = COMPUTEWINDOWMEASURES(curve, times, t1, t2, polarity) summarises a
%   single curve (TEP/GMFP/LMFP grand mean) over the closed window
%   [min(t1,t2), max(t1,t2)] and returns a struct with fields:
%     .mean        - mean amplitude over the window (NaN if window empty)
%     .peakLatency - time (same units as t1/t2) of the selected extremum
%     .peakAmp     - amplitude at that extremum
%     .found       - true when the window contained at least one sample
%
%   polarity selects which extremum is the "peak":
%     'neg'  -> the minimum (most negative) sample
%     'pos'  -> the maximum sample
%     'auto' or '' (default) -> the sample with the largest absolute value
%
%   The mean reuses computeWindowMean. For modes where a signed peak is not
%   meaningful (GMFP/LMFP) callers simply ignore the peak fields.

    if nargin < 5 || isempty(polarity)
        polarity = 'auto';
    end

    m = struct('mean', NaN, 'peakLatency', NaN, 'peakAmp', NaN, 'found', false);

    lo = min(t1, t2);
    hi = max(t1, t2);
    inWindow = times >= lo & times <= hi;
    if ~any(inWindow)
        return
    end

    m.found = true;
    m.mean  = computeWindowMean(curve, times, t1, t2);

    segVals  = curve(inWindow);
    segTimes = times(inWindow);
    switch lower(polarity)
        case 'neg'
            [m.peakAmp, idx] = min(segVals);
        case 'pos'
            [m.peakAmp, idx] = max(segVals);
        otherwise   % 'auto' - largest absolute deflection, keep its signed value
            [~, idx]  = max(abs(segVals));
            m.peakAmp = segVals(idx);
    end
    m.peakLatency = segTimes(idx);
end
