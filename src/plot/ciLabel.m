% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = ciLabel(level)
% CILABEL  The coverage phrase for a confidence level: 0.95 -> '95% CI'.
%   s = CILABEL(level)
%
%   One place formats this, because it is read off a figure. It appears in
%   differenceInterval's stored .note, in the relabelling intervalAtLevel does
%   when a plot is drawn at another level, and in the Explore status line and
%   the provenance footer stamped into an exported figure. Three independent
%   sprintf('%g%% CI') calls is three chances for the percent convention or
%   the rounding to diverge, and the divergence would show up as two different
%   coverages on one figure.
%
%   No default: a caller that does not know its level cannot label one, and
%   defaulting here would put a fourth copy of 0.95 in the codebase. The
%   default lives in curveInterval and groupCurves, which apply it.
%
%   See also: differenceInterval, intervalAtLevel, curveInterval, tCritical

if isempty(level) || ~isnumeric(level) || ~isscalar(level)
    error('nestapp:badLevel', ...
          'ciLabel needs one numeric confidence level to describe.');
end
s = sprintf('%g%% CI', level * 100);
end
