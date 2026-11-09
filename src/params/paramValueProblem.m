% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function why = paramValueProblem(meta, v)
% PARAMVALUEPROBLEM  Why one typed value is not acceptable, or '' when it is.
%   why = PARAMVALUEPROBLEM(meta, v) checks v against its own declaration in
%   makeParam: a mode key, a choice key, the limits (and openMin), integer and
%   step, and that a two-element range runs low to high.
%
%   The sentence names the rule ("must be at least 2", "must be even"), because
%   the form shows it next to the refused edit and that is all the user has.
%
%   See also: paramProblems, makeParam

why = '';
if ~isempty(meta.modes) && ischar(v)
    if ~any(strcmp(v, {meta.modes.key}))
        why = sprintf('"%s" is not one of its options.', v);
    end
    return
end
if ~isempty(meta.choices)
    if ~ischar(v) || ~any(strcmp(v, {meta.choices.key}))
        why = sprintf('must be one of: %s.', strjoin({meta.choices.label}, ', '));
    end
    return
end
switch meta.type
    case 'logical'
        if ~(islogical(v) && isscalar(v)), why = 'must be on or off.'; end
    case {'scalar', 'integer', 'vector'}
        if isempty(v), return; end
        if ~isnumeric(v) || any(isnan(v(:)))
            why = 'must be a number.'; return
        end
        lim = meta.limits;
        if ~isempty(lim)
            if any(v < lim(1)) || (meta.openMin && any(v == lim(1)))
                why = sprintf('must be %s %g.', ternary(meta.openMin, 'above', 'at least'), lim(1));
                return
            end
            if any(v > lim(2)), why = sprintf('must be at most %g.', lim(2)); return; end
        end
        if strcmp(meta.type, 'integer') && any(v ~= round(v))
            why = 'must be a whole number.'; return
        end
        % A step counts from the lower limit, as a spinner does: from 2 in
        % steps of 2 is the even orders a Butterworth design accepts.
        if ~isempty(meta.step) && ~isempty(lim) && any(mod(v - lim(1), meta.step) ~= 0)
            if meta.step == 2 && mod(lim(1), 2) == 0
                why = 'must be even.';
            else
                why = sprintf('must be %g, %g, %g, ...', lim(1), lim(1) + meta.step, lim(1) + 2*meta.step);
            end
            return
        end
        if strcmp(meta.type, 'vector') && numel(v) == 2 && ~(v(1) < v(2))
            why = 'the first value must be below the second.';
        end
end
end
