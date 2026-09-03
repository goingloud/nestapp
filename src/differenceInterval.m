% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function est = differenceInterval(A, B, design, level)
% DIFFERENCEINTERVAL  B minus A, with a confidence interval on the difference.
%   est = DIFFERENCEINTERVAL(A, B, design) takes two subject-by-time matrices
%   and returns the contrast between them.
%
%   est fields:
%     .mean  1xT difference (B - A)
%     .lo    1xT lower bound
%     .hi    1xT upper bound
%     .sem   1xT standard error of the difference
%     .n     subjects the contrast rests on
%     .df    degrees of freedom used
%     .note  short human label, e.g. 'paired, 95% CI'
%
%   The interval is computed on the difference, never carried over from the two
%   groups' own intervals, because they answer different questions: two heavily
%   overlapping group bands can have a difference nowhere near zero, and two
%   tight ones can have a difference that straddles it. Reading a contrast off
%   a pair of overlapping bands is the commonest way to misread this kind of
%   figure.
%
%   design:
%     'paired'    Rows are the same subjects in the same order. The
%                 per-subject differences are taken first and the interval is
%                 their own standard error - the between-subject spread is
%                 irrelevant to a within-subject contrast.
%     'unpaired'  Two-sample standard error sqrt(s1^2/n1 + s2^2/n2) with
%                 Welch-Satterthwaite degrees of freedom, so unequal group
%                 sizes and unequal variances do not quietly narrow the band.
%
%   This lives next to curveInterval rather than inside the drawing code that
%   first needed it: it is an estimator, the window-bars view and the exported
%   measures need exactly the same numbers, and a statistic computed inside a
%   plot function gets silently reimplemented the moment a second view wants it.
%
%   An interval that excludes zero is not a significance test and is not
%   labelled as one - this app reports estimates, not p-values.
%
%   See also: curveInterval, tCritical, drawDifferenceWave

if nargin < 3 || isempty(design); design = 'unpaired'; end
if nargin < 4 || isempty(level);   level  = 0.95;       end
alpha = 1 - level;

if strcmpi(design, 'paired')
    if size(A, 1) ~= size(B, 1)
        error('nestapp:pairedGroupsUnequal', ...
            ['A paired difference needs the same subjects in both groups, ' ...
             'but got %d and %d rows. Pass complete cases only.'], ...
            size(A, 1), size(B, 1));
    end
    D    = B - A;
    n    = size(D, 1);
    mu   = mean(D, 1, 'omitnan');
    sem  = std(D, 0, 1, 'omitnan') / sqrt(n);
    df   = n - 1;                        % scalar broadcasts through tCritical
    note = sprintf('paired, %s', ciLabel(level));
else
    n1 = size(A, 1);
    n2 = size(B, 1);
    mu = mean(B, 1, 'omitnan') - mean(A, 1, 'omitnan');
    v1 = var(A, 0, 1, 'omitnan') / n1;
    v2 = var(B, 0, 1, 'omitnan') / n2;
    sem = sqrt(v1 + v2);
    df  = (v1 + v2).^2 ./ (v1.^2 / max(n1 - 1, 1) + v2.^2 / max(n2 - 1, 1));
    n    = min(n1, n2);
    note = sprintf('unpaired, %s', ciLabel(level));
end

est = struct('mean', mu, 'lo', nan(size(mu)), 'hi', nan(size(mu)), ...
             'sem', sem, 'n', n, 'df', df, 'note', note);
if n < 2
    return   % nothing to estimate spread from; NaN bounds rather than a guess
end

t      = tCritical(df, alpha);
est.lo = mu - t .* sem;
est.hi = mu + t .* sem;
end
