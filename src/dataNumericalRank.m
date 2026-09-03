
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function r = dataNumericalRank(data)
% DATANUMERICALRANK  Numerical rank of an EEG data matrix (the well-posed ICA dim).
%   r = DATANUMERICALRANK(data) returns the number of channel-covariance
%   eigenvalues that are meaningfully above the numerical floor - i.e. the
%   number of real spatial dimensions in the data. This is the correct
%   component count to hand ICA after operations that make the montage
%   rank-deficient: an average reference removes exactly one dimension, and
%   every spherically interpolated channel is an exact linear combination of
%   its neighbours (a zero eigenvalue), so neither is counted. Reducing ICA
%   to this rank keeps the decomposition well-conditioned WITHOUT the
%   file-to-file swing of a variance-fraction target (numPCsForVariance),
%   whose component count moves with residual-artifact severity.
%
%   Inputs:
%     data - channels x samples (x trials; later dims are collapsed).
%
%   Output:
%     r    - numerical rank, clamped to >= 1.
%
%   Uses the same eigenvalue tolerance as numPCsForVariance so the two agree
%   on where the near-zero tail begins.
%
%   See also: numPCsForVariance, runIcaEngine

    X = double(data);
    if ~ismatrix(X)
        X = X(:, :);                 % collapse trials -> channels x (time*trials)
    end
    X = X - mean(X, 2);              % center each channel
    ev = sort(real(eig(cov(X'))), 'descend');
    ev(ev < 0) = 0;                 % numerical floor
    if isempty(ev) || max(ev) <= 0
        r = max(size(X, 1), 1);
        return
    end
    tol = max(size(X)) * eps(max(ev));
    r = max(sum(ev > tol), 1);
end
