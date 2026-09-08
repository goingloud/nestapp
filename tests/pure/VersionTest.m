% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef VersionTest < NestappTestCase
% VERSIONTEST  The version is stated in four places and they must agree.
%
%   nestappVersion is what the app reports, what a report header stamps, what
%   an error bundle records, and what tools/package_toolbox.m names the .mltbx.
%   CHANGELOG.md, CITATION.cff and the README badge each restate it. Four
%   copies of one fact, and the only thing keeping them in step is this test.
%
%   RESTORED AT THE 2.1.0 RELEASE, and its absence is worth recording. The old
%   suite had this check; the rewrite's cutover deleted it and nothing replaced
%   it. That was a mistake on my part rather than a judgement - unlike the
%   source-scraping tests dropped in the same commit, this one asserts a real
%   invariant the CHANGELOG's own header states ("The version here must match
%   src/nestappVersion.m and the release git tag"). It went unnoticed for
%   exactly as long as nobody cut a release, which is the failure mode of a
%   check nothing enforces.
%
%   Reading these files as text is the only way to compare them, so
%   VersionTest is on SuiteHygieneTest's MayReadSource list. They are
%   documents, not source.

    properties (Constant)
        % Semver, three components. The old check allowed only this shape and
        % it is worth keeping strict: the pre-1.0 tags were v1.01 ... v2.0,
        % which sort unpredictably and are part of why the numbering had to be
        % straightened out at 2.1.0 (see CHANGELOG).
        Semver = '^\d+\.\d+\.\d+$'
    end

    methods (Test)

        function theVersionIsSemver(tc)
            v = nestappVersion();
            tc.verifyClass(v, 'char');
            tc.verifyMatches(v, tc.Semver, ...
                'nestappVersion must be MAJOR.MINOR.PATCH');
        end

        function theChangelogTopSectionIsThisVersion(tc)
        % The newest RELEASED section, skipping [Unreleased] - which is a
        % standing heading in Keep a Changelog format and carries no version.
            [ver, ~] = tc.topChangelogRelease();
            tc.verifyEqual(ver, nestappVersion(), ...
                ['CHANGELOG.md''s newest released section and ' ...
                 'nestappVersion disagree. Its own header says they must ' ...
                 'match, and a release is cut from both.']);
        end

        function theCitationMetadataMatches(tc)
        % CITATION.cff is what GitHub's "Cite this repository" button reads, so
        % a stale version here is a wrong citation in somebody's manuscript -
        % the one place a version being wrong outlives the project.
            cff = fileread(fullfile(addNestappPath(), 'CITATION.cff'));
            tok = regexp(cff, '(?m)^version:\s*(\S+)\s*$', 'tokens', 'once');
            tc.assertNotEmpty(tok, 'CITATION.cff states no version');
            tc.verifyEqual(strtrim(tok{1}), nestappVersion());
        end

        function theCitationReleaseDateMatchesTheChangelog(tc)
            [~, changelogDate] = tc.topChangelogRelease();
            cff = fileread(fullfile(addNestappPath(), 'CITATION.cff'));
            tok = regexp(cff, '(?m)^date-released:\s*"?([\d-]+)"?\s*$', 'tokens', 'once');
            tc.assertNotEmpty(tok, 'CITATION.cff states no release date');
            tc.verifyEqual(strtrim(tok{1}), changelogDate, ...
                'the cited release date is not the date the CHANGELOG gives');
        end

        function theReadmeBadgeMatches(tc)
        % The first version number anyone sees. A badge showing 1.0.0 over a
        % 2.1.0 release is the same confusion this release exists to end.
            readme = fileread(fullfile(addNestappPath(), 'README.md'));
            tok = regexp(readme, 'badge/version-([\d.]+)-', 'tokens', 'once');
            tc.assertNotEmpty(tok, 'the README has no version badge');
            tc.verifyEqual(tok{1}, nestappVersion());
        end

        function everyChangelogVersionIsSemverAndDescending(tc)
        % Ordering, not just format. The whole reason for 2.1.0 is that a
        % published v2.0 sorted above a later 1.0.0, so a file that lists its
        % releases out of order is the same fault written down.
            changelog = fileread(fullfile(addNestappPath(), 'CHANGELOG.md'));
            % Brackets optional: a version that was released but never tagged
            % on GitHub carries no link reference, so it is written unbracketed
            % (1.0.0). It still has to be in order.
            vers = regexp(changelog, '(?m)^## \[?(\d+\.\d+\.\d+)\]?', 'tokens');
            vers = cellfun(@(c) c{1}, vers, 'UniformOutput', false);
            tc.assertNotEmpty(vers, 'CHANGELOG.md lists no released versions');

            nums = cell2mat(cellfun(@(v) sscanf(v, '%d.%d.%d')', vers, ...
                                    'UniformOutput', false)');
            for k = 2:size(nums, 1)
                tc.verifyTrue(isBefore(nums(k, :), nums(k-1, :)), sprintf( ...
                    ['CHANGELOG.md lists %s above %s, so its releases are ' ...
                     'not in descending order'], vers{k-1}, vers{k}));
            end
        end
    end

    methods (Access = private)
        function [ver, dateStr] = topChangelogRelease(tc)
        % The first `## [x.y.z] - date` heading in the file.
            changelog = fileread(fullfile(addNestappPath(), 'CHANGELOG.md'));
            tok = regexp(changelog, ...
                '(?m)^## \[?(\d+\.\d+\.\d+)\]?\s*-\s*([\d-]+)', 'tokens', 'once');
            tc.assertNotEmpty(tok, ...
                'CHANGELOG.md has no `## [x.y.z] - YYYY-MM-DD` section');
            ver     = tok{1};
            dateStr = strtrim(tok{2});
        end
    end
end

% ── local helpers ─────────────────────────────────────────────────────────────

function tf = isBefore(a, b)
% True when version vector a is strictly older than b.
tf = false;
for i = 1:3
    if a(i) ~= b(i); tf = a(i) < b(i); return; end
end
end
