
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function entry = buildHistoryEntry(spec, pipelineName)
% BUILDHISTORYENTRY  Build a human-readable provenance string for EEG.history.
%   entry = BUILDHISTORYENTRY(spec, pipelineName)
timestamp = string(datetime('now'), 'yyyy-MM-dd HH:mm:ss');
if isempty(pipelineName)
    pipelineName = '(unsaved)';
end
lines = { ...
    sprintf('%% --- nestapp pipeline  [%s] ---', timestamp), ...
    sprintf('%% Pipeline: %s', pipelineName), ...
    '%  Steps:' ...
};
for si = 1:numel(spec)
    keys   = fieldnames(spec(si).params);
    pairs  = cell(1, numel(keys));
    for ki = 1:numel(keys)
        pairs{ki} = sprintf('%s=%s', keys{ki}, valueToText(spec(si).params.(keys{ki})));
    end
    if isempty(pairs)
        paramStr = '';
    else
        paramStr = ['  [', strjoin(pairs, ', '), ']'];
    end
    lines{end+1} = sprintf('%%  %2d. %s%s', si, spec(si).name, paramStr); %#ok<AGROW>
end
entry = strjoin(lines, newline);
end

function s = valueToText(val)
% Render a param value for the history stamp. char(val) errors on logicals
% ("Conversion to char from logical is not possible") and other non-char
% types, so branch on type and degrade gracefully for anything unexpected.
    if ischar(val)
        s = val;
    elseif isstring(val)
        s = char(strjoin(val, ' '));
    elseif isnumeric(val) || islogical(val)
        s = mat2str(val);                 % logical -> 'true'/'false'
    elseif iscell(val)
        parts = cellfun(@valueToText, val, 'UniformOutput', false);
        s = ['{', strjoin(parts, ', '), '}'];
    else
        s = ['<', class(val), '>'];
    end
end
