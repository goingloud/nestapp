
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function T = tepWindowTable(fileLabels, curves, time, windows, mode)
% TEPWINDOWTABLE  Per-file x per-window measures as a MATLAB table.
%   T = TEPWINDOWTABLE(fileLabels, curves, time, windows, mode) builds one row
%   per (file, window): the window Mean of that file's curve, plus - for TEP
%   mode - the peak latency and amplitude. Shared by the Analysis tab's
%   workspace export and the batch CSV so both produce identical schemas.
%
%   Inputs:
%     fileLabels - 1xnFiles cellstr of file names.
%     curves     - nFiles x nTime matrix; row f is that file's curve already
%                  reduced for the active mode (see tepFieldCurve).
%     time       - 1xnTime time vector (ms).
%     windows    - struct array with fields name, winStart, winEnd and
%                  (optional) polarity; one entry per window of interest.
%     mode       - 'TEP', 'GMFP' or 'LMFP'. TEP adds peak_ms / peak_uV columns.
%
%   Output:
%     T - table with variables file, window, t1_ms, t2_ms, mean_uV,
%         [peak_ms, peak_uV for TEP], mode.

    isTEP = strcmpi(mode, 'TEP');
    nF = numel(fileLabels);
    nW = numel(windows);
    nRows = nF * nW;

    file   = cell(nRows, 1);
    win    = cell(nRows, 1);
    t1     = zeros(nRows, 1);
    t2     = zeros(nRows, 1);
    meanv  = nan(nRows, 1);
    areav  = nan(nRows, 1);
    peakMs = nan(nRows, 1);
    peakUv = nan(nRows, 1);

    k = 0;
    for f = 1:nF
        for w = 1:nW
            k = k + 1;
            m = computeWindowMeasures(curves(f,:), time, ...
                windows(w).winStart, windows(w).winEnd, windowPolarity(windows(w)));
            file{k}   = fileLabels{f};
            win{k}    = windows(w).name;
            t1(k)     = windows(w).winStart;
            t2(k)     = windows(w).winEnd;
            meanv(k)  = m.mean;
            areav(k)  = m.area;
            peakMs(k) = m.peakLatency;
            peakUv(k) = m.peakAmp;
        end
    end

    T = table(file, win, t1, t2, meanv, ...
        'VariableNames', {'file', 'window', 't1_ms', 't2_ms', 'mean_uV'});
    if isTEP
        T.peak_ms = peakMs;
        T.peak_uV = peakUv;
    else
        % AUC (cumulative field power) is the natural extra measure for GMFP/LMFP.
        T.area_uV_ms = areav;
    end
    T.mode = repmat({upper(char(mode))}, nRows, 1);
end
