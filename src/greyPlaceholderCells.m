% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function greyPlaceholderCells(tbl)
% GREYPLACEHOLDERCELLS  Grey the value cells of a param table that are not values.
%   GREYPLACEHOLDERCELLS(tbl) styles every row of a two-column param uitable
%   whose value is a PLACEHOLDER rather than a set value, so the table shows at
%   a glance what the user has chosen and what is still the default.
%
%   The convention, which makeParam documents and buildParamTableData produces:
%   a placeholder starts with '(' - '(all channels)', '(600)'. The literal '[]'
%   is the older not-set sentinel and is greyed too, so a param cleared back to
%   unset does not read as a value of "[]".
%
%   Takes a table handle rather than living on the app, so the pipeline's step
%   table and the plot and figure dialogs all grey by the same rule. It had
%   three implementations and two of them had already dropped the '[]' case.
%
%   See also: makeParam, buildParamTableData, plotOptionsDialog

removeStyle(tbl);
T = tbl.Data;
if isempty(T); return; end
grey = uistyle('FontColor', [0.6 0.6 0.6], 'FontAngle', 'italic');

if istable(T)
    values = T.val;          % legacy table-valued Data
else
    values = T(:, 2);
end
for row = 1:numel(values)
    v = values{row};
    if ~(ischar(v) || isstring(v)) || ~isscalar(string(v)); continue; end
    sv = string(v);
    if (strlength(sv) > 0 && startsWith(sv, '(')) || sv == "[]"
        addStyle(tbl, grey, 'cell', [row, 2]);
    end
end
end
