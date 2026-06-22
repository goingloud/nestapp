
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_qcExportLock
% TEST_QCEXPORTLOCK  The QC export lock is a correct, self-healing mutex.
%
%   acquireQCExportLock serializes exportgraphics across parallel workers so a
%   big batch can't wedge on a concurrent-render deadlock. These tests pin the
%   primitive's contract: claiming creates the lock under the shared root;
%   releasing the handle frees it; a second claim sees the lock as held; and a
%   stale lock (dead worker) is broken so the pool never hangs forever.
%
%   Run: runtests('tests/unit/test_qcExportLock')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r); addpath(fullfile(r, 'src')); addpath(fullfile(r, 'src', 'qa'));
testCase.assumeNotEmpty(which('acquireQCExportLock'), 'helper must be on path');
end

function setup(testCase)
% A private shared root per test, cleaned up afterwards.
root = tempname;
mkdir(root);
testCase.TestData.root    = root;
testCase.TestData.lockDir = fullfile(root, '.nestapp_qc_export.lock');
testCase.addTeardown(@() rmdirIfPresent(root));
end

function test_claimCreatesLockUnderRoot(testCase)
lock = acquireQCExportLock(testCase.TestData.root); %#ok<NASGU>
testCase.verifyTrue(isfolder(testCase.TestData.lockDir), ...
    'claiming the lock must create the lock dir under the shared root');
end

function test_releaseFreesLock(testCase)
lock = acquireQCExportLock(testCase.TestData.root); %#ok<NASGU>
testCase.verifyTrue(isfolder(testCase.TestData.lockDir));
clear lock                                  % triggers the onCleanup release
testCase.verifyFalse(isfolder(testCase.TestData.lockDir), ...
    'clearing the returned handle must release (remove) the lock');
end

function test_secondClaimSeesHeldLock(testCase)
% While one holder has the lock, a bare mkdir of the same dir must report
% DirectoryExists - that create-vs-exists distinction is what arbitrates the
% mutual exclusion between workers.
lock = acquireQCExportLock(testCase.TestData.root); %#ok<NASGU>
[ok, ~, msgid] = mkdir(testCase.TestData.lockDir);
testCase.verifyTrue(ok);
testCase.verifyEqual(msgid, 'MATLAB:MKDIR:DirectoryExists', ...
    'a held lock must look "already exists" to a contender');
end

function test_staleLockIsBroken(testCase)
% Simulate a worker that died holding the lock: create the lock dir, then
% backdate it far into the past. acquire must break it and return promptly
% (well under the 120 s stale timeout), not block forever.
lockDir = testCase.TestData.lockDir;
mkdir(lockDir);
backdate(lockDir);                          % epoch 0 -> very stale

t0   = tic;
lock = acquireQCExportLock(testCase.TestData.root); %#ok<NASGU>
elapsed = toc(t0);

testCase.verifyLessThan(elapsed, 30, 'stale lock must be broken quickly, not waited out');
testCase.verifyTrue(isfolder(lockDir), 'after breaking a stale lock we hold a fresh one');
end

% -- helpers --------------------------------------------------------------

function backdate(dirPath)
% Set the directory's last-modified time to the epoch via Java, so dir()
% reports it as far older than the stale timeout. Portable across OSes.
f = java.io.File(dirPath);
f.setLastModified(0);
end

function rmdirIfPresent(p)
if exist(p, 'dir')
    try
        rmdir(p, 's');
    catch
    end
end
end
