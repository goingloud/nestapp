% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function labels = channelLabelChoices(filePaths)
% CHANNELLABELCHOICES  Channel labels to offer in a channel chooser.
%   labels = CHANNELLABELCHOICES(filePaths) reads the labels of the first data
%   file it can (EEGLAB .set, BrainVision .vhdr header), and otherwise returns
%   EEGLAB's standard 10-05 labels, then nestapp's own electrodeList.
%
%   Only headers are read - never the data - so it is cheap enough to call
%   when a chooser opens.
%
%   See also: pickChannels, settingsForm

labels = {}; %#ok<NASGU> overwritten in the loop or by the fallback
for k = 1:min(numel(filePaths), 3)
    try
        labels = labelsOf(filePaths{k});
    catch
        labels = {};
    end
    if ~isempty(labels), return; end
end
labels = standardLabels();
end

function labels = labelsOf(path)
labels = {};
[~, ~, ext] = fileparts(path);
switch lower(ext)
    case '.set'
        % Newer .set files hold each EEG field as its own variable, so the
        % labels load alone; an older single-struct file is read only if small.
        vars = who('-file', path);
        if any(strcmp(vars, 'chanlocs'))
            s = load(path, '-mat', 'chanlocs');
        elseif any(strcmp(vars, 'EEG')) && dir(path).bytes < 50e6
            s = load(path, '-mat', 'EEG');
            s = s.EEG;
        else
            return
        end
        if isfield(s, 'chanlocs') && ~isempty(s.chanlocs)
            labels = {s.chanlocs.labels};
        end
    case '.vhdr'
        txt = fileread(path);
        tok = regexp(txt, '(?m)^Ch\d+=([^,\r\n]+)', 'tokens');
        labels = cellfun(@(t) strtrim(t{1}), tok, 'UniformOutput', false);
end
end

function labels = standardLabels()
labels = {};
root = fileparts(which('eeglab'));
f = fullfile(root, 'plugins', 'dipfit', 'standard_BEM', 'elec', 'standard_1005.elc');
if ~isempty(root) && isfile(f)
    txt = fileread(f);
    i = strfind(txt, 'Labels');
    if ~isempty(i)
        labels = regexp(strtrim(txt(i(1)+6:end)), '\s+', 'split');
    end
end
if isempty(labels)
    labels = electrodeList();   % the montage list nestapp already knows
end
end
