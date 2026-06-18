
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function m = computeWindowMean(curve, times, t1, t2)
% COMPUTEWINDOWMEAN  Mean of a waveform over a time window.
%   m = COMPUTEWINDOWMEAN(curve, times, t1, t2) returns the mean of curve at
%   the samples whose time (in the same units as t1/t2, e.g. ms) falls within
%   the closed window [min(t1,t2), max(t1,t2)]. Used by the Visualizing tab to
%   report the average amplitude of the displayed TEP/GMFP/LMFP curve over a
%   user-adjustable window.
%
%   Inputs:
%     curve - 1xN numeric waveform.
%     times - 1xN time vector aligned with curve.
%     t1,t2 - window bounds (order-independent).
%
%   Output:
%     m - mean over the window, or NaN when the window contains no samples.

    lo = min(t1, t2);
    hi = max(t1, t2);
    inWindow = times >= lo & times <= hi;
    if ~any(inWindow)
        m = NaN;
        return
    end
    m = mean(curve(inWindow), 'omitnan');
end
