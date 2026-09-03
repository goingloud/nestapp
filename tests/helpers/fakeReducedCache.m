% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [cache, entries] = fakeReducedCache(o)
% FAKEREDUCEDCACHE  A loadReducedSets-shaped cohort, plus its entries table.
%   [cache, entries] = FAKEREDUCEDCACHE()
%   [cache, entries] = FAKEREDUCEDCACHE('subjects', 4, 'sessions', 2, ...)
%
%   cache    struct array as loadReducedSets returns: .path .trialAvg .labels
%            .chanlocs .time .nTrials .ok
%   entries  struct array as the files table holds: .path .subject .group
%
%   Options:
%     subjects  4              subjects per group
%     sessions  2              groups, one recording per subject per group
%     repeats   1              extra recordings for subject 1, in group 1 -
%                              this is what makes files out-number subjects
%     labels    5 electrodes   channel labels
%     time      -50:2:300      ms
%     nTrials   [] or vector   trials behind each recording's average; a vector
%                              gives a different weight to each repeat, which
%                              is what the trial-weighting rule needs
%     amp       1              per-subject amplitude scaling
%     badFile   0              index of one recording to mark .ok = false
%     oddLabels 0              index of one recording given a different montage
%
%   loadReducedSets is the ONLY thing between a .set file and this struct, and
%   it is the only part of the chain that needs EEGLAB. Everything downstream -
%   groupCurves, the measures, the drawers - consumes this shape, so a fixture
%   at this seam makes all of it testable with no EEGLAB and no files.
%
%   The last two options exist because the interesting behaviour is in the
%   awkward cases: a file that failed to load must be excluded rather than
%   crash the run, and a file on a different cap must be excluded AND NAMED,
%   which is what res.info.montage.excluded reports.
%
%   See also: fakeGroupResult, loadReducedSets, groupCurves

arguments
    o.subjects  (1,1) double {mustBePositive} = 4
    o.sessions  (1,1) double {mustBePositive} = 2
    o.repeats   (1,1) double {mustBeNonnegative} = 1
    o.labels    cell = {'F3', 'FC1', 'C3', 'CP1', 'Pz'}
    o.time      (1,:) double = -50:2:300
    o.nTrials   double = []
    o.amp       (1,1) double = 1
    o.badFile   (1,1) double {mustBeNonnegative} = 0
    o.oddLabels (1,1) double {mustBeNonnegative} = 0
end

prev = rng(11, 'twister');
restore = onCleanup(@() rng(prev)); %#ok<NASGU>

nCh   = numel(o.labels);
nT    = numel(o.time);
shape = sin(linspace(0, pi, nT));

% Build the recording list first: subjects x sessions, plus the repeats.
recs = struct('subject', {}, 'group', {});
for s = 1:o.sessions
    for i = 1:o.subjects
        recs(end+1) = struct('subject', sprintf('s%d', i), ...
                             'group',   sprintf('g%d', s)); %#ok<AGROW>
    end
end
for r = 1:o.repeats
    recs(end+1) = struct('subject', 's1', 'group', 'g1'); %#ok<AGROW>
end

n = numel(recs);
trials = o.nTrials;
if isempty(trials); trials = repmat(50, 1, n); end
if isscalar(trials); trials = repmat(trials, 1, n); end

cache   = repmat(struct('path', '', 'trialAvg', [], 'labels', {{}}, ...
                        'chanlocs', [], 'time', [], 'nTrials', 0, 'ok', false), 1, n);
entries = repmat(struct('path', '', 'subject', '', 'group', ''), 1, n);

for i = 1:n
    subjIdx = sscanf(recs(i).subject, 's%d');
    p = sprintf('/fake/%s_%s_r%d.set', recs(i).subject, recs(i).group, i);

    labels = o.labels;
    if i == o.oddLabels
        % A different cap. groupCurves must exclude this file and name it,
        % rather than averaging over a montage it does not share.
        labels = [o.labels(1:end-1), {'FT9'}];
    end

    cache(i).path     = p;
    cache(i).labels   = labels;
    cache(i).time     = o.time;
    cache(i).nTrials  = trials(i);
    cache(i).chanlocs = flatChanlocs(labels);
    cache(i).trialAvg = (shape .* (subjIdx * o.amp)) + (1:nCh)' * 0.01;
    cache(i).ok       = (i ~= o.badFile);

    entries(i) = struct('path', p, 'subject', recs(i).subject, ...
                        'group', recs(i).group);
end
end

function locs = flatChanlocs(labels)
% Positions, without EEGLAB. Only the labels matter to anything downstream of
% loadReducedSets; the coordinates are filled in because chanlocs consumers
% vary in which fields they read.
theta  = linspace(-90, 90, numel(labels));
radius = repmat(0.35, 1, numel(labels));
sphPhi = 90 - radius * 180;
locs = struct('labels', labels(:)', ...
              'theta', num2cell(theta), 'radius', num2cell(radius), ...
              'sph_theta', num2cell(theta), 'sph_phi', num2cell(sphPhi), ...
              'X', num2cell(cosd(sphPhi) .* cosd(theta)), ...
              'Y', num2cell(cosd(sphPhi) .* sind(theta)), ...
              'Z', num2cell(sind(sphPhi)));
end
