
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [report, info] = aaratepHarvest(report, outputDir, prefix, opts)
% AARATEPHARVEST  Fold one AARATEP run's own outputs back into nestapp.
%   [report, info] = AARATEPHARVEST(report, outputDir, prefix, opts)
%
%   The orchestrator returns only the cleaned EEG, but it also writes a
%   provenance struct, QC images and several intermediate datasets into
%   outputDir. Left alone, none of that reaches nestapp: the report shows no
%   ICA and no rejected channels (AARATEP interpolates them back, so the
%   channel count never moves), the methods paragraph silently omits ICA
%   because it is gated on report.ica.nComponents > 0, the QC images never
%   appear in the Reports tab or the PDF, and the intermediates sit on disk at
%   roughly 3x the size of the result.
%
%   report    - the in-progress PipelineReport, returned updated.
%   outputDir - the folder the orchestrator wrote to (aaratepOutputDir).
%   prefix    - its outputFilePrefix, which names every file it wrote.
%   opts      - optional struct:
%     .keepIntermediates  keep the _pre*.mat datasets (default true)
%     .dropFinalMat       delete the final <prefix>.mat, for when a Save New
%                         Set step is writing the same dataset as a .set
%                         (default false - never drop the only copy)
%     .channelLabels      cellstr of the returned EEG's channel labels, used
%                         to resolve upstream's channel INDICES to names
%
%   info - what happened, for logging: .mdFound, .figures, .removed, .bytesFreed
%
%   See also: aaratepOutputDir, processOneFile, initPipelineReport

if nargin < 4 || ~isstruct(opts), opts = struct(); end
if ~isfield(opts, 'keepIntermediates'), opts.keepIntermediates = true;  end
if ~isfield(opts, 'dropFinalMat'),      opts.dropFinalMat      = false; end
if ~isfield(opts, 'channelLabels'),     opts.channelLabels     = {};    end

info = struct('mdFound', false, 'figures', {{}}, 'removed', {{}}, 'bytesFreed', 0);
if isempty(outputDir) || ~isfolder(outputDir)
    return
end
if isempty(prefix); prefix = 'PreprocessedResults'; end

finalMat = fullfile(outputDir, [prefix '.mat']);

% -- provenance ---------------------------------------------------------------
md = readMetadata(finalMat);
if ~isempty(md)
    info.mdFound = true;
    report = applyMetadata(report, md, opts.channelLabels);
end

% -- QC images ----------------------------------------------------------------
info.figures = listImages(outputDir, prefix);
if ~isempty(info.figures)
    if ~isfield(report, 'quality') || ~isfield(report.quality, 'figures')
        report.quality = struct('figures', {{}});
    end
    report.quality.figures = [report.quality.figures, info.figures];
end

% -- tidy ---------------------------------------------------------------------
doomed = {};
if ~opts.keepIntermediates
    % The three upstream saves guarded by `if true`, not by doDebug - so they
    % are written on every run whether or not anyone wants them.
    suffixes = {'_preSOUND', '_preDecayRemoval', '_preICARejection'};
    doomed = cellfun(@(sfx) fullfile(outputDir, [prefix sfx '.mat']), ...
                     suffixes, 'UniformOutput', false);
end
% Only ever drop the final .mat once its metadata is safely in the report and
% the caller has confirmed the same dataset is being written as a .set.
if opts.dropFinalMat && info.mdFound
    doomed{end+1} = finalMat;
end

for k = 1:numel(doomed)
    d = dir(doomed{k});
    if isempty(d); continue; end
    try
        delete(doomed{k});
        info.removed{end+1}  = doomed{k};
        info.bytesFreed      = info.bytesFreed + d(1).bytes;
    catch
        % Non-fatal: a locked file costs disk, not results.
    end
end
end

% ── local helpers ─────────────────────────────────────────────────────────────

function md = readMetadata(finalMat)
% AARATEP saves 'EEG' and 'md' together; load only md so a multi-hundred-MB
% dataset is not pulled into memory just to read a few counters.
md = [];
if exist(finalMat, 'file') ~= 2; return; end
try
    % Check the header before loading: load(...,'md') warns when the variable
    % is absent, and whos reads only the file's table of contents.
    contents = whos('-file', finalMat);
    if ~ismember('md', {contents.name}); return; end
    S = load(finalMat, 'md');
    if isfield(S, 'md') && isstruct(S.md); md = S.md; end
catch
    % A truncated or unreadable .mat costs provenance, not the run.
end
end

function report = applyMetadata(report, md, labels)
% Map upstream's counters onto the report fields the rest of nestapp reads.
% Both ICA passes count: the early eye pass and the main one.
nComp = numField(md, 'ICA_numComp')    + numField(md, 'eyeICA_numComp');
nRej  = numField(md, 'ICA_numRejComp') + numField(md, 'eyeICA_numRejComp');
if nComp > 0
    report.ica.nComponents = nComp;
    report.ica.nRejected   = nRej;
    report.ica.nKept       = nComp - nRej;
end

% Channels AARATEP judged bad. It interpolates them back, so the channel
% COUNT is unchanged - record the names and the interpolation, not a rejection,
% or the report would claim data was dropped that is still there.
if isfield(md, 'earlyRejectedChannels') && ~isempty(md.earlyRejectedChannels)
    names = channelNames(labels, md.earlyRejectedChannels);
    if ~isempty(names)
        report.channels.badChannelNames = unique([ ...
            asCellstr(getfielddef(report.channels, 'badChannelNames', {})), names], 'stable');
        report.channels.interpolatedNames = unique([ ...
            asCellstr(getfielddef(report.channels, 'interpolatedNames', {})), names], 'stable');
        report.channels.nInterpolated = numel(report.channels.interpolatedNames);
    end
end

if isfield(md, 'pipelineVersion') && ~isempty(md.pipelineVersion)
    report.aaratepVersion = char(string(md.pipelineVersion));
end
end

function names = channelNames(labels, idx)
% earlyRejectedChannels is a list of indices into the montage. AARATEP
% interpolates those channels back, so the returned EEG still carries them and
% its labels index correctly. Fall back to "#n" so the information survives
% even when no labels were supplied.
labels = asCellstr(labels);
idx    = idx(:)';
if ~isempty(labels) && all(idx >= 1 & idx <= numel(labels))
    names = labels(idx);
else
    names = arrayfun(@(i) sprintf('#%d', i), idx, 'UniformOutput', false);
end
end

function files = listImages(outputDir, prefix)
% Everything the orchestrator plots: QC panels, the final timtopo, and the
% debug figures when doDebug was on.
files = {};
for pat = {'_QC_*.png', '_Plot_*.png', '_Debug_*.png'}
    d = dir(fullfile(outputDir, [prefix pat{1}]));
    for k = 1:numel(d)
        if d(k).isdir; continue; end
        files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
    end
end
files = sort(files);
end

function v = numField(s, name)
v = 0;
if isfield(s, name) && isnumeric(s.(name)) && isscalar(s.(name)) && isfinite(s.(name))
    v = double(s.(name));
end
end

function v = getfielddef(s, name, default)
if isstruct(s) && isfield(s, name); v = s.(name); else, v = default; end
end

function c = asCellstr(v)
if isempty(v); c = {}; elseif ischar(v); c = {v}; else, c = cellstr(v(:)'); end
end
