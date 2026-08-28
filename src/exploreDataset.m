% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [entries, summary] = exploreDataset(paths, rules, opts)
% EXPLOREDATASET  Turn a list of files into a grouped, subject-tagged dataset.
%   [entries, summary] = EXPLOREDATASET(paths, rules) assigns a subject and a
%   group to every file and reports what the result contains.
%
%   rules defines the groups, in order, as a struct array or an Nx2 cell:
%
%       rules = {'_pre_',  'pre'
%                '_post_', 'post'};
%
%   Each rule is the filter expression that FINDS the condition's files and the
%   name of the group they belong to - the same expression typed into
%   selectDataTree's filter, matched identically. Later rules do not steal files
%   from earlier ones: the first rule that matches a file wins, so overlapping
%   patterns degrade to "first match" rather than silently reassigning.
%
%   opts:
%     .root      make paths relative to this before matching, so a pattern
%                cannot match the directories above the data (a cohort under
%                C:\preprocessed must not make every file match 'pre')
%     .subjects  cellstr overriding the inferred subject ids, one per path
%
%   entries is the struct array the rest of the Explore layer takes:
%   .path .subject .group, plus .subjectConfident so a caller can show which
%   subject ids were guessed rather than given.
%
%   This is the headless entry point for building a comparison. The GUI will
%   call exactly this, which is the point: a script can reproduce any figure
%   the app draws without the app, and a saved session is consumable by the
%   same functions.
%
%   See also: inferSubjectIds, assignGroupByFilter, datasetSummary, groupCurves

if nargin < 2; rules = {}; end
if nargin < 3; opts = struct(); end
opts = fillDefaults(opts, struct('root', '', 'subjects', {{}}));

if ischar(paths) || isstring(paths); paths = cellstr(paths); end
paths = paths(:)';

[ids, confident] = inferSubjectIds(paths);
if ~isempty(opts.subjects)
    if numel(opts.subjects) ~= numel(paths)
        error('nestapp:subjectCountMismatch', ...
            'Given %d subject ids for %d files.', numel(opts.subjects), numel(paths));
    end
    ids       = cellstr(opts.subjects);
    confident = true(1, numel(ids));
end

entries = struct('path', paths, 'subject', ids, ...
                 'group', repmat({''}, 1, numel(paths)), ...
                 'subjectConfident', num2cell(confident));

rules = normaliseRules(rules);
for r = 1:numel(rules)
    % Only files still unassigned are offered to this rule, so the first match
    % wins and a later pattern cannot quietly move a file between groups.
    free = cellfun(@isempty, {entries.group});
    if ~any(free); break; end
    [assigned, n] = assignGroupByFilter(entries(free), rules(r).pattern, ...
                                        rules(r).group, opts.root);
    if n > 0
        entries(free) = assigned;
    end
end

[groups, overall] = datasetSummary(entries);
summary = overall;
summary.groups = groups;
end

% ── helpers ─────────────────────────────────────────────────────────────────

function rules = normaliseRules(rules)
if isempty(rules)
    rules = struct('pattern', {}, 'group', {});
    return
end
if iscell(rules)
    if size(rules, 2) ~= 2
        error('nestapp:badGroupRules', ...
            'Group rules given as a cell must be Nx2: {pattern, groupName}.');
    end
    rules = struct('pattern', rules(:, 1)', 'group', rules(:, 2)');
end
if ~isfield(rules, 'pattern') || ~isfield(rules, 'group')
    error('nestapp:badGroupRules', ...
        'Group rules need .pattern and .group fields.');
end
end
