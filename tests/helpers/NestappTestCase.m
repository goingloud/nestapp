% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef (Abstract) NestappTestCase < matlab.unittest.TestCase
% NESTAPPTESTCASE  Base class for every nestapp test. Handles the path; nothing else.
%
%   classdef MyThingTest < NestappTestCase
%       methods (Test)
%           function itDoesTheThing(tc)
%               tc.verifyEqual(myThing(2), 4);
%           end
%       end
%   end
%
%   That is a complete test file. There is no setup to write, which is the
%   entire point.
%
%   WHY THIS EXISTS. The suite this replaced contained 50 verbatim copies of a
%   local repoRoot() helper and 85 hand-written setupOnce blocks, all doing the
%   same two addpath calls - and they had drifted, with 49 files using a
%   non-recursive addpath(src) and 56 using genpath, so whether src/qa and
%   src/io were reachable depended on which file you happened to run. Twelve
%   tests then hid that by opening with assumeNotEmpty(which(<a function in
%   this very repo>)), which converts a path bug into a silently skipped test.
%
%   None of that happened because anyone thought duplication was good. It
%   happened because writing the boilerplate was easier than finding the
%   helper. So the boilerplate is gone rather than merely discouraged: inherit
%   and there is nothing left to copy.
%
%   DELIBERATELY MINIMAL. This class sets up the path and stops. It is not a
%   place to hang fixtures, assertion sugar or shared state - those are free
%   functions in tests/helpers, callable from anywhere and testable on their
%   own. A base class that accumulates helpers becomes a god-object that every
%   test drags in and nobody can change, which is the same failure as the
%   duplication, arriving from the other direction.
%
%   WHAT DOES NOT BELONG HERE. EEGLAB. Whether a test needs it is declared by
%   which folder the test lives in (tests/pure vs tests/eeglab), and a base
%   class that quietly initialised EEGLAB would make every pure test pass for
%   the wrong reason - and would reintroduce the leak that had one unit test
%   calling eeglab('nogui') with no teardown, polluting the path for every
%   test that ran after it.
%
%   ONE THING IT DOES ENFORCE: no test may leak a graphics object. That is a
%   runtime check rather than another source rule, and deliberately so - the
%   source scan in SuiteHygieneTest can only see a figure opened by the test
%   file ITSELF, and is blind to one opened two call frames down inside a src/
%   helper. This catches it however it was produced, and applies to every
%   folder: a gui test may open windows, it just has to close them.
%
%   findall, not findobj: findobj skips HandleVisibility 'off', which is most
%   of what the app creates, and a leak check that cannot see the leak is
%   worse than none.
%
%   See also: addNestappPath, scratchDir, run_tests

    properties (Access = private)
        FiguresBefore double
    end

    methods (TestClassSetup)
        function nestappIsOnThePath(~)
        % Once per class, and idempotent - addNestappPath derives "already
        % done" from the path itself rather than caching it, so a test that
        % calls restoredefaultpath does not break every class after it.
            addNestappPath();
        end
    end

    methods (TestMethodSetup)
        function countGraphicsBefore(tc)
            tc.FiguresBefore = numel(findall(0, 'Type', 'figure'));
        end
    end

    methods (TestMethodTeardown)
        function noGraphicsAreLeaked(tc)
        % Runs AFTER the test's own addTeardown callbacks (verified: MATLAB
        % orders addTeardown before TestMethodTeardown), so a test that cleans
        % up properly is not reported.
            leaked = numel(findall(0, 'Type', 'figure')) - tc.FiguresBefore;
            tc.verifyEqual(leaked, 0, sprintf( ...
                ['%d figure(s) left open. Close what the test opens - ' ...
                 'testCase.addTeardown(@() delete(fig)) - or the next test ' ...
                 'inherits them.'], leaked));
        end
    end
end
