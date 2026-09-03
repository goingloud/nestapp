% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function t = tCritical(df, alpha)
% TCRITICAL  Two-sided critical value of Student's t, without any toolbox.
%   t = TCRITICAL(df, alpha) returns the value t such that P(|T| > t) = alpha
%   for T distributed as Student's t with df degrees of freedom. alpha defaults
%   to 0.05, giving the multiplier for a 95% confidence interval.
%
%   Why not tinv: tinv needs the Statistics and Machine Learning Toolbox, and a
%   confidence interval is the one number every figure this app produces has to
%   carry. Gating error bars behind a licence - or silently substituting 1.96
%   and mislabelling it - is worse than deriving the value here.
%
%   The derivation uses only betaincinv, which is core MATLAB. For T ~ t(v),
%
%       P(|T| > t) = I_{v/(v+t^2)}(v/2, 1/2)
%
%   where I is the regularised incomplete beta function. Inverting for t:
%
%       z = betaincinv(alpha, v/2, 1/2)   ->   t = sqrt(v*(1-z)/z)
%
%   This agrees with tinv(1-alpha/2, v) to ~1e-14 across df = 1..100.
%
%   df below 1 (a single observation, so no spread to estimate) returns Inf:
%   the interval is undefined, and Inf makes that visible rather than implying
%   a precision that does not exist.
%
%   See also: curveInterval, betaincinv

if nargin < 2 || isempty(alpha); alpha = 0.05; end

t = inf(size(df));
ok = df >= 1;
if any(ok(:))
    v      = df(ok);
    z      = betaincinv(alpha, v / 2, 0.5);
    t(ok)  = sqrt(v .* (1 - z) ./ z);
end
end
