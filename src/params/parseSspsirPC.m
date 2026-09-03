
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function pc = parseSspsirPC(raw)
% PARSESSPSIRPC  Coerce the SSP-SIR "Variance kept" (PC) param to a valid shape.
%   pc = PARSESSPSIRPC(raw) returns one of the forms pop_tesa_sspsir accepts:
%     {'data', N}  - remove the PCs explaining N% of the variance (data mode)
%     N            - remove exactly N principal components (fixed count)
%     []           - leave to the (interactive) default
%
%   Why this exists: the PC param is declared type 'string' in the registry,
%   so once {'data', 90} round-trips through the app's UITable or a saved
%   pipeline it comes back as the CHAR "{'data', 90}", not the cell. Passed
%   through as a char it reaches tesa_sspsir, which does "1:PC" internally
%   and throws "For colon operator with char operands, first and last
%   operands must be char." This normalises every reasonable entry form back
%   to a cell / number so the step runs regardless of how it was stored.

% Already the right shape (fresh pipeline: real cell; or a numeric count).
if iscell(raw)
    pc = raw;
    return
end
if isnumeric(raw)
    pc = raw;
    return
end

s = strtrim(char(raw));
if isempty(s) || strcmp(s, '[]')
    pc = [];
    return
end

% "data" form: pull the percentage out of whatever wrapper the user typed -
% "{'data', 90}", "{data,90}", "data, 90", "data 90" all reduce to the same.
if ~isempty(regexpi(s, 'data', 'once'))
    num = regexp(s, '-?\d+\.?\d*', 'match', 'once');
    if ~isempty(num)
        pc = {'data', str2double(num)};
        return
    end
    error('nestapp:sspsirPC', ...
        ['SSP-SIR "Variance kept" value "%s" names the data mode but has ' ...
         'no percentage. Use e.g. {''data'', 90}.'], s);
end

% Bare number -> fixed PC count.
n = str2double(s);
if ~isnan(n)
    pc = n;
    return
end

error('nestapp:sspsirPC', ...
    ['Could not interpret SSP-SIR "Variance kept" value "%s". Use ' ...
     '{''data'', 90} to keep 90%% of variance, or a plain number like 5 ' ...
     'for a fixed principal-component count.'], s);
end
