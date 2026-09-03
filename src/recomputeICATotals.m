
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function ica = recomputeICATotals(ica)
% RECOMPUTEICATOTALS  Derive top-level ICA report fields from the per-round records.
%   ica = RECOMPUTEICATOTALS(ica)
%
%   With ICA recorded one round per decomposition (see openICARound /
%   addICARemoval), the top-level summary fields are derived from the rounds:
%     nComponents - the first (original) decomposition's component count
%     nRejected   - total components removed across all rounds
%     nKept       - components surviving the FINAL round (that round's
%                   nComponents - nRejected). This does NOT generally equal
%                   nComponents - nRejected: each round re-decomposes the data
%                   the previous round left, and the new decomposition is sized
%                   by that data's rank, not by how many components were
%                   removed. Remove 11 of 32 components from 32 channels and
%                   the next runica still returns ~32. Only compare component
%                   counts within a round - see buildReportText, which reports
%                   per-round rather than printing a cross-round triple.
%     categories  - union of every round's per-category tally, each round's
%                   share rescaled to the common "% of original variance" basis
%     varRemoved / varMin / varMax - COMPOUNDED across rounds. Variance is not
%                   additive across different ICA bases, so we compound: each
%                   round removes a fraction of the variance ENTERING it (the
%                   residual after earlier rounds), and the total removed is
%                   1 - prod(1 - vr_i/100). Per-category shares and the
%                   per-component range are scaled by the residual entering
%                   their round so everything is on the original-variance basis
%                   and the category shares sum to varRemoved.
%
%   See also: openICARound, addICARemoval, mergeCategories, buildReportText

if isempty(ica.rounds)
    return
end

ica.nComponents = ica.rounds{1}.nComponents;

residual = 1;     % fraction of original evoked variance still present
haveVar  = false;
total    = 0;
cats     = struct('names', {{}}, 'nRemoved', [], 'varShare', []);
vMin     = inf;
vMax     = -inf;

for i = 1:numel(ica.rounds)
    rnd   = ica.rounds{i};
    total = total + rnd.nRejected;

    % This round's per-category shares are relative to the round's own basis;
    % scale them by the residual variance entering the round so the merged
    % shares are all on the original-variance basis (and sum to varRemoved).
    scaled = rnd.categories;
    if isfield(scaled, 'varShare') && ~isempty(scaled.varShare)
        vs = scaled.varShare;
        vs(~isfinite(vs)) = 0;
        scaled.varShare = vs * residual;
    end
    cats = mergeCategories(cats, scaled);

    % Per-component range, likewise rescaled to the original-variance basis.
    if ~isnan(rnd.varMin), vMin = min(vMin, rnd.varMin * residual); haveVar = true; end
    if ~isnan(rnd.varMax), vMax = max(vMax, rnd.varMax * residual); end

    % Compound the residual using the round's total variance removed.
    if ~isnan(rnd.varRemoved)
        residual = residual * (1 - rnd.varRemoved / 100);
        haveVar  = true;
    end
end

ica.nRejected = total;

last      = ica.rounds{end};
ica.nKept = last.nComponents - last.nRejected;

ica.categories = cats;

if haveVar
    ica.varRemoved = 100 * (1 - residual);
    if isfinite(vMin), ica.varMin = vMin; else, ica.varMin = NaN; end
    if isfinite(vMax), ica.varMax = vMax; else, ica.varMax = NaN; end
else
    ica.varRemoved = NaN;
    ica.varMin     = NaN;
    ica.varMax     = NaN;
end
end
