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
%                     .files - 1xnFiles struct (.name .subject .curve), the
%                     individual recordings BEFORE the subject collapse
%     .est            1xG from curveInterval, aligned with .groups
%     .contrast       differenceInterval for groups(2) minus groups(1) when
%                     there are exactly two groups; struct([]) otherwise
%     .design         the design actually used
%     .complete       subjects present in every group
%     .dropped        subjects excluded from a paired estimate, and why
%     .info           time-base info from commonTimeBase, plus .roi
%                     (.requested .matched .missing - a partial ROI is
%                     averaged, not refused, so the difference is recorded)
%                     and .montage:
%                       .uniform    true when every file has the same channels
%                       .nChannels  size of the modal montage
%                       .excluded   files not on it, by name
%                       .variants   each distinct montage with its files and
%                                   what it lacks relative to the modal one
%
%   Three decisions here are the ones that were previously wrong or absent:
%
%   Subjects, then groups. Files are averaged within a subject first - weighted
%   by trial count, so a 40-trial and a 120-trial session do not count equally -
%   and only then across subjects. The old code averaged files directly and
%   divided by sqrt(nFiles), which on this cohort (8 people, 32 recordings)
%   treats one person's four sessions as four independent observations.
%
%   One montage for the whole dataset - the modal one. Files recorded on a
%   different cap are excluded and named in res.info.montage.excluded rather
%   than quietly shrinking everyone else's channel set; see modalMontage.
%
%   Complete cases for paired designs. A paired interval is only defined on
%   subjects present in every group; the rest are dropped and NAMED in
%   res.dropped so the figure can say "n = 7 of 8 complete pairs" instead of
%   quietly reporting 8.
%
%   See also: loadReducedSets, curveInterval, commonTimeBase, tepFieldCurve

if nargin < 3; opts = struct(); end
opts = fillDefaults(opts, struct('roi', {{}}, 'mode', 'TEP', ...
    'design', 'unpaired', 'smoothWin', 5, 'level', 0.95));

res = struct('time', [], 'channelLabels', {{}}, 'chanlocs', [], ...
             'groups', struct('name', {}, 'subjects', {}, 'curves', {}, ...
                              'chanMeans', {}, 'nFiles', {}, 'nSubjects', {}, ...
                              'files', {}), ...
             'est', struct([]), 'contrast', struct([]), ...
             'design', opts.design, 'complete', {{}}, ...
             'dropped', {{}}, 'info', struct());

use = usableEntries(cache, entries);
if isempty(use); return; end

% ── one montage, then one time base for the files that carry it ──────────
% Montage first: files on a different cap are excluded outright, so they must
% not get a say in the time base either.
[res.channelLabels, conforms, chanIdx, montage] = modalMontage(cache, use);
use     = use(conforms);
chanIdx = chanIdx(conforms);
if isempty(res.channelLabels)
    error('nestapp:noCommonChannels', ...
        'The selected files have no channel labels, so they cannot be compared.');
end

[res.time, timeIdx, res.info] = commonTimeBase({cache([use.ci]).time}, {use.label});
res.info.montage = montage;
res.chanlocs = cache(use(1).ci).chanlocs(chanIdx{1});

% ── per file: crop to the common montage and time base, then reduce ──────
roiIdx = roiChannelIndex(res.channelLabels, opts.roi);
if isempty(roiIdx) && ~strcmpi(opts.mode, 'GMFP')
    error('nestapp:emptyROI', ...
        ['The ROI matches none of the %d electrodes common to these files. ' ...
         'Pick electrodes that exist in every selected file.'], ...
        numel(res.channelLabels));
end

% What was ASKED FOR versus what was AVERAGED. Only a total miss errored
% above; a partial match - three of five electrodes present - was averaged
% silently while the status line and the exported figure's footer went on
% naming all five. A caption that overstates the ROI is the one place this
% does real damage, so the difference is recorded and the footer stamps
% .matched rather than the request.
res.info.roi = struct( ...
    'requested', {opts.roi(:)'}, ...
    'matched',   {res.channelLabels(roiIdx)}, ...
    'missing',   {opts.roi(~ismember(lower(opts.roi), lower(res.channelLabels)))});

for i = 1:numel(use)
    avg            = cache(use(i).ci).trialAvg(chanIdx{i}, timeIdx{i});
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

    % The per-FILE records, kept rather than discarded. They were already
    % computed above and thrown away with `use`, so retaining them costs one
    % projection and nothing in the reduction. They answer "is that one
    % recording an outlier" - a question a group mean cannot be asked, and
    % which previously needed the old Add-to-current-Figure gesture.
    %
    % A struct array, not parallel arrays: it is the shape `cache`, `entries`
    % and `block` itself already use, and it is what keeps the paired-design
    % filter below a single indexing operation however many per-file fields
    % this grows. .name carries the identity a curve alone does not have, so a
    % saved result can say WHICH recording an outlying row was.
    groups(g).files = struct('name',    {block.label}, ...
                             'subject', {block.subject}, ...
                             'curve',   {block.curve});
end

% ── intervals ────────────────────────────────────────────────────────────
res.complete = completeSubjects(groups);
if strcmpi(opts.design, 'paired')
    [groups, res.dropped] = restrictToComplete(groups, res.complete);
end
res.groups = groups;
res.est    = curveInterval({groups.curves}, opts.design, opts.level);

% The contrast is an estimate, so it belongs here with the others rather than
% at draw time. drawDifferenceWave was deriving it with no level argument,
% which drew a 95% difference band beside 99% group bands whenever the run's
% level was changed.
if numel(groups) == 2
    res.contrast = differenceInterval(groups(1).curves, groups(2).curves, ...
                                      opts.design, opts.level);
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function use = usableEntries(cache, entries)
% Join entries to their cached data, keeping only grouped files that loaded.
%
% Holds a cache INDEX, not the cached arrays. Copy-on-write means the previous
% version never actually memcopied the 63x2000 trial averages - they were
% shared - so the win is not avoided duplication but avoided REALLOCATION:
% growing a struct array whose elements each carried those fields, once per
% file, then filtering it again by montage. Measured 0.20 -> 0.09 ms at 12
% files and 2.9 -> 1.4 ms at 200, on a path that re-runs on every ROI change.
use = struct('ci', {}, 'subject', {}, 'group', {}, 'label', {}, ...
             'nTrials', {}, 'chanAvg', {}, 'curve', {});
if isempty(entries) || isempty(cache); return; end

paths = {cache.path};
ci    = zeros(1, numel(entries));
for i = 1:numel(entries)
    if isempty(entries(i).group); continue; end
    k = find(strcmp(paths, entries(i).path), 1);
    if isempty(k) || ~cache(k).ok; continue; end
    ci(i) = k;
end

idxE = find(ci > 0);
if isempty(idxE); return; end
use = repmat(struct('ci', 0, 'subject', '', 'group', '', 'label', '', ...
                    'nTrials', 1, 'chanAvg', [], 'curve', []), 1, numel(idxE));
for j = 1:numel(idxE)
    i = idxE(j);
    [~, nm, ex]    = fileparts(entries(i).path);
    use(j).ci      = ci(i);
    use(j).subject = char(entries(i).subject);
    use(j).group   = char(entries(i).group);
    use(j).label   = [nm ex];
    use(j).nTrials = max(cache(ci(i)).nTrials, 1);
end
end

function [labels, conforms, idx, montage] = modalMontage(cache, use)
% The montage carried by the most files, and which files carry it.
%
% Not an intersection across every file. On this cohort 32 files carry
% AFz/FCz/FT9/FT10 and three (rtmsct006, rtmsct016, rtmsct021) carry
% CPz/FPz/Iz instead - two cap configurations, not bad channels awaiting
% interpolation, which the pipeline does correctly. Intersecting would take the
% 59 labels common to both and make 32 files pay for three, and it would move
% GMFP without saying so, since GMFP is a standard deviation ACROSS CHANNELS
% and 59 of them is not 63 of them.
%
% So the majority montage wins and the odd files out are excluded and NAMED.
% That keeps the common case exact, keeps GMFP comparable, and turns a silent
% degradation into a list of files to go and look at.
%
% Ties (two montages with equally many files) go to the one seen first, which
% is stable for a given file order and reported either way.
labelSets = {cache([use.ci]).labels};
sigs = cellfun(@(L) strjoin(sort(lower(L)), ','), labelSets, 'UniformOutput', false);
[uniqSigs, ~, which] = unique(sigs, 'stable');

counts = accumarray(which(:), 1);
[~, winner] = max(counts);          % max takes the first on a tie
conforms = (which(:)' == winner);
labels   = labelSets{find(conforms, 1)};

idx = cell(1, numel(use));
for i = find(conforms)
    [~, idx{i}] = ismember(lower(labels), lower(labelSets{i}));
end

montage = struct();
montage.uniform   = isscalar(uniqSigs);
montage.nChannels = numel(labels);
montage.excluded  = {use(~conforms).label};
montage.variants = struct('nChannels', {}, 'nFiles', {}, 'files', {}, 'missing', {});
for v = 1:numel(uniqSigs)
    inV = (which(:)' == v);
    vLabels = labelSets{find(inV, 1)};
    montage.variants(v).nChannels = numel(vLabels);
    montage.variants(v).nFiles    = sum(inV);
    montage.variants(v).files     = {use(inV).label};
    % What this variant lacks relative to the modal one - the actionable bit.
    montage.variants(v).missing   = labels(~ismember(lower(labels), lower(vLabels)));
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

    % The per-file records have to follow, or a traces overlay would draw
    % recordings belonging to subjects this estimate just excluded - the
    % picture would disagree with the interval drawn on top of it. One
    % indexing operation, so a future per-file field cannot fall out of step.
    keepFile        = ismember({groups(g).files.subject}, groups(g).subjects);
    groups(g).files = groups(g).files(keepFile);
    groups(g).nFiles = numel(groups(g).files);
end
dropped = unique(dropped);
end

function y = smoothCurve(x, win)
if isempty(win) || win <= 1; y = x; return; end
y = smoothdata(x, 'movmean', win);
end
