
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [results, warnings] = batchWindowExtract(filePaths, roiElectrodes, mode, windows, varargin)
% BATCHWINDOWEXTRACT  Per-file window-of-interest measures for many .set files.
%   [results, warnings] = BATCHWINDOWEXTRACT(filePaths, roiElectrodes, mode,
%   windows, ...) loads each file, reduces it to a single curve for the active
%   mode (TEP = ROI mean, GMFP = SD across all channels, LMFP = SD across the
%   ROI; see tepFieldCurve), 5-point smooths it, then measures each window's
%   mean (and peak latency/amplitude for TEP). Returns a table with one row per
%   (file, window) - the same schema the Analysis-tab workspace export uses
%   (tepWindowTable) - and a cellstr of per-file warnings.
%
%   Name-value options:
%     'smoothWin'   moving-average window in samples (default 5)
%     'csvPath'     if non-empty, writetable the results there
%     'progressFcn' @(iFile, nFiles) called before each file
%     'loadFcn'     @(path)->EEG override for tests (default pop_loadset)
%
%   See also: batchTEPExtract, tepFieldCurve, tepWindowTable, computeWindowMeasures

    p = inputParser;
    p.addRequired('filePaths',     @(x) iscell(x) && ~isempty(x));
    p.addRequired('roiElectrodes', @(x) iscell(x));
    p.addRequired('mode',          @(x) ischar(x) || isstring(x));
    p.addRequired('windows',       @(x) isstruct(x) && ~isempty(x));
    p.addParameter('smoothWin',   5,  @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('csvPath',     '', @ischar);
    p.addParameter('progressFcn', [], @(x) isempty(x) || isa(x,'function_handle'));
    p.addParameter('loadFcn',     [], @(x) isempty(x) || isa(x,'function_handle'));
    p.parse(filePaths, roiElectrodes, mode, windows, varargin{:});
    opts = p.Results;

    mode    = char(opts.mode);
    needsROI = ~strcmpi(mode, 'GMFP');   % GMFP spans all channels - ROI optional
    nFiles  = numel(opts.filePaths);
    parts   = cell(1, nFiles);
    warnings = {};

    for fi = 1:nFiles
        if ~isempty(opts.progressFcn)
            opts.progressFcn(fi, nFiles);
        end

        fp = opts.filePaths{fi};
        [fdir, fname, fext] = fileparts(fp); %#ok<ASGLU> used inside evalc string

        % -- load --
        try
            if ~isempty(opts.loadFcn)
                EEG = opts.loadFcn(fp);
            else
                evalc("EEG = pop_loadset('filename', [fname fext], 'filepath', fdir)");
            end
        catch ME
            warnings{end+1} = sprintf('%s: load failed - %s', fname, ME.message); %#ok<AGROW>
            parts{fi} = tepWindowTable({fname}, NaN, [], opts.windows, mode);
            continue
        end

        % -- guard: epoched --
        if ~isstruct(EEG) || ~isfield(EEG,'trials') || EEG.trials < 2
            nTrials = 0;
            if isstruct(EEG) && isfield(EEG, 'trials'), nTrials = EEG.trials; end
            warnings{end+1} = sprintf('%s: skipped - not epoched (trials=%d)', fname, nTrials); %#ok<AGROW>
            parts{fi} = tepWindowTable({fname}, NaN, [], opts.windows, mode);
            continue
        end

        % -- resolve ROI (case-insensitive; needed only for TEP/LMFP) --
        allLabels = {EEG.chanlocs.labels};
        roiIdx    = roiChannelIndex(allLabels, opts.roiElectrodes);
        if needsROI && isempty(roiIdx)
            warnings{end+1} = sprintf('%s: skipped - none of the requested ROI electrodes found', fname); %#ok<AGROW>
            parts{fi} = tepWindowTable({fname}, NaN, [], opts.windows, mode);
            continue
        end
        if needsROI && numel(roiIdx) < numel(opts.roiElectrodes)
            warnings{end+1} = sprintf('%s: partial ROI - %d of %d requested electrodes found', ...
                fname, numel(roiIdx), numel(opts.roiElectrodes)); %#ok<AGROW>
        end

        % -- curve for the active mode, smoothed like the on-screen plot --
        curve = tepFieldCurve(EEG.data, roiIdx, mode);
        curve = smoothdata(curve, 'movmean', opts.smoothWin);
        parts{fi} = tepWindowTable({fname}, curve, EEG.times, opts.windows, mode);
    end

    results = vertcat(parts{:});

    if ~isempty(opts.csvPath)
        writetable(results, opts.csvPath);
    end
end
