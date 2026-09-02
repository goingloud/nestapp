% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_loadEegFile
% TEST_LOADEEGFILE  The format dispatch, now that it is shared.
%
%   The reader choice moved out of processOneFile's 'Load Data' case so that
%   anything wanting a recording - the pipeline, the raw-data browser - picks
%   the same one. Two things are worth pinning:
%
%   1. An unreadable extension raises nestapp:unknownFormat, so a caller can
%      tell "wrong kind of file" apart from a reader failing on a file it
%      accepted. The browser shows a different message for each.
%   2. The dispatch is case-insensitive. '.SET' came off a Windows share in
%      the cohort, and the old end-2:end / strcmpi test accepted it; a switch
%      on a raw extension would silently have stopped.
%
%   Actually reading a file needs EEGLAB and a real recording, which the
%   integration suite covers through the pipeline. These are the routing
%   contract only.
%
%   Run: runtests('tests/unit/test_loadEegFile')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('loadEegFile'));
end

function test_anUnknownExtensionIsNamedAsSuch(testCase)
try
    loadEegFile(fullfile(tempdir, 'recording.xyz'));
    testCase.verifyFail('an unreadable extension should have raised');
catch err
    testCase.verifyEqual(err.identifier, 'nestapp:unknownFormat');
    testCase.verifySubstring(err.message, 'recording.xyz', ...
        'the message should name the offending file');
end
end

function test_aFileWithNoExtensionIsUnknownRatherThanAGuess(testCase)
try
    loadEegFile(fullfile(tempdir, 'recording'));
    testCase.verifyFail('a bare name should have raised');
catch err
    testCase.verifyEqual(err.identifier, 'nestapp:unknownFormat');
end
end

function test_aKnownExtensionIsNotCalledUnknownWhateverItsCase(testCase)
% '.SET' came off a Windows share in the cohort and the old end-2:end /
% strcmpi test accepted it, so the switch must too.
%
% This asserts on the ROUTING TABLE rather than by calling loadEegFile,
% deliberately. Handing a known extension to the real function reaches
% pop_loadset / pop_loadbv, and those mutate the session - they add paths and
% touch EEGLAB's globals even when the file is missing - which leaks into
% whatever test runs next. A unit test in the no-EEGLAB suite must not do
% that.
src = fileread(which('loadEegFile'));
testCase.verifySubstring(src, 'switch lower(ext)', ...
    'the dispatch must fold case before matching');
for ext = {'.set', '.cnt', '.cdt', '.vhdr'}
    testCase.verifySubstring(src, sprintf('case ''%s''', ext{1}), ...
        sprintf('%s should have a branch, in lower case', ext{1}));
end
end
