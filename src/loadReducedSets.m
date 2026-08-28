% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [cache, warnings] = loadReducedSets(paths, opts)
% LOADREDUCEDSETS  Load .set files and keep only what any TEP view can need.
%   [cache, warnings] = LOADREDUCEDSETS(paths) loads each file, reduces it to
%   its trial average, and discards the epoched data.
%
%   cache is a 1xN struct array:
%     .path      the file it came from
%     .trialAvg  channels x time, mean over trials
%     .labels    1xC cellstr of channel labels
%     .chanlocs  the chanlocs struct, for topographies
%     .time      1xT time vector (ms)
%     .nTrials   trials that went into the average, for weighting
%     .ok        false when the file could not be loaded
%
%   Why reduce at load time. The Visualizing tab kept every selected dataset
%   whole in EEGofAllSelectedFiles. Real files here are 35 MB of .fdt each, so
%   a 32-file cohort held about 1.1 GB, and a second group would have doubled
%   it. Nothing downstream ever needed the trials: tepFieldCurve's first act is
%   mean(data,3), and every mode it offers - TEP, GMFP, LMFP - is a function of
%   that trial average alone. Scalp maps need the same array. So the trial
%   average is a sufficient statistic for every view in the app, and keeping it
%   instead of the epochs costs about 800 kB per file rather than 35 MB.
%
%   The consequence that matters to the user is not memory but latency: with
%   the trial averages cached, changing the ROI, the plot type, or a window is
%   pure arithmetic on a few MB. That is what makes re-rendering instant, and
%   why picking different electrodes no longer means reloading the cohort or
%   drawing a third curve on top of the old one.
%
%   Options:
%     .loadFcn      @(path)->EEG, default pop_loadset. Overridable for tests.
%     .progressFcn  @(i, n, path) called before each file.
%
%   A file that fails to load is reported in warnings and marked ok=false
%   rather than aborting the batch - one bad recording should not cost the
%   whole comparison.
%
%   See also: groupCurves, tepFieldCurve, drawScalpTopo

if nargin < 2; opts = struct(); end
opts = fillDefaults(opts, struct('loadFcn', @defaultLoad, 'progressFcn', []));

if ischar(paths) || isstring(paths); paths = cellstr(paths); end
n        = numel(paths);
warnings = {};

cache = repmat(struct('path', '', 'trialAvg', [], 'labels', {{}}, ...
                      'chanlocs', [], 'time', [], 'nTrials', 0, 'ok', false), 1, n);

for i = 1:n
    p = char(paths{i});
    cache(i).path = p;
    if ~isempty(opts.progressFcn)
        opts.progressFcn(i, n, p);
    end
    try
        EEG = opts.loadFcn(p);
        [cache(i).trialAvg, cache(i).nTrials] = reduce(EEG);
        cache(i).chanlocs = EEG.chanlocs;
        cache(i).labels   = channelLabels(EEG);
        cache(i).time     = double(EEG.times(:))';
        cache(i).ok       = true;
    catch ME
        warnings{end+1} = sprintf('%s: %s', p, ME.message); %#ok<AGROW>
    end
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function EEG = defaultLoad(p)
[fp, nm, ex] = fileparts(p);
EEG = pop_loadset('filename', [nm ex], 'filepath', fp);
end

function [avg, nTrials] = reduce(EEG)
% The trial average, in double, plus how many trials it represents. EEG.data is
% single on disk; the curve arithmetic downstream is done in double so repeated
% means do not accumulate single-precision error.
data    = double(EEG.data);
nTrials = size(data, 3);
avg     = mean(data, 3, 'omitnan');
end

function labels = channelLabels(EEG)
if isstruct(EEG.chanlocs) && isfield(EEG.chanlocs, 'labels')
    labels = {EEG.chanlocs.labels};
else
    labels = {};
end
end
