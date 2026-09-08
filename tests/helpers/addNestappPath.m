% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function root = addNestappPath()
% ADDNESTAPPPATH  Put nestapp on the MATLAB path, once, and return the repo root.
%   root = ADDNESTAPPPATH()
%
%   Idempotent: repeated calls do nothing after the first, so a hundred test
%   classes may each call it in TestClassSetup without re-ordering the path a
%   hundred times.
%
%   THIS REPLACES 50 VERBATIM COPIES of a local repoRoot() helper, and 107
%   occurrences of fileparts(fileparts(fileparts(mfilename('fullpath')))). That
%   duplication was not merely untidy - it had already drifted: 49 test files
%   used a non-recursive addpath(<repo>/src) while 56 used genpath, so whether
%   src/qa and src/io were reachable depended on which file you ran. Twelve
%   tests papered over the difference by opening with
%
%       testCase.assumeNotEmpty(which('<a function in this very repo>'))
%
%   which turns a path bug into a silently skipped test, i.e. a green run. One
%   helper removes the inconsistency and the guards together.
%
%   THE "ALREADY DONE" CHECK IS DERIVED FROM THE PATH, NOT CACHED. A persistent
%   flag would be the third instance in this project of a cached path answer
%   that never notices the path changing underneath it - the bug that made
%   ensureEeglabReady report ready with pop_loadset gone, and that pathMemo
%   exists to prevent. It matters here specifically: the pure suite is verified
%   by calling restoredefaultpath and re-running in the SAME session, which a
%   cached flag would defeat.
%
%   pathMemo itself cannot be used, because it lives in src/ and this function
%   is what puts src/ on the path. So the check probes two sentinels directly:
%   one from src/ root and one from a subdirectory, which together verify the
%   SHAPE of the path (genpath, not a bare addpath) rather than merely that
%   something was added. Two which() calls cost ~50 us.
%
%   EEGLAB is NOT added. Whether it is present is what the tests/eeglab and
%   tests/pure split encodes, and a helper that quietly added it would make
%   every pure test pass for the wrong reason.
%
%   See also: scratchDir, pathMemo, run_tests

% tests/helpers/addNestappPath.m -> tests/helpers -> tests -> <repo root>
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));

if ~isempty(which('fillDefaults')) && ~isempty(which('outputPaths'))
    return   % src/ root and src/io both resolve: the path is already right
end

addpath(root);
addpath(genpath(fullfile(root, 'src')));
addpath(here);
end
