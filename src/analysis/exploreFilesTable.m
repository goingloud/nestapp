% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function entries = exploreFilesTable(entries, opts)
% EXPLOREFILESTABLE  Show and edit which file belongs to whom and to which group.
%   entries = EXPLOREFILESTABLE(entries) opens a modal table of
%   file | subject | group, with subject and group editable, and returns the
%   edited entries - or [] if cancelled.
%
%   This is the backstop the whole subject story rests on. Subject identity
%   cannot be derived reliably from arbitrary naming, and the count it produces
%   sets n for every confidence interval, so the app's position is: never guess
%   silently, always show what was assumed, and make it correctable here.
%
%   Two actions fill the subject column wholesale:
%
%     One subject per file        every recording is its own person, so n is the
%                                 number of files. The default, and correct
%                                 whenever each file IS a different participant.
%     Guess from filenames        runs inferSubjectIds, which collapses repeat
%                                 recordings. PREVIEWED before it applies - on a
%                                 real cohort this turns 148 files into 95
%                                 subjects, and a change that large to n should
%                                 never happen without being seen first.
%
%   The count line is the point of the whole dialog: it states files, subjects
%   and groups at all times, so "why is n 92 and not 148" is answerable by
%   looking rather than by reading source.
%
%   opts:
%     .parent   figure to centre over
%     .title    window title
%
%   See also: exploreDataset, inferSubjectIds, datasetSummary

if nargin < 2; opts = struct(); end
opts = fillDefaults(opts, struct('parent', [], 'title', 'Files, subjects and groups'));

if isempty(entries)
    entries = [];
    return
end

work     = entries;
accepted = false;

W = 760; H = 520;
PAD = 12;

fig = uifigure('Name', char(opts.title), 'Resize', 'off', ...
               'Position', centreOn(opts.parent, W, H), 'WindowStyle', 'modal');
% Exit is by DELETING the figure, never by uiresume, and the wait is waitfor
% rather than uiwait. selectDataTree already documents why: uiresume's
% close-on-X path can leave the window up and soft-lock the app. The concrete
% failure is a nested modal - uiconfirm or uialert on this same figure runs its
% own wait, and afterwards a uiresume no longer releases the outer uiwait, so
% the X silently does nothing and the app is stuck behind a window that will
% not close. waitfor returns the moment the figure is destroyed, and a plain
% delete cannot be vetoed or missed.
%
% Not an onCleanup either: the callbacks are nested functions holding this
% workspace, which would hold the onCleanup, which would hold the figure - a
% cycle that leaks a window on every call.
fig.CloseRequestFcn = @(src, ~) delete(src);

try
tbl = uitable(fig, 'Position', [PAD, 96, W - 2*PAD, H - 96 - 56], ...
    'ColumnName', {'File', 'Subject', 'Group'}, ...
    'ColumnWidth', {430, 150, 130}, ...
    'ColumnEditable', [false true true], 'RowName', {});
tbl.CellEditCallback = @(~, ev) onEdit(ev);

countLabel = uilabel(fig, 'Position', [PAD, H - 34, W - 2*PAD, 22], ...
    'FontWeight', 'bold');

uibutton(fig, 'Text', 'One subject per file', 'Position', [PAD, 62, 170, 26], ...
    'ButtonPushedFcn', @(~, ~) subjectsPerFile());
uibutton(fig, 'Text', 'Guess from filenames...', 'Position', [PAD + 178, 62, 190, 26], ...
    'ButtonPushedFcn', @(~, ~) guessSubjects());

uilabel(fig, 'Position', [PAD, 34, W - 2*PAD, 22], 'FontSize', 11, ...
    'FontColor', [0.35 0.38 0.43], ...
    'Text', ['Subject identity only matters for two things: collapsing repeat ' ...
             'recordings of one person, and pairing groups. Otherwise leave it.']);

uibutton(fig, 'Text', 'Use these assignments', 'Position', [W - PAD - 320, PAD, 155, 26], ...
    'ButtonPushedFcn', @(~, ~) accept());
uibutton(fig, 'Text', 'Cancel', 'Position', [W - PAD - 155, PAD, 155, 26], ...
    'ButtonPushedFcn', @(~, ~) delete(fig));

refresh();
setappdata(fig, 'nestappModalReady', true);
waitfor(fig);
catch ME
    if isvalid(fig); delete(fig); end
    rethrow(ME);
end

% `accepted` and `work` live in this workspace, which outlives the figure, so
% the answer survives the deletion that released waitfor.
if accepted
    entries = work;
else
    entries = [];
end
if isvalid(fig); delete(fig); end

% ── nested ───────────────────────────────────────────────────────────────
    function refresh()
        n = numel(work);
        data = cell(n, 3);
        for i = 1:n
            data{i, 1} = shortPath(work(i).path);
            data{i, 2} = work(i).subject;
            data{i, 3} = work(i).group;
        end
        tbl.Data = data;
        countLabel.Text = summaryText(work);
    end

    function onEdit(ev)
        r = ev.Indices(1);
        c = ev.Indices(2);
        if r < 1 || r > numel(work); return; end
        v = strtrim(char(string(ev.NewData)));
        switch c
            case 2
                if isempty(v)
                    % An empty subject would silently merge rows; refuse it.
                    refresh();
                    return
                end
                work(r).subject = v;
                work(r).subjectConfident = true;   % given, not guessed
            case 3
                work(r).group = v;
        end
        refresh();
    end

    function subjectsPerFile()
        paths = {work.path};
        ids   = exploreDataset(paths, {});      % 'file' mode is the default
        for i = 1:numel(work)
            work(i).subject          = ids(i).subject;
            work(i).subjectConfident = true;
        end
        refresh();
    end

    function guessSubjects()
        paths  = {work.path};
        [ids, confident] = inferSubjectIds(paths);
        nSub   = numel(unique(ids));
        % Preview first. Collapsing files into subjects changes n for every
        % interval, so the size of that change is shown before it happens.
        msg = sprintf(['Guessing subjects from filenames would give %d ' ...
            'subject(s) from %d file(s).\n\n%s'], nSub, numel(paths), ...
            collapseNote(nSub, numel(paths), sum(~confident)));
        choice = uiconfirm(fig, msg, 'Guess subjects', ...
            'Options', {'Apply', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
        if ~strcmp(choice, 'Apply'); return; end
        for i = 1:numel(work)
            work(i).subject          = ids{i};
            work(i).subjectConfident = confident(i);
        end
        refresh();
    end

    function accept()
        accepted = true;
        delete(fig);
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function s = summaryText(work)
[~, overall] = datasetSummary(work);
nSub = numel(unique({work.subject}));
s = sprintf('%d files   |   %d subjects   |   %d group(s)', ...
            numel(work), nSub, overall.nGroups);
if overall.nUngrouped > 0
    s = sprintf('%s   |   %d not in a group', s, overall.nUngrouped);
end
if nSub < numel(work)
    s = sprintf('%s   |   %d files share a subject', s, numel(work) - nSub);
end
end

function s = collapseNote(nSub, nFiles, nUnsure)
if nSub == nFiles
    s = 'No files would be merged, so n would not change.';
    return
end
s = sprintf(['%d file(s) would be merged into a shared subject, so n falls ' ...
     'from %d to %d and every confidence interval widens. Correct if those ' ...
     'files are repeat recordings of the same person; wrong if they are ' ...
     'different people.'], nFiles - nSub, nFiles, nSub);
if nUnsure > 0
    s = sprintf(['%s\n\n%d id(s) came from a name with no digits, which is ' ...
        'more often a condition than a person - check those rows.'], s, nUnsure);
end
end

function s = shortPath(p)
% Enough of the tail to identify the file without a 200-character cell.
p   = strrep(char(p), '\', '/');
seg = strsplit(p, '/');
seg = seg(~cellfun(@isempty, seg));
if numel(seg) <= 3
    s = strjoin(seg, '/');
else
    s = ['.../' strjoin(seg(end-2:end), '/')];
end
end
