% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function est = intervalAtLevel(est, level)
% INTERVALATLEVEL  Re-express a stored estimate at a different confidence level.
%   est = INTERVALATLEVEL(est, level)
%
%   est    one or more curveInterval / differenceInterval estimates, carrying
%          .mean .sem .df (and .note, where the source wrote one)
%   level  the confidence level wanted, e.g. 0.90. Empty or 0.95 - and an
%          estimate with no usable .sem or .df - leaves it untouched
%
%   THE CONFIDENCE LEVEL IS A DRAW DECISION, and this is why. In both
%   curveInterval and differenceInterval the bounds are exactly
%   mean -/+ tCritical(df, alpha) .* sem, and everything expensive is already
%   inside .sem: the collapse to one curve per subject, the standard error, the
%   paired Cousineau-Morey normalisation and Morey's sqrt(J/(J-1)) correction.
%   None of that depends on the level. So any level costs one scalar betaincinv
%   per estimate, needs nothing precomputed or cached, and supports an
%   arbitrary level rather than a fixed menu.
%
%   THE NOTE IS RE-RENDERED WITH THE BOUNDS. differenceInterval stores a
%   pre-formatted '.note' - 'unpaired, 95% CI' - which drawDifferenceWave puts
%   in its title and the provenance footer stamps into an exported figure. A
%   90% band under a title reading 95% is the one failure that does real
%   damage, because both halves look right on their own and the figure
%   outlives the session. Deriving the two together here is what makes them
%   impossible to separate.
%
%   Not folded into the draw functions: three of them render an interval, and
%   three copies of "negate, re-derive, relabel" is three chances for one to
%   keep the old note.
%
%   See also: curveInterval, differenceInterval, tCritical, drawTEPOverlay

if nargin < 2 || isempty(level) || isempty(est); return; end
level = double(level(1));
if ~isfinite(level) || level <= 0 || level >= 1
    error('nestapp:badLevel', ...
          'A confidence level must lie strictly between 0 and 1; got %g.', level);
end

alpha = 1 - level;
for k = 1:numel(est)
    e = est(k);
    if ~isfield(e, 'sem') || isempty(e.sem) || ~isfield(e, 'df') || isempty(e.df)
        continue
    end
    if isfield(e, 'lo') && ~isempty(e.lo) && all(isnan(e.lo(:)))
        % The source reported no interval - one subject, nothing to estimate
        % spread from. Rescaling nothing would invent a band for n = 1, which
        % is worse than showing none. Deferring to what the source decided
        % also keeps the rule in one place instead of re-testing n here.
        continue
    end
    % Elementwise throughout: an unpaired difference carries a
    % Welch-Satterthwaite df PER SAMPLE, not one scalar, and tCritical is
    % vectorised for exactly that.
    t = tCritical(e.df, alpha);
    est(k).lo = e.mean - t .* e.sem;
    est(k).hi = e.mean + t .* e.sem;
    if isfield(e, 'note') && ~isempty(e.note)
        % Keep whatever the source called the design, replace only the level.
        est(k).note = regexprep(e.note, '[\d.]+%\s*CI', ciLabel(level));
    end
end
end
