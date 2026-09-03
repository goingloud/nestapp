% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function est = curveInterval(curvesByGroup, design, level)
% CURVEINTERVAL  Group means with confidence intervals, paired or unpaired.
%   est = CURVEINTERVAL(curvesByGroup, design) takes one subject-by-time matrix
%   per group and returns the mean and a confidence interval per group.
%
%   est is a 1xG struct array with:
%     .mean  1xT group mean
%     .lo    1xT lower bound
%     .hi    1xT upper bound
%     .sem   1xT standard error the interval was built from
%     .n     number of SUBJECTS contributing
%     .df    degrees of freedom used for the t multiplier
%
%   Rows are subjects, never files. Averaging repeat recordings of one person
%   as if they were independent is pseudo-replication: on this cohort (8
%   participants, 32 recordings) it would shrink the interval by roughly a
%   factor of two while looking completely normal. groupCurves does that
%   collapsing before calling here.
%
%   design selects how the interval is built, and the two are genuinely
%   different questions:
%
%     'unpaired'  Groups are different people. Each group gets its own
%                 between-subject SEM: std/sqrt(n), n its own subject count.
%                 Groups may have different n.
%
%     'paired'    Groups are conditions measured in the same people, so rows
%                 must be the SAME subjects in the SAME order in every group -
%                 the caller passes complete cases only. Between-subject
%                 variance is irrelevant here (a subject who is large in every
%                 condition tells you nothing about the difference), so the
%                 interval is built the Cousineau-Morey way: remove each
%                 subject's mean across conditions, add the grand mean back,
%                 then apply Morey's correction sqrt(J/(J-1)) for the J
%                 conditions - without which the normalisation leaves the
%                 interval too narrow. The result is an interval you can read
%                 differences off, which a plain between-subject band is not.
%
%   level is the confidence level, default 0.95. The t multiplier comes from
%   tCritical, so no toolbox is required.
%
%   A group with fewer than two subjects gets NaN bounds rather than a made-up
%   width - with n=1 there is nothing to estimate spread from, and drawing a
%   zero-width band would imply certainty.
%
%   See also: groupCurves, tCritical, datasetSummary, drawTEPOverlay

if nargin < 2 || isempty(design); design = 'unpaired'; end
if nargin < 3 || isempty(level);  level  = 0.95;       end

design = lower(char(design));
alpha  = 1 - level;

if ~iscell(curvesByGroup); curvesByGroup = {curvesByGroup}; end
G = numel(curvesByGroup);

est = struct('mean', {}, 'lo', {}, 'hi', {}, 'sem', {}, 'n', {}, 'df', {});
if G == 0; return; end

switch design
    case 'paired'
        est = pairedIntervals(curvesByGroup, alpha);
    case 'unpaired'
        est = unpairedIntervals(curvesByGroup, alpha);
    otherwise
        error('nestapp:unknownDesign', ...
              'design must be ''paired'' or ''unpaired'', got ''%s''.', design);
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function est = unpairedIntervals(curvesByGroup, alpha)
G   = numel(curvesByGroup);
est = emptyEst(G);
for g = 1:G
    X = curvesByGroup{g};
    est(g) = intervalFrom(mean(X, 1, 'omitnan'), X, size(X, 1), alpha, 1);
end
end

function est = pairedIntervals(curvesByGroup, alpha)
G = numel(curvesByGroup);
n = size(curvesByGroup{1}, 1);
for g = 2:G
    if size(curvesByGroup{g}, 1) ~= n
        error('nestapp:pairedGroupsUnequal', ...
            ['A paired design needs the same subjects in every group, but ' ...
             'group 1 has %d rows and group %d has %d. Pass complete cases ' ...
             'only.'], n, g, size(curvesByGroup{g}, 1));
    end
end

est = emptyEst(G);
if G < 2
    % One condition is not a paired design; fall back rather than divide by
    % zero in Morey's correction.
    est = unpairedIntervals(curvesByGroup, alpha);
    return
end

% Cousineau normalisation: subtract each subject's mean across conditions and
% add the grand mean back, so only within-subject variation is left.
stacked    = cat(3, curvesByGroup{:});          % subjects x time x groups
subjMean   = mean(stacked, 3, 'omitnan');       % subjects x time
grandMean  = mean(subjMean, 1, 'omitnan');      % 1 x time
moreyScale = sqrt(G / (G - 1));                 % Morey (2008) correction

for g = 1:G
    raw  = curvesByGroup{g};
    norm = raw - subjMean + grandMean;
    % The mean is unchanged by the normalisation; report the real one.
    est(g) = intervalFrom(mean(raw, 1, 'omitnan'), norm, n, alpha, moreyScale);
end
end

function e = intervalFrom(mu, X, n, alpha, scale)
% Shared assembly so the paired and unpaired paths cannot drift apart.
df = n - 1;
if n < 2
    e = struct('mean', mu, 'lo', nan(size(mu)), 'hi', nan(size(mu)), ...
               'sem', nan(size(mu)), 'n', n, 'df', max(df, 0));
    return
end
sem = std(X, 0, 1, 'omitnan') / sqrt(n) * scale;
t   = tCritical(df, alpha);
e   = struct('mean', mu, 'lo', mu - t * sem, 'hi', mu + t * sem, ...
             'sem', sem, 'n', n, 'df', df);
end

function est = emptyEst(G)
est = repmat(struct('mean', [], 'lo', [], 'hi', [], 'sem', [], ...
                    'n', 0, 'df', 0), 1, G);
end
