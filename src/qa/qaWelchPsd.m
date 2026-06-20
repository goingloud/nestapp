
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [pxx, f, fsEff] = qaWelchPsd(x, fs)
% QAWELCHPSD  Bounded Welch power-spectral-density of one signal, for QA.
%   [pxx, f, fsEff] = QAWELCHPSD(x, fs) returns an averaged Welch PSD of the
%   vector x (sampled at fs Hz), specified in FREQUENCY terms so its cost is
%   bounded regardless of the sample rate, epoch count, or recording length of
%   the input. fsEff is the working rate after any downsampling (== fs when none
%   was needed), so callers can disclose it on the figure.
%
%   Why this exists: the unbounded default, pwelch(x,[],[],[],fs), sizes its FFT
%   from the data length (nfft ~ 2^nextpow2(N/4.5)). On raw 5 kHz, many-trial
%   data that is ~10^5 frequency bins per signal - which, multiplied across
%   channels and rasterized by exportgraphics, hangs a headless parallel worker
%   (see renderQualityFigure/drawPSD). It is also a poor estimate: the whole-file
%   periodogram is an INCONSISTENT estimator (its variance does not shrink as N
%   grows), so "more frequency points" buys noise, not accuracy.
%
%   What it does instead, in two frequency-domain steps:
%     1. Bandwidth - anti-alias DOWNSAMPLE high-rate data to ~PSD_TARGET_RATE_HZ
%        (integer factor). The displayed bandwidth is then that rate's Nyquist
%        (~500 Hz at 1 kHz), which is ample for QA - the neural band plus the
%        line-noise harmonics and the onset of broadband muscle; nothing above is
%        informative. This also shrinks the data, so memory stays small.
%     2. Resolution / averaging - size the Welch window from PSD_RES_HZ
%        (resolution = 1/window), so nfft tracks rate/resolution, never the
%        recording length. On a long record the short window yields MANY Welch
%        segments to average, and averaging (not point count) is what drives a
%        low-variance, consistent estimate (Welch 1967).
%
%   It degrades gracefully on any input: fs <= PSD_TARGET_RATE_HZ -> no
%   downsampling (never upsamples); a short signal -> the window clamps to its
%   length while still averaging over several segments.
%
%   See also: renderQualityFigure, computeICAQualityMetrics, pwelch

% ---- QA spectrum constants (edit here to change every QA PSD) ----------------
PSD_TARGET_RATE_HZ = 1000;  % working rate for the QA PSD (Hz). Higher-rate data
                            % is anti-alias downsampled to ~this, so the shown
                            % bandwidth is its Nyquist (~500 Hz at 1 kHz): the
                            % neural band plus line harmonics and muscle onset,
                            % and nothing uninformative above. Mirrors the
                            % pipeline's own 1 kHz downsample.
PSD_RES_HZ         = 1;     % Welch frequency resolution = 1 / window-duration
                            % (Hz). 1 Hz resolves every QA feature while keeping
                            % the window short, which maximises averaging (and so
                            % accuracy) on a long recording. Lower it for sharper
                            % features at the cost of fewer averages.
% -----------------------------------------------------------------------------

    x = double(x(:));
    q = max(1, floor(fs / PSD_TARGET_RATE_HZ));   % integer factor; >=1, never upsamples
    if q > 1
        x = resample(x, 1, q);                    % anti-aliased downsample
    end
    fsEff = fs / q;

    % Window from the target resolution, but never more than ~1/4 of the signal,
    % so a SHORT input still yields several Welch segments to average over (a
    % long input is unaffected and keeps the full PSD_RES_HZ resolution). Floored
    % at 256 samples and never longer than the signal.
    winLen = min(round(fsEff / PSD_RES_HZ), floor(numel(x) / 4));
    winLen = min(numel(x), max(256, winLen));
    [pxx, f] = pwelch(x, hamming(winLen), [], winLen, fsEff);
end
