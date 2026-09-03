
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function writeFailedFilesList(txtPath, failed)
% WRITEFAILEDFILESLIST  Write a copy-paste re-run list for failed files.
%   WRITEFAILEDFILESLIST(txtPath, failed) writes the absolute input path of
%   every file that did not complete, one per line, so a large batch can be
%   re-run without hunting through the log. Each path is preceded by a '#'
%   comment line naming the file, the step it died at, and the one-line
%   reason - so the list is self-explanatory, and a loader can keep just the
%   non-'#' lines to get a clean path list.
%
%   failed - struct array from runPipelineCore with fields name, stepName,
%            message, kind and (resolved before writing) path.

fid = fopen(txtPath, 'wt');
if fid < 0
    error('nestapp:writeFailedFilesList', 'Could not open %s for writing.', txtPath);
end
closeFid = onCleanup(@() fclose(fid));

fprintf(fid, '# %d file(s) did not complete - re-run the paths below.\n', numel(failed));
fprintf(fid, '# Lines starting with "#" are comments; the rest are input paths.\n');

for k = 1:numel(failed)
    f = failed(k);

    if isfield(f, 'path') && ~isempty(f.path)
        p = f.path;
    else
        p = f.name;              % fall back to basename if path wasn't resolved
    end

    stepInfo = '';
    if isfield(f, 'stepName') && ~isempty(f.stepName)
        stepInfo = sprintf(' [%s]', f.stepName);
    end
    reason = '';
    if isfield(f, 'message') && ~isempty(f.message)
        reason = regexprep(f.message, '\s*[\r\n]+\s*', ' ');
    end

    fprintf(fid, '# %s%s: %s\n', f.name, stepInfo, reason);
    fprintf(fid, '%s\n', p);
end
end
