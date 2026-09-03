
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function matFiles = findReportMatFiles(folder)
% FINDREPORTMATFILES  Pipeline report .mat files under a folder.
%   matFiles = FINDREPORTMATFILES(folder) returns a dir() struct array of the
%   report .mat files for `folder`, which may be a reports folder, a batch
%   root, or a parent holding several batch runs.
%
%   Matches BOTH names reportArtifactName emits: "<base>_report.mat"
%   (overwriteReports on) and "<base>_report_<timestamp>.mat" (off).
%
%   Reports sit in a known place, so the two cheap single-folder listings are
%   tried first - the folder itself, then its reports/ subfolder (the
%   typeBased layout) - and the whole-tree walk only runs if neither hits.
%   That last case still lets a parent of several batch runs work, but it is
%   what makes loading slow over a network share: a batch root also holds
%   data/ and qc/, so recursing it stats hundreds of large files to find the
%   few that are reports.
%
%   See also: reportArtifactName, exportReport, outputPaths

PATTERN = '*_report*.mat';

matFiles = listMats(fullfile(folder, PATTERN));
if ~isempty(matFiles); return; end

matFiles = listMats(fullfile(folder, 'reports', PATTERN));
if ~isempty(matFiles); return; end

matFiles = listMats(fullfile(folder, '**', PATTERN));
end

% ── local helpers ─────────────────────────────────────────────────────────────

function matFiles = listMats(pattern)
matFiles = dir(pattern);
if ~isempty(matFiles)
    matFiles = matFiles(~[matFiles.isdir]);
end
end
