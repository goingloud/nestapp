
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [paths, rel] = scanLoadableFiles(root, exts, progressFcn)
% SCANLOADABLEFILES  Recursively list loadable data files under a root.
%   [paths, rel] = SCANLOADABLEFILES(root, exts) walks ROOT and every
%   subfolder, returning full paths PATHS and their paths RELATIVE to ROOT
%   (forward-slash separated, ROOT itself stripped). Only files matching a
%   glob in EXTS are returned; companion files such as BrainVision
%   .eeg/.vmrk are skipped because they are not in EXTS.
%
%   progressFcn (optional) is invoked once per folder visited as
%       cancelled = progressFcn(nFoundSoFar, currentFolder)
%   and the walk stops early when it returns true. This lets the caller
%   drive a cancelable uiprogressdlg without this function knowing about
%   any UI. Whatever was found before cancelling is still returned.

    if nargin < 3, progressFcn = []; end

    paths = {};
    stack = {root};                 % depth-first worklist of folders to visit
    while ~isempty(stack)
        folder = stack{end};
        stack(end) = [];

        % Queue subfolders for later visits.
        d   = dir(folder);
        sub = d([d.isdir]);
        sub = sub(~ismember({sub.name}, {'.', '..'}));
        for i = 1:numel(sub)
            stack{end+1} = fullfile(folder, sub(i).name); %#ok<AGROW>
        end

        % Collect loadable files in this folder.
        here = loadableFilesIn(folder, exts);
        if ~isempty(here)
            paths = [paths, here]; %#ok<AGROW>
        end

        if ~isempty(progressFcn)
            cancelled = progressFcn(numel(paths), folder);
            if cancelled, break; end
        end
    end

    paths = unique(paths);
    paths = reshape(paths, 1, []);

    % Relative paths for display / filtering: strip the root prefix and
    % normalise separators so a user can filter on "EEG/SPL" style text.
    rel = cell(1, numel(paths));
    prefix = [root filesep];
    for i = 1:numel(paths)
        r = paths{i};
        if startsWith(r, prefix)
            r = r(numel(prefix)+1 : end);
        end
        rel{i} = strrep(r, '\', '/');
    end
end
