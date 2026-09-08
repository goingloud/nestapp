% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [same, why] = digestsMatch(expected, actual)
% DIGESTSMATCH  Compare two eegDigest structs and name the first difference.
%   [same, why] = DIGESTSMATCH(expected, actual)
%
%   same  true when every field of `actual` matches `expected` to 1e-6
%   why   '' when same, otherwise which field changed and by how much
%
%   The message is the point. A bare "not equal" on a twenty-field struct tells
%   you a step's behaviour changed but not how, which is the difference between
%   a golden that helps and one that is merely red - and the decision that
%   follows a red golden is whether a step regressed or genuinely improved,
%   which nobody can make without knowing what moved.
%
%   FIELDS ARE NOT ALL SCALARS. A digest carries vectors as well as single
%   numbers, and jsondecode hands arrays back as columns where the recorder
%   wrote rows - so the comparison is over numel plus an elementwise tolerance,
%   with NaN treated as equal to NaN. Writing it as a scalar comparison with
%   && is the obvious mistake and errors on the first vector field it meets.
%
%   Extracted from tests/characterization rather than rewritten: the version
%   that already existed handled all of the above, and a second comparison
%   would eventually disagree with it about what "the same" means. The old
%   file keeps a local copy of this name, which shadows this one, so it goes on
%   working untouched until the cutover deletes it.
%
%   See also: eegDigest, charFixture, recordGoldens

same = true;
why  = '';

fn = fieldnames(actual);
for i = 1:numel(fn)
    f = fn{i};
    if ~isfield(expected, f)
        same = false;
        why  = sprintf('golden has no field "%s"', f);
        return
    end

    a = double(reshape(actual.(f),   1, []));
    e = double(reshape(expected.(f), 1, []));

    if numel(a) ~= numel(e) || ~all(abs(a - e) < 1e-6 | (isnan(a) & isnan(e)))
        same = false;
        why  = sprintf('%s: expected %s, got %s', f, brief(e), brief(a));
        return
    end
end
end

function s = brief(v)
% Enough of a vector to recognise it, without printing six hundred samples.
if isempty(v); s = '[]'; return; end
if numel(v) > 4
    s = sprintf('[%.6g %.6g ... %.6g] (%d vals)', v(1), v(2), v(end), numel(v));
else
    s = ['[' strjoin(arrayfun(@(x) sprintf('%.6g', x), v, ...
                              'UniformOutput', false), ' ') ']'];
end
end
