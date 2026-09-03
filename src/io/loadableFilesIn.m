
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function files = loadableFilesIn(folder, exts)
% LOADABLEFILESIN  Full paths of loadable data files directly in a folder.
%   files = LOADABLEFILESIN(folder, exts) returns a sorted, de-duplicated
%   cell array (row) of full paths to the files in FOLDER whose names match
%   any glob in EXTS (e.g. {'*.vhdr','*.set'}). Non-recursive.
%
%   Companion files such as BrainVision .eeg/.vmrk are excluded for free by
%   simply not appearing in EXTS - only the header (.vhdr) is loadable, and
%   EEGLAB pulls the companions in from it.

    files = {};
    for i = 1:numel(exts)
        hits = dir(fullfile(folder, exts{i}));
        hits = hits(~[hits.isdir]);
        for j = 1:numel(hits)
            files{end+1} = fullfile(folder, hits(j).name); %#ok<AGROW>
        end
    end

    files = unique(files);          % unique() also sorts; a file can match
    files = reshape(files, 1, []);  % only one ext so this is mostly a no-op
end
