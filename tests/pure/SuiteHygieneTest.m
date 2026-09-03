% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef SuiteHygieneTest < NestappTestCase
% SUITEHYGIENETEST  The suite's rules about itself, enforced rather than written down.
%
%   Every rule here corresponds to a way the previous suite decayed. That suite
%   was not written by people who thought duplication was fine; it drifted one
%   reasonable-looking file at a time, and nothing was watching. A convention
%   document would not have stopped it - 50 verbatim copies of one 3-line
%   helper accumulated while the duplication was entirely obvious.
%
%   So the conventions are executable. Each test names the specific decay it
%   prevents, and fails with the list of offending files.
%
%   WHY EACH TEST LOOPS INSTEAD OF USING TestParameter. One test per rule, not
%   one per file: the FACT being asserted is the rule ("no test rolls its own
%   temp dir"), and the files are merely its domain. Parameterising over ~30
%   files x 8 rules would report 240 results for 8 facts, which is precisely
%   the inflation this rewrite exists to undo. The failure message lists every
%   offender, so nothing is lost diagnostically - unlike the old
%   characterization test, which collapsed ten genuinely distinct behaviours
%   into one verifyEmpty and there the granularity really was wrong.
%
%   THE SUITE IS READ ONCE, in TestClassSetup. An earlier version read and
%   comment-stripped every file inside every rule, which came to ELEVEN full
%   passes over the tree per run - a cost that grew with each rule added, not
%   merely with each file. Reading once makes it one.
%
%   EVERY RULE IS ONE SHAPE: verifyNoneOf(noteFcn, why). Three rules used to
%   hand-roll the accumulate-and-verify loop instead of using the helper the
%   other five went through, which is one more way for a ninth rule to be
%   written inconsistently with the rest.
%
%   These rules apply to the NEW suite only. The legacy folders are exempt
%   until they are deleted; they violate nearly all of it, which is the point.

    properties (Constant)
        % The four folders the rules govern. Legacy folders are absent by
        % design - see the class comment.
        SuiteFolders = {'pure', 'eeglab', 'gui', 'eeglab_gui'}

        % Files permitted to read nestapp source as text. Source scraping is
        % not banned outright because two contracts genuinely need it - "every
        % plot param key is a real option of its draw function" and "every case
        % literal in methodsClause is a real registry step". Both DERIVE the
        % expected set from the registry rather than hardcoding it, which is
        % what separates them from the 19 brittle scrapes being deleted (exact
        % source lines as string literals; extractBetween bounded by an
        % ADJACENT function's name, so renaming a neighbour broke them).
        % An allowlist makes adding a third one a deliberate act.
        MayReadSource = {'RegistryContractTest', 'MethodsClauseTest'}
    end

    properties (Access = private)
        % One entry per suite file: .path .name .folder .code (comments stripped).
        Files
    end

    methods (TestClassSetup)
        function readTheSuiteOnce(tc)
        % Runs after NestappTestCase's own TestClassSetup has fixed the path.
            tc.Files = struct('path', {}, 'name', {}, 'folder', {}, 'code', {});
            root = fullfile(addNestappPath(), 'tests');

            % Every suite folder goes on the path for the duration, because
            % everyTestClassInheritsTheBase resolves classes by reflection and
            % meta.class.fromName cannot see a class MATLAB cannot load. Only
            % the folder being RUN is on the path otherwise, so the rule would
            % report every file in the other three as not inheriting the base -
            % which it did, the moment tests/gui gained its first file.
            %
            % A PathFixture rather than addpath: it restores itself, and it is
            % not the bare addpath call this file's own rules ban elsewhere.
            present = {};
            for k = 1:numel(tc.SuiteFolders)
                d = fullfile(root, tc.SuiteFolders{k});
                if isfolder(d); present{end+1} = d; end %#ok<AGROW>
            end
            if ~isempty(present)
                tc.applyFixture(matlab.unittest.fixtures.PathFixture(present));
            end
            for k = 1:numel(tc.SuiteFolders)
                folder = tc.SuiteFolders{k};
                d = fullfile(root, folder);
                if ~isfolder(d); continue; end
                e = dir(fullfile(d, '*.m'));
                for i = 1:numel(e)
                    % This file is exempt from its own scan. It necessarily
                    % CONTAINS every pattern it forbids - the bans are written
                    % here as regex literals - so including it would make each
                    % rule report itself. Found the moment the suite first ran:
                    % noTestRollsItsOwnTempDir failed on its own
                    % '(tempname|tempdir)' pattern. The alternative, parsing
                    % MATLAB well enough to ignore string literals, is far more
                    % machinery than these rules are worth.
                    if strcmp(e(i).name, 'SuiteHygieneTest.m'); continue; end
                    p = fullfile(d, e(i).name);
                    [~, name] = fileparts(e(i).name);
                    tc.Files(end+1) = struct('path', p, 'name', name, ...
                                             'folder', folder, ...
                                             'code', stripComments(p));
                end
            end
        end
    end

    methods (Test)

        function noTestRollsItsOwnPathSetup(tc)
        % 50 verbatim copies of repoRoot() and 107 fileparts^3 chains, which
        % had already drifted: 49 files used a bare addpath(src) and 56 used
        % genpath, so whether src/qa was reachable depended on which file you
        % ran. NestappTestCase does this once.
            tc.verifyNoMatch('(^|\s)function\s+\w+\s*=\s*(repoRoot|srcRoot)\b', ...
                'defines its own repoRoot/srcRoot - inherit NestappTestCase instead');
            tc.verifyNoMatch('(^|[^.\w])addpath\s*\(', ...
                'calls addpath directly - NestappTestCase does that');
            tc.verifyNoMatch('fileparts\s*\(\s*fileparts\s*\(', ...
                'walks up to the repo root by hand - use addNestappPath');
        end

        function noTestRollsItsOwnTempDir(tc)
        % ~30 creation sites in five idioms, of which the old sweep matched
        % four; one of its five hardcoded prefixes matched nothing at all.
            tc.verifyNoMatch('(^|[^.\w])(tempname|tempdir)\s*[\(;,)]', ...
                'builds its own temp dir - use scratchDir(tc)');
        end

        function noTestDecidesItCannotRun(tc)
        % 38 assume* sites, twelve of which skipped on a function shipped in
        % THIS repo - turning a path bug into a green run. The folder declares
        % what a test needs; run_tests checks it once, up front.
            tc.verifyNoMatch('\.assume(Fail|NotEmpty|True|False|Equal|NotEqual)\s*\(', ...
                'skips itself at runtime - the folder already declares its needs');
        end

        function noTestAssertsSomethingThatCannotFail(tc)
        % The old suite contained a literal verifyTrue(true) as a test's only
        % assertion, plus file-size floors standing in for "it rendered".
            tc.verifyNoMatch('verify(True|False)\s*\(\s*(true|false)\s*\)', ...
                'asserts a literal - that cannot fail');
        end

        function everyTestClassInheritsTheBase(tc)
        % Asked of the class hierarchy MATLAB actually resolved, not of the
        % source text: matching '< NestappTestCase' is whitespace-sensitive and
        % blind to a class that inherits through an intermediate base.
            tc.verifyNoneOf(@(f) noteWhen(~inheritsBase(f.name)), ...
                'does not extend NestappTestCase');
        end

        function sourceScrapingIsOptIn(tc)
        % Behavioural over textual, with a named exception list. The old suite
        % had 19 scrapes; test_dispatchCoverage even documents why it stopped
        % ("passes or fails on how the code is WRITTEN rather than what it
        % DOES") while two other files went on scraping the same file.
            allowed = tc.MayReadSource;
            tc.verifyNoneOf(@(f) noteWhen(~ismember(f.name, allowed) && ...
                    ~isempty(regexp(f.code, '(fileread|readlines)\s*\(', 'once'))), ...
                ['reads source as text; prefer a behavioural test, or add it ' ...
                 'to SuiteHygieneTest.MayReadSource with a reason']);
        end

        function everyTestIsInTheFolderItsDependenciesRequire(tc)
        % The load-bearing rule. The old taxonomy was drawn on "does it call an
        % EEGLAB function" rather than on what a test NEEDS, which left 11
        % files in the documented no-EEGLAB-no-GUI suite needing one or the
        % other, and made its stated contract false.
            tc.verifyNoneOf(@folderNote, 'is in the wrong folder');
        end

        function everySuiteFolderIsTrackable(tc)
        % .gitignore ignores every directory by default and whitelists test
        % folders one at a time, so a folder that is not listed is SILENTLY
        % untracked - git add reports nothing and the commit looks clean. Not
        % hypothetical: tests/pure was created, two test files were written and
        % run green, and both were omitted from the commit without a word.
        %
        % The postmortem comment left in .gitignore asks a human to remember.
        % This is that same rule, enforced - which is this file's whole
        % argument, applied to the one place it had been left as prose.
            ignore  = fileread(fullfile(addNestappPath(), '.gitignore'));
            missing = {};
            for k = 1:numel(tc.SuiteFolders)
                want = sprintf('!tests/%s/*.m', tc.SuiteFolders{k});
                if ~contains(ignore, want)
                    missing{end+1} = want; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(missing, sprintf( ...
                ['.gitignore does not whitelist %d suite folder(s), so files ' ...
                 'there are silently untracked. Add: %s'], ...
                numel(missing), strjoin(missing, ', ')));
        end

        function theHelpersAreActuallyShared(tc)
        % charFixture and fakeRegistry both existed in the old suite and both
        % failed to take: charFixture had ZERO callers in unit/ while nine
        % local EEG builders lived there, and fakeRegistry had one caller
        % against four private reimplementations. A shared fixture with no
        % uptake is worse than none - it is a second thing to keep in step.
            names = {'fakeEeg', 'fakeGroupResult'};
            for k = 1:numel(names)
                pattern = ['(^|[^.\w])' names{k} '\s*\('];
                used = arrayfun(@(f) ~isempty(regexp(f.code, pattern, 'once')), ...
                                tc.Files);
                tc.verifyTrue(any(used), sprintf( ...
                    ['helpers/%s.m has no callers. Either it is not the right ' ...
                     'abstraction, or tests are rolling their own - both are ' ...
                     'faults, and the second is how the old suite got eleven ' ...
                     'fake-EEG builders.'], names{k}));
            end
        end
    end

    % ── the one shape every rule uses ────────────────────────────────────────
    methods (Access = private)

        function verifyNoneOf(tc, noteFcn, why)
        % noteFcn(fileEntry) returns '' when the file is fine, or text to
        % append to its name when it is not.
            bad = {};
            for i = 1:numel(tc.Files)
                note = noteFcn(tc.Files(i));
                if isempty(note); continue; end
                bad{end+1} = [shortPath(tc.Files(i).path) note]; %#ok<AGROW>
            end
            tc.verifyEmpty(bad, listing(bad, why));
        end

        function verifyNoMatch(tc, pattern, why)
            tc.verifyNoneOf(@(f) noteWhen(~isempty(regexp(f.code, pattern, 'once'))), why);
        end
    end
end

% ── file-level helpers ───────────────────────────────────────────────────────

function code = stripComments(p)
% Not cosmetic: an earlier version of this scan matched the licence header
% "% Part of nestapp; see the LICENSE..." in every single file and classified
% the whole suite as needing a display.
lines = strtrim(strsplit(fileread(p), newline));
lines = lines(~startsWith(lines, '%'));
code  = strjoin(regexprep(lines, '%.*$', ''), newline);
end

function tf = inheritsBase(className)
% Walks the real superclass list. Falls back to false when the class cannot be
% resolved at all, which is itself worth failing on - a suite file MATLAB
% cannot load is not a test.
tf = false;
mc = meta.class.fromName(className);
if isempty(mc); return; end
seen = {};
queue = {mc};
while ~isempty(queue)
    c = queue{1}; queue(1) = [];
    if ismember(c.Name, seen); continue; end
    seen{end+1} = c.Name; %#ok<AGROW>
    if strcmp(c.Name, 'NestappTestCase'); tf = true; return; end
    queue = [queue, num2cell(c.SuperclassList')]; %#ok<AGROW>
end
end

function note = noteWhen(isBad)
% The common case: a rule that only needs to say yes or no. Non-empty means
% "offending"; verifyNoneOf appends it to the file name, and a single space
% appends nothing visible.
if isBad; note = ' '; else; note = ''; end
end

function note = folderNote(f)
% A folder may be MORE permissive than the file needs (a pure test parked in
% eeglab/ is wasteful, not wrong), but never less: that is the failure that
% makes a suite's contract a lie.
needsEeglab = ~isempty(regexp(f.code, ['(^|[^.\w])(pop_[a-z]\w*|eeg_checkset|' ...
    'eeg_emptyset|eeglab|topoplot|convertlocs|readlocs)\s*\('], 'once'));
needsDisplay = ~isempty(regexp(f.code, ['(^|[^.\w])(uifigure|figure|uiaxes|axes|' ...
    'subplot|uipanel|exportapp|nestapp)\s*\('], 'once'));

if      needsEeglab &&  needsDisplay; want = 'eeglab_gui';
elseif  needsEeglab;                  want = 'eeglab';
elseif  needsDisplay;                 want = 'gui';
else;                                 want = 'pure';
end

% Explicit membership rather than a rank comparison, because gui and eeglab are
% SIBLINGS, not ordered - a rank would happily accept a display-needing test in
% eeglab/, where there is no display.
switch want
    case 'pure';       ok = true;
    case 'gui';        ok = ismember(f.folder, {'gui', 'eeglab_gui'});
    case 'eeglab';     ok = ismember(f.folder, {'eeglab', 'eeglab_gui'});
    case 'eeglab_gui'; ok = strcmp(f.folder, 'eeglab_gui');
end

note = '';
if ~ok
    note = sprintf(' (in %s/, needs %s/)', f.folder, want);
end
end

function s = shortPath(p)
parts = strsplit(strrep(p, filesep, '/'), '/tests/');
s = parts{end};
end

function msg = listing(items, why)
if isempty(items); msg = ''; return; end
msg = sprintf('%d file(s) %s:\n  %s', numel(items), why, ...
              strjoin(items, sprintf('\n  ')));
end
