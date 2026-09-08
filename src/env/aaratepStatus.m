% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function status = aaratepStatus(targetDir)
% AARATEPSTATUS  Whether the AARATEP helpers are installed, where, and which.
%   status = AARATEPSTATUS()           ask the whole search order
%   status = AARATEPSTATUS(targetDir)  ask one specific folder
%
%   Fields:
%     .installed  a tree carrying the sentinel function was found
%     .dir        where ('' if none)
%     .version    the release nestapp recorded installing ('' if unknown)
%     .isPinned   true when .version equals the pinned release
%     .label      one phrase naming what is there, for a message
%
%   A PURE QUERY, no network and no side effects, which is the point. It is
%   split out of installAaratep so the decisions around the download can be
%   tested without performing one: a test that reaches GitHub fails on a train,
%   behind a proxy, and on a runner with no egress, and a test that skips in
%   those conditions is a test that never runs.
%
%   IT DOES NOT GUESS A VERSION. Finding the sentinel file proves a tree is
%   there and nothing about which one - a years-old git clone looks identical
%   to a fresh install. installAaratep therefore stamps the tag it wrote, and
%   an unstamped tree is reported as unknown. For a tool whose claim is that a
%   template reproduces, announcing the pinned release over an arbitrary clone
%   is worse than admitting ignorance.
%
%   ASKING ONE FOLDER IS NOT THE SAME AS ASKING THE SEARCH ORDER, and conflating
%   them was a real bug: installAaratep('TargetDir', X) consulted the global
%   order, found the developer checkout at third_party/aaratep, reported
%   already-present, and never touched X.
%
%   See also: installAaratep, aaratepRelease, ensureAaratepOnPath

rel = aaratepRelease();
if nargin < 1 || isempty(targetDir)
    candidates = rel.searchDirs;
else
    candidates = {char(targetDir)};
end

status = struct('installed', false, 'dir', '', 'version', '', ...
                'isPinned', false, 'label', 'not installed');

for k = 1:numel(candidates)
    if isfile(fullfile(candidates{k}, [rel.sentinel '.m']))
        status.installed = true;
        status.dir       = candidates{k};
        break
    end
end
if ~status.installed
    return
end

status.version  = readStamp(status.dir);
status.isPinned = strcmp(status.version, rel.tag);

if isempty(status.version)
    status.label = 'An AARATEP tree (version unknown - not installed by nestapp)';
elseif status.isPinned
    status.label = sprintf('AARATEP %s', status.version);
else
    status.label = sprintf('AARATEP %s (nestapp pins %s)', status.version, rel.tag);
end
end

function tag = readStamp(dir_)
% The marker installAaratep writes naming what it installed. Absent for a tree
% that arrived any other way, which is the "unknown" case above.
tag = '';
f = fullfile(dir_, '.nestapp-aaratep-version');
if ~isfile(f); return; end
try
    tag = strtrim(fileread(f));
catch
    % An unreadable stamp is the same as none.
end
end
