% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_pathMemo
% TEST_PATHMEMO  A cached path answer is only valid while its sentinel holds.
%
%   Three functions used to invent this policy separately and two got it wrong
%   the same way, so the policy is pinned here once. What matters is not that
%   caching works - it is that the cache is DROPPED in each of the ways the
%   path can change underneath it:
%
%     the sentinel stops resolving   (restoredefaultpath, hideFromPath, rmpath)
%     the sentinel resolves ELSEWHERE (a swapped install - the case none of the
%                                     three hand-rolled caches ever caught)
%
%   The sentinel here is a scratch function written to a temp folder, so the
%   test owns the whole path story and needs neither EEGLAB nor AARATEP.
%
%   Run: runtests('tests/unit/test_pathMemo')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(fullfile(r, 'src'));
testCase.assumeNotEmpty(which('pathMemo'));
end

function setup(testCase)
% A sentinel function nothing else on this machine could provide.
testCase.TestData.name = sprintf('nestappMemoProbe%d', feature('getpid'));
testCase.TestData.dirs = {};
pathMemo(testCase.TestData.name, []);
testCase.addTeardown(@() pathMemo(testCase.TestData.name, []));
end

function teardown(testCase)
for i = 1:numel(testCase.TestData.dirs)
    d = testCase.TestData.dirs{i};
    if any(strcmp(strsplit(path, pathsep), d)); rmpath(d); end
    if isfolder(d); rmdir(d, 's'); end
end
end

% -- fixture --------------------------------------------------------------

function d = provide(testCase, tag)
% Write the sentinel into a fresh folder and put it on the path. Returns the
% folder so a test can rmpath it or shadow it with another.
d = fullfile(tempdir, sprintf('%s_%s', testCase.TestData.name, tag));
if ~isfolder(d); mkdir(d); end
f = fullfile(d, [testCase.TestData.name '.m']);
fid = fopen(f, 'w');
fprintf(fid, 'function out = %s()\nout = ''%s'';\nend\n', testCase.TestData.name, tag);
fclose(fid);
addpath(d);
rehash;
testCase.TestData.dirs{end+1} = d;
end

function [fcn, countSoFar] = counter()
% Returns the compute function and a reader for how often it ran.
%
% BOTH have to be nested functions sharing this workspace. A struct would be a
% value copy, and `@() n` would be an anonymous handle capturing n BY VALUE at
% construction - frozen at zero however many times bump runs.
n = 0;
fcn        = @bump;
countSoFar = @readCount;
    function v = bump()
        n = n + 1;
        v = n;
    end
    function v = readCount()
        v = n;
    end
end

% -- tests ----------------------------------------------------------------

function test_computesWhenTheSentinelDoesNotResolveYet(testCase)
% The normal cold start: the thing is not on the path, which is exactly why
% computeFcn is being asked to put it there.
name = testCase.TestData.name;
testCase.assertEmpty(which(name), 'the probe name must start unused');

hits = 0;
[v, refreshed] = pathMemo(name, @() bumpAndProvide());
testCase.verifyEqual(v, 1);
testCase.verifyTrue(refreshed);
testCase.verifyEqual(hits, 1);

    function out = bumpAndProvide()
        hits = hits + 1;
        provide(testCase, 'first');
        out = hits;
    end
end

function test_asecondCallIsCachedOnceTheSentinelResolves(testCase)
name = testCase.TestData.name;
provide(testCase, 'first');

[fcn, nCalls] = counter();
pathMemo(name, fcn);
[v, refreshed] = pathMemo(name, fcn);

testCase.verifyFalse(refreshed, 'a resolvable sentinel must not recompute');
testCase.verifyEqual(v, 1, 'the cached value should come back unchanged');
testCase.verifyEqual(nCalls(), 1);
end

function test_theCacheIsDroppedWhenTheSentinelStopsResolving(testCase)
% restoredefaultpath / hideFromPath / rmpath. This is the shape that bit
% ensureEeglabReady and, before it, ensureAaratepOnPath.
name = testCase.TestData.name;
d = provide(testCase, 'first');

[fcn, nCalls] = counter();
pathMemo(name, fcn);
rmpath(d); rehash;
testCase.assertEmpty(which(name));

[~, refreshed] = pathMemo(name, fcn);
testCase.verifyTrue(refreshed, 'a vanished sentinel must invalidate the memo');
testCase.verifyEqual(nCalls(), 2);
end

function test_theCacheIsDroppedWhenTheSentinelMovesInstall(testCase)
% The case NONE of the three hand-rolled caches caught: the function still
% resolves, but to a different file - a swapped EEGLAB, a second TESA. An
% exist(...)==2 check cannot see this; which() can.
name = testCase.TestData.name;
provide(testCase, 'first');

[fcn, nCalls] = counter();
pathMemo(name, fcn);
before = which(name);

second = provide(testCase, 'second');   % addpath prepends, so this shadows
rehash;
testCase.assumeNotEqual(which(name), before, ...
    'the second copy did not take precedence; nothing to test');
testCase.assertEqual(fileparts(which(name)), second);

[~, refreshed] = pathMemo(name, fcn);
testCase.verifyTrue(refreshed, ...
    'a sentinel resolving somewhere new means a different install');
testCase.verifyEqual(nCalls(), 2);
end

function test_resetDropsOneEntryAndLeavesTheOthers(testCase)
% Per-sentinel reset is what lets one test invalidate one toolchain without
% disturbing another's - `clear pathMemo` would drop all of them.
name  = testCase.TestData.name;
other = 'pathMemo';                     % always resolves; a stand-in neighbour
provide(testCase, 'first');

[fcnA, nCallsA] = counter();
[fcnB, nCallsB] = counter();
pathMemo(name,  fcnA);
pathMemo(other, fcnB);

pathMemo(name, []);

pathMemo(name,  fcnA);
pathMemo(other, fcnB);

testCase.verifyEqual(nCallsA(), 2, 'the reset entry should recompute');
testCase.verifyEqual(nCallsB(), 1, 'an untouched entry must survive');

pathMemo(other, []);
end

function test_aFailedComputeIsRetriedNotRemembered(testCase)
% When computeFcn cannot put the sentinel on the path, the answer must not be
% cached - otherwise "install it and try again" needs a MATLAB restart.
name = testCase.TestData.name;
[fcn, nCalls] = counter();

pathMemo(name, fcn);
testCase.assertEmpty(which(name), 'the compute must not have provided it');

[~, refreshed] = pathMemo(name, fcn);
testCase.verifyTrue(refreshed);
testCase.verifyEqual(nCalls(), 2, 'a miss must be retried, not cached');
end
