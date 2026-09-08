
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function k = numPCsForVariance(data, frac)
% NUMPCSFORVARIANCE  Number of principal components retaining a variance fraction.
%   k = NUMPCSFORVARIANCE(data, frac) returns the smallest number of principal
%   components whose cumulative share of the channel-covariance eigenvalue
%   spectrum reaches frac (with 0 < frac < 1). This is the "PCA -> X% variance"
%   dimensionality used before ICA (e.g. ARTIST's PCA -> 99.9%, Wu 2018 §2.2.1):
%   after average referencing and channel interpolation the data is
%   rank-deficient, and keeping only the components up to frac drops the
%   near-zero-variance tail so ICA is well-conditioned.
%
%   Inputs:
%     data - channels x samples (x trials; later dims are collapsed).
%     frac - variance fraction in (0, 1), e.g. 0.999.
%
%   Output:
%     k    - component count, clamped to [1, numerical rank].

    X = double(data);
    if ~ismatrix(X)
        X = X(:, :);                 % collapse trials -> channels x (time*trials)
    end
    X = X - mean(X, 2);              % center each channel
    ev = sort(real(eig(cov(X'))), 'descend');
    ev(ev < 0) = 0;                 % numerical floor
    total = sum(ev);
    if total <= 0
        k = size(X, 1);
        return
    end
    cumv = cumsum(ev) / total;
    k = find(cumv >= frac, 1);
    if isempty(k); k = numel(ev); end

    % Never request more components than the numerical rank (the near-zero
    % eigenvalues from average-reference + interpolation are not real dimensions).
    tol = max(size(X)) * eps(max(ev));
    r = max(sum(ev > tol), 1);
    k = max(min(k, r), 1);
end
