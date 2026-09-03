% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function res = fakeGroupResult(varargin)
% FAKEGROUPRESULT  A groupCurves-shaped result, for the plot and measure layers.
%   res = FAKEGROUPRESULT()
%   res = FAKEGROUPRESULT('groups', 2, 'subjects', 4, 'design', 'paired', ...)
%
%   Name-value options:
%     groups     2                 number of groups
%     subjects   4                 subjects per group
%     names      {}                group names; default pre, post, sham, other
%     time       -50:2:300         the shared time base, ms
%     gain       1                 multiplier applied to group 2, so the groups
%                                  genuinely differ in amplitude
%     design     'unpaired'        'paired' | 'unpaired'
%     chanlocs   false             true adds a real 17-electrode montage
%     level      0.95              recorded in res.info.level, as groupCurves does
%
%   Returns the full contract: .time .channelLabels .chanlocs .design .groups
%   (.name .subjects .curves .chanMeans .nFiles .nSubjects .files) .est
%   .contrast .complete .dropped .info. Two subjects are given a repeat
%   recording, so .files has more rows than .subjects - which is the case
%   "n is subjects, not files" exists to catch, and the reason .files is here
%   at all.
%
%   WHY THIS EXISTS. The old suite fabricated this same struct FOUR times, three
%   of them under the name twoGroupRes with three different signatures - (),
%   (scaleB) and (midpointGain) - in files that could not see each other, plus a
%   fourth called fakeRes(nGroups, design). The 17-electrode theta/radius/
%   convertlocs montage block was byte-for-byte identical in two of them. Any
%   change to what groupCurves returns meant finding all four.
%
%   The chanlocs option is off by default because building it calls convertlocs,
%   which is EEGLAB - so a pure test must not ask for it, and asking is what
%   moves a test into tests/eeglab. That the flag is explicit rather than
%   automatic is deliberate: it keeps the EEGLAB dependency visible at the call
%   site instead of hidden in a fixture.
%
%   See also: fakeEeg, charFixture, groupCurves, NestappTestCase

o = parse(varargin);

prev = rng(7, 'twister');
restore = onCleanup(@() rng(prev));

nT     = numel(o.time);
labels = {'F3', 'FC1', 'C3', 'CP1', 'Pz'};

res = struct('time', o.time, 'channelLabels', {labels}, 'chanlocs', [], ...
             'design', o.design, 'complete', {{}}, 'dropped', {{}}, ...
             'contrast', struct([]), 'info', struct());

names = o.names;
if isempty(names); names = {'pre', 'post', 'sham', 'other'}; end

g = struct('name', {}, 'subjects', {}, 'curves', {}, 'chanMeans', {}, ...
           'nFiles', {}, 'nSubjects', {}, 'files', {});
shape = sin(linspace(0, pi, nT));

for k = 1:o.groups
    amp    = (1:o.subjects)' * (1 + (k == 2) * (o.gain - 1));
    curves = shape .* amp + k;

    subj = arrayfun(@(i) sprintf('s%d', i), 1:o.subjects, ...
                    'UniformOutput', false);

    % Two subjects recorded twice: .files must out-number .subjects, or the
    % fixture cannot exercise the subject-first collapse at all.
    rows      = [curves; curves(1:min(2, o.subjects), :) * 1.1];
    fileSubj  = [subj, subj(1:min(2, o.subjects))];
    fileNames = arrayfun(@(i) sprintf('%s_r%d', fileSubj{i}, i), ...
                         1:numel(fileSubj), 'UniformOutput', false);

    g(k) = struct('name', names{min(k, numel(names))}, 'subjects', {subj}, ...
                  'curves', curves, 'chanMeans', repmat(mean(curves, 1), ...
                                                        numel(labels), 1), ...
                  'nFiles', numel(fileSubj), 'nSubjects', o.subjects, ...
                  'files', struct('name', fileNames, 'subject', fileSubj, ...
                                  'curve', num2cell(rows, 2)'));
end
res.groups = g;

res.est = curveInterval({g.curves}, o.design, o.level);
if o.groups == 2
    res.contrast = differenceInterval(g(1).curves, g(2).curves, o.design, o.level);
end

res.info.level = o.level;
res.info.roi   = struct('requested', {labels}, 'matched', {labels}, 'missing', {{}});

if o.chanlocs
    res.chanlocs = montage(labels);
end
end

function locs = montage(labels)
% EEGLAB's convertlocs, so a caller asking for this has declared an EEGLAB
% dependency and belongs in tests/eeglab.
theta  = linspace(-90, 90, numel(labels));
radius = repmat(0.35, 1, numel(labels));
locs = struct('labels', labels(:)', 'theta', num2cell(theta), ...
              'radius', num2cell(radius));
locs = convertlocs(locs, 'topo2all');
end

function o = parse(args)
o = struct('groups', 2, 'subjects', 4, 'names', {{}}, 'time', -50:2:300, ...
           'gain', 1, 'design', 'unpaired', 'chanlocs', false, 'level', 0.95);
if mod(numel(args), 2) ~= 0
    error('nestapp:fakeGroupResult:oddArgs', ...
          'Name-value arguments must come in pairs.');
end
for i = 1:2:numel(args)
    key = lower(char(args{i}));
    if ~isfield(o, key)
        error('nestapp:fakeGroupResult:unknownOpt', ...
              'Unknown option "%s".', args{i});
    end
    o.(key) = args{i+1};
end
end
