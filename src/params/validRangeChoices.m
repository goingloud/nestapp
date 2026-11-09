% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function choices = validRangeChoices(meta)
% VALIDRANGECHOICES  The closed list a text-era validRange names, or {}.
%   choices = VALIDRANGECHOICES(meta) splits a validRange such as
%   'off|warn|remove|error' into its tokens. Returns {} when the validRange is
%   not a closed list of tokens - a range ('[0 Inf]'), a hint ('integer >= 1')
%   or a list with a free-form member ('automatic|[value]').
%
%   For steps not yet converted to typed settings (schema 1), which declare
%   their choices only in this text. The one reading of it, shared by the
%   settings form and the argument-capture tool.
%
%   See also: settingsForm, makeParam

choices = {};
vr = meta.validRange;
if ~contains(vr, '|') || contains(vr, '[')
    return
end
parts = strtrim(strsplit(vr, '|'));
token = @(c) ~isempty(c) && (isvarname(strrep(c, '-', '_')) || all(isstrprop(c, 'digit')));
if all(cellfun(token, parts)), choices = parts; end
end
