% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function res = groupCurves(cache, entries, opts)
% GROUPCURVES  Per-group subject curves and intervals, from cached trial averages.
%   res = GROUPCURVES(cache, entries, opts) turns the reduced datasets from
%   loadReducedSets into everything a comparison view needs. It touches no
%   files, so it is cheap enough to re-run on every ROI, mode or window change.
%
%   Inputs:
%     cache   - struct array from loadReducedSets, keyed by .path.
%     entries - struct array with .path .subject .group (see assignGroupByFilter).
%     opts    - .roi        cellstr of ROI electrode labels (required for TEP/LMFP)
%               .mode       'TEP' | 'GMFP' | 'LMFP'   (default 'TEP')
%               .design     'paired' | 'unpaired'     (default 'unpaired')
%               .smoothWin  moving-average samples    (default 5, as the app uses)
%               .level      confidence level          (default 0.95)
%
%   Output res:
%     .time           1xT common time base (ms)
%     .channelLabels  electrodes common to EVERY file in EVERY group
%     .chanlocs       locations for those electrodes, for scalp maps
%     .groups         1xG struct: .name .subjects .curves (nSubj x T)
%                     .chanMeans (C x T, subject-averaged) .nFiles .nSubjects
%     .est            1xG from curveInterval, aligned with .groups
%     .design         the design actually used
%     .complete       subjects present in every group
%     .dropped        subjects excluded from a paired estimate, and why
%     .info           time-base info from commonTimeBase
%
%   Three decisions here are the ones that were previously wrong or absent:
%
%   Subjects, then groups. Files are averaged within a subject first - weighted
%   by trial count, so a 40-trial and a 120-trial session do not count equally -
%   and only then across subjects. The old code averaged files directly and
%   divided by sqrt(nFiles), which on this cohort (8 people, 32 recordings)
%   treats one person's four sessions as four independent observations.
%
%   Electrodes common to every group. The intersection is taken across the
%   whole dataset, not within each group. Restricting it per group would let
%   two conditions be measured over different montages and compared anyway.
%
%   Complete cases for paired designs. A paired interval is only defined on
%   subjects present in every group; the rest are dropped and NAMED in
%   res.dropped so the figure can say "n = 7 of 8 complete pairs" instead of
%   quietly reporting 8.
%
%   See also: loadReducedSets, curveInterval, commonTimeBase, tepFieldCurve

if nargin < 3; opts = struct(); end
opts = withDefaults(opts);

res = struct('time', [], 'channelLabels', {{}}, 'chanlocs', [], ...
             'groups', struct('name', {}, 'subjects', {}, 'curves', {}, ...
                              'chanMeans', {}, 'nFiles', {}, 'nSubjects', {}), ...
             'est', struct([]), 'design', opts.design, 'complete', {{}}, ...
             'dropped', {{}}, 'info', struct());

use = usableEntries(cache, entries);
if isempty(use); return; end

% ── one time base and one montage for the whole dataset ──────────────────
[res.time, timeIdx, res.info] = commonTimeBase({use.time}, {use.label});
[res.channelLabels, chanIdx]  = commonChannels(use);
if isempty(res.channelLabels)
    error('nestapp:noCommonChannels', ...
        'The selected files share no channel labels, so they cannot be compared.');
end
res.chanlocs = use(1).chanlocs(chanIdx{1});

% ── per file: crop to the common montage and time base, then reduce ──────
roiIdx = roiChannelIndex(res.channelLabels, opts.roi);
if isempty(roiIdx) && ~strcmpi(opts.mode, 'GMFP')
    error('nestapp:emptyROI', ...
        ['The ROI matches none of the %d electrodes common to these files. ' ...
         'Pick electrodes that exist in every selected file.'], ...
        numel(res.channelLabels));
end

for i = 1:numel(use)
    avg           = use(i).trialAvg(chanIdx{i}, timeIdx{i});
    use(i).chanAvg = avg;
    % tepFieldCurve takes channels x time x trials; a 2-D trial average is the
    % degenerate case its mean(...,3) leaves untouched, so the one definition of
    % each mode is reused rather than restated here.
    use(i).curve  = smoothCurve(tepFieldCurve(avg, roiIdx, opts.mode), opts.smoothWin);
end

% ── collapse to subjects, then to groups ─────────────────────────────────
groupNames = unique({use.group}, 'stable');
G          = numel(groupNames);
groups     = res.groups;
for g = 1:G
    inG   = strcmp({use.group}, groupNames{g});
    block = use(inG);
    subs  = unique({block.subject}, 'stable');

    curves    = zeros(numel(subs), numel(res.time));
    chanMeans = zeros(numel(res.channelLabels), numel(res.time));
    for s = 1:numel(subs)
        rows            = strcmp({block.subject}, subs{s});
        [curves(s, :), sChan] = collapseSubject(block(rows));
        chanMeans       = chanMeans + sChan;
    end

    groups(g).name      = groupNames{g};
    groups(g).subjects  = subs;
    groups(g).curves    = curves;
    groups(g).chanMeans = chanMeans / max(numel(subs), 1);
    groups(g).nFiles    = numel(block);
    groups(g).nSubjects = numel(subs);
end

% ── intervals ────────────────────────────────────────────────────────────
res.complete = completeSubjects(groups);
if strcmpi(opts.design, 'paired')
    [groups, res.dropped] = restrictToComplete(groups, res.complete);
end
res.groups = groups;
res.est    = curveInterval({groups.curves}, opts.design, opts.level);
end

% ── helpers ─────────────────────────────────────────────────────────────────

function opts = withDefaults(opts)
d = struct('roi', {{}}, 'mode', 'TEP', 'design', 'unpaired', ...
           'smoothWin', 5, 'level', 0.95);
f = fieldnames(d);
for k = 1:numel(f)
    if ~isfield(opts, f{k}) || isempty(opts.(f{k}))
        opts.(f{k}) = d.(f{k});
    end
end
end

function use = usableEntries(cache, entries)
% Join entries to their cached data, keeping only grouped files that loaded.
use = struct('path', {}, 'subject', {}, 'group', {}, 'label', {}, ...
             'trialAvg', {}, 'labels', {}, 'chanlocs', {}, 'time', {}, ...
             'nTrials', {}, 'chanAvg', {}, 'curve', {});
if isempty(entries) || isempty(cache); return; end

paths = {cache.path};
for i = 1:numel(entries)
    if isempty(entries(i).group); continue; end
    k = find(strcmp(paths, entries(i).path), 1);
    if isempty(k) || ~cache(k).ok; continue; end
    [~, nm, ex]      = fileparts(entries(i).path);
    use(end+1) = struct( ...
        'path', entries(i).path, 'subject', char(entries(i).subject), ...
        'group', char(entries(i).group), 'label', [nm ex], ...
        'trialAvg', cache(k).trialAvg, 'labels', {cache(k).labels}, ...
        'chanlocs', cache(k).chanlocs, 'time', cache(k).time, ...
        'nTrials', max(cache(k).nTrials, 1), 'chanAvg', [], 'curve', []); %#ok<AGROW>
end
end

function [labels, idx] = commonChannels(use)
% Labels present in EVERY file, in the first file's order, plus per-file row
% indices onto that common set. Case-insensitive: montages disagree on case
% (Fp1 vs FP1) far more often than they disagree on the electrode.
labels = use(1).labels;
for i = 2:numel(use)
    keep   = ismember(lower(labels), lower(use(i).labels));
    labels = labels(keep);
end
idx = cell(1, numel(use));
for i = 1:numel(use)
    [~, idx{i}] = ismember(lower(labels), lower(use(i).labels));
end
end

function [curve, chanAvg] = collapseSubject(files)
% One subject's recordings, weighted by trial count: a 120-trial session is a
% better estimate of that person than a 40-trial one and should count more.
w       = [files.nTrials];
w       = w(:) / sum(w);
curve   = sum(cell2mat({files.curve}') .* w, 1);
chanAvg = zeros(size(files(1).chanAvg));
for i = 1:numel(files)
    chanAvg = chanAvg + files(i).chanAvg * w(i);
end
end

function subs = completeSubjects(groups)
if isempty(groups); subs = {}; return; end
subs = groups(1).subjects;
for g = 2:numel(groups)
    subs = intersect(subs, groups(g).subjects);
end
end

function [groups, dropped] = restrictToComplete(groups, complete)
% Keep only complete cases, in the SAME subject order in every group - the
% paired interval pairs by row position, so a mismatch here would silently
% compare different people.
dropped = {};
for g = 1:numel(groups)
    [tf, loc] = ismember(complete, groups(g).subjects);
    dropped   = [dropped, setdiff(groups(g).subjects, complete)]; %#ok<AGROW>
    keep      = loc(tf);
    groups(g).subjects  = groups(g).subjects(keep);
    groups(g).curves    = groups(g).curves(keep, :);
    groups(g).nSubjects = numel(keep);
end
dropped = unique(dropped);
end

function y = smoothCurve(x, win)
if isempty(win) || win <= 1; y = x; return; end
y = smoothdata(x, 'movmean', win);
end
