% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function res = fakeGroupResult(o)
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
%   The chanlocs montage is built with plain trigonometry, NOT with EEGLAB's
%   convertlocs. An earlier version called convertlocs, which quietly defeated
%   the rule the whole folder split rests on: a test in tests/pure calling
%   fakeGroupResult('chanlocs', true) contains no EEGLAB token of its own, so
%   SuiteHygieneTest's folder check - which scans the TEST file - would pass it
%   while it called an EEGLAB function one level down. Tracking that dependency
%   would have meant teaching the scanner which helpers are contaminated;
%   removing it means there is nothing to track. The five lines of spherical-
%   to-cartesian below are the whole of what convertlocs was providing.
%
%   See also: fakeEeg, charFixture, groupCurves, NestappTestCase

arguments
    o.groups   (1,1) double {mustBePositive} = 2
    o.subjects (1,1) double {mustBePositive} = 4
    o.names    cell = {}
    o.time     (1,:) double = -50:2:300
    o.gain     (1,1) double = 1
    o.design   char {mustBeMember(o.design, {'paired', 'unpaired'})} = 'unpaired'
    o.chanlocs (1,1) logical = false
    o.level    (1,1) double = 0.95
end

prev = rng(7, 'twister');
restore = onCleanup(@() rng(prev));

nT     = numel(o.time);
labels = {'F3', 'FC1', 'C3', 'CP1', 'Pz'};

res = struct('time', o.time, 'channelLabels', {labels}, 'chanlocs', [], ...
             'design', o.design, 'complete', {{}}, 'dropped', {{}}, ...
             'contrast', struct([]), 'info', struct());

names = o.names;
if isempty(names); names = {'pre', 'post', 'sham', 'other'}; end
if o.groups > numel(names)
    % Better to say so than to hand back two groups sharing a name, which
    % would make a comparison between them meaningless in a way no assertion
    % would catch.
    error('nestapp:fakeGroupResult:tooFewNames', ...
          'Asked for %d groups but only %d names are available; pass ''names''.', ...
          o.groups, numel(names));
end

% Loop-invariant: the subject list and the repeat count are the same for every
% group, so they are built once.
subj    = arrayfun(@(i) sprintf('s%d', i), 1:o.subjects, 'UniformOutput', false);
nRepeat = min(2, o.subjects);

g = struct('name', {}, 'subjects', {}, 'curves', {}, 'chanMeans', {}, ...
           'nFiles', {}, 'nSubjects', {}, 'files', {});
shape = sin(linspace(0, pi, nT));

for k = 1:o.groups
    amp    = (1:o.subjects)' * (1 + (k == 2) * (o.gain - 1));
    curves = shape .* amp + k;

    % Two subjects recorded twice: .files must out-number .subjects, or the
    % fixture cannot exercise the subject-first collapse at all.
    rows      = [curves; curves(1:nRepeat, :) * 1.1];
    fileSubj  = [subj, subj(1:nRepeat)];
    fileNames = arrayfun(@(i) sprintf('%s_r%d', fileSubj{i}, i), ...
                         1:numel(fileSubj), 'UniformOutput', false);

    g(k) = struct('name', names{k}, 'subjects', {subj}, ...
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
% Spherical polar to cartesian, EEGLAB's convention, done here so the fixture
% needs no EEGLAB. topoplot accepts theta/radius directly; X/Y/Z are filled in
% because chanlocs consumers vary in which they read.
theta  = linspace(-90, 90, numel(labels));
radius = repmat(0.35, 1, numel(labels));
sphPhi = 90 - radius * 180;

locs = struct('labels', labels(:)', ...
              'theta',  num2cell(theta), 'radius', num2cell(radius), ...
              'sph_theta', num2cell(theta), 'sph_phi', num2cell(sphPhi), ...
              'sph_radius', num2cell(ones(1, numel(labels))), ...
              'X', num2cell(cosd(sphPhi) .* cosd(theta)), ...
              'Y', num2cell(cosd(sphPhi) .* sind(theta)), ...
              'Z', num2cell(sind(sphPhi)));
end

