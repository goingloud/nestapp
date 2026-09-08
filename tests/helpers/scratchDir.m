% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function d = scratchDir(testCase)
% SCRATCHDIR  A temp directory for one test, removed when that test ends.
%   d = SCRATCHDIR(testCase)
%
%   Registers its own teardown, so the caller writes one line:
%
%       d = scratchDir(tc);
%
%   ONE IDIOM, replacing five. The old suite created scratch directories at
%   ~30 sites in five different shapes - bare tempname; tempname + onCleanup;
%   tempdir + a uuid behind a per-test prefix; a FIXED name reused across runs;
%   and per-method mkdir blocks repeated four times inside one file. run_tests
%   then swept tempdir for five hardcoded prefixes, of which one ('qg_batch_')
%   matched nothing in the repo at all, while the 21 files using bare tempname
%   matched none of the five. So the sweep reaped 4 of ~30 creation sites and
%   every new test had to remember to extend a list it could not see.
%
%   With one idiom and a teardown that always runs, THE SWEEP IS UNNECESSARY:
%   there is no list to keep in step, and an interrupted run leaves at most one
%   directory under a single recognisable prefix.
%
%   Deliberately NOT matlab.unittest.fixtures.TemporaryFolderFixture, which
%   does the same job: applyFixture returns the folder on a property of the
%   fixture object, so every caller becomes two lines and a local variable
%   holding a fixture it does not otherwise use. This is one line and reads as
%   what it is.
%
%   The name carries the prefix so a directory surviving a killed session is
%   identifiable as nestapp's; the uuid is what keeps two concurrent MATLAB
%   sessions from colliding, so no process id is needed (and matlabProcessID
%   would not be available on the R2023a this project still supports).
%
%   See also: addNestappPath, run_tests

d = fullfile(tempdir, ['nestapp_test_' char(matlab.lang.internal.uuid())]);
mkdir(d);
testCase.addTeardown(@() removeQuietly(d));
end

function removeQuietly(d)
% Best-effort: a directory still held open by another process must not turn a
% passing test red on the way out.
if ~isfolder(d); return; end
try
    rmdir(d, 's');
catch
    % Left for the OS. One stale directory is not worth failing a run over.
end
end
