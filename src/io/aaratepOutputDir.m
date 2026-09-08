
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function dirPath = aaratepOutputDir(batchCtx, fullPath)
% AARATEPOUTPUTDIR Where the AARATEP orchestrator writes, for one input file.
%   dirPath = AARATEPOUTPUTDIR(batchCtx, fullPath) places the orchestrator's
%   output under the batch folder the rest of the run already uses, in a
%   per-file 'aaratep' subfolder.
%
%   Per-file matters: upstream MOVES an existing output folder aside to
%   <folder>_old# before writing. One folder shared across a batch would mean
%   each file displaces the results of the file before it, so the run appears
%   to succeed while leaving only the last file's output in place.
%
%   Returns '' when there is no batch context (a direct processOneFile call),
%   which the caller reports as a missing Output folder.

if isempty(batchCtx)
    dirPath = '';
    return;
end

[~, stem] = fileparts(fullPath);
stem = replace(replace(stem, ' ', '_'), '-', '_');

% Deliberately not routed through outputPaths: under the 'typeBased' layout
% its 'data' kind ignores the stem (every .set shares data/, distinguished by
% filename). AARATEP writes a whole FOLDER per file, so it needs separation
% the layouts do not all provide - hence an explicit per-file path here.
dirPath = fullfile(batchCtx.batchRoot, 'aaratep', stem);
end
