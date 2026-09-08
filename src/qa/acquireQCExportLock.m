
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function lock = acquireQCExportLock(lockRoot)
% ACQUIREQCEXPORTLOCK  Machine-wide lock that serializes QC figure export.
%   lock = ACQUIREQCEXPORTLOCK(lockRoot) blocks until it can claim a single
%   lock under lockRoot, then returns an onCleanup handle. The lock is
%   released when that handle is cleared or goes out of scope.
%
%   Why this exists: renderQualityFigure runs on parallel (process) workers,
%   and concurrent exportgraphics on headless workers can deadlock on shared
%   OS graphics resources (GPU/OpenGL context, the Windows font cache, the
%   print/raster temp path). The deadlock is non-deterministic and load-
%   dependent: in a big batch one random file wedges, but re-running it alone
%   (one worker, no contention) is fine. Serializing ONLY the export step
%   removes the contention while leaving the figure build fully parallel.
%
%   lockRoot must be a directory every worker shares - the batch root is the
%   natural choice (all workers write QC PNGs beneath it). It deliberately is
%   NOT placed in tempdir, because a parallel worker's tempdir is not
%   guaranteed to be the same folder the client / other workers see.
%
%   Robustness: the lock is an atomically-created directory. mkdir either
%   creates it (we hold the lock) or reports MATLAB:MKDIR:DirectoryExists
%   (someone else holds it) - that create-vs-exists distinction is the
%   OS-atomic arbiter. If a worker dies holding the lock, its age breaks a
%   stale lock after STALE_TIMEOUT_S so the pool can never wedge permanently.
%   If the lock cannot be created at all (permissions / bad path), we proceed
%   WITHOUT serialization rather than spin - the rare deadlock is a better
%   failure mode than a guaranteed hang. In a single process (no contention)
%   the first mkdir succeeds instantly.
%
%   See also: renderQualityFigure, processOneFile, outputPaths

STALE_TIMEOUT_S = 120;   % break a lock older than this (dead-worker guard).
                         % Far above any legitimate export time (sub-second to
                         % a few seconds), so a live render is never broken.
POLL_S          = 0.05;  % retry cadence while another worker holds the lock.

    if nargin < 1 || isempty(lockRoot)
        lockRoot = tempdir;   % fallback; pooled callers must pass a shared dir
    end
    lockDir = fullfile(lockRoot, '.nestapp_qc_export.lock');

    while true
        [ok, ~, msgid] = mkdir(lockDir);
        if ok && ~strcmp(msgid, 'MATLAB:MKDIR:DirectoryExists')
            break                       % we created it - lock is ours
        end
        if ~ok
            % Can't create the lock at all - don't spin or block the
            % pipeline; run unserialized (no-op release).
            lock = onCleanup(@() []);
            return
        end
        % Held by another worker. Break it if it's stale, else wait.
        if lockAgeSeconds(lockDir) > STALE_TIMEOUT_S
            forceRemove(lockDir);       % dead worker - reclaim, then re-contend
        else
            pause(POLL_S);
        end
    end

    lock = onCleanup(@() forceRemove(lockDir));
end

function ageS = lockAgeSeconds(lockDir)
d = dir(lockDir);
if isempty(d)
    ageS = inf;   % vanished between checks - treat as breakable
    return
end
% The '.' entry carries the directory's own timestamp (set at creation).
ageS = seconds(datetime('now') - datetime(d(1).datenum, 'ConvertFrom', 'datenum'));
end

function forceRemove(lockDir)
if exist(lockDir, 'dir')
    try
        rmdir(lockDir, 's');
    catch
        % Another worker may have already broken / recreated it - ignore.
    end
end
end
