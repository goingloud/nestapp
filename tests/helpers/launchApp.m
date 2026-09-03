% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function app = launchApp(testCase)
% LAUNCHAPP  Construct nestapp for a GUI test, settled and with its teardown set.
%
%   app = LAUNCHAPP(testCase) creates the app, schedules delete(app) as a
%   teardown on testCase, and does not return until the window has stopped
%   changing shape on its own.
%
%   Worth sharing not for the lines but because forgetting the teardown leaves
%   an app window on screen for the rest of the run, which is how a UI suite
%   ends up unusable.
%
%   SETTLING, NOT ONE drawnow. This function always claimed to return a
%   realised window, and a single drawnow does not deliver that: for the first
%   tens of milliseconds after startupFcn the figure still adjusts its own
%   Position, and a Position written by a test during that window is silently
%   discarded. Measured directly - a resize applied immediately after launch
%   was reverted, with the figure back at its construction geometry, in 4 runs
%   out of 8. A test built on that reads the ORIGINAL position and concludes
%   whatever the original position happens to imply.
%
%   That is the mechanism behind the "GUI tests are flaky, just add a pause"
%   folklore. The fix is a condition, not a longer sleep: poll until two
%   consecutive reads agree, which costs ~70 ms here and is bounded by a
%   timeout rather than by a guess.
%
%   A CAUTION FOR CALLERS, learned the same way: when waiting for something to
%   happen to this window afterwards, make the predicate FALSE in the state you
%   start from. Waiting for "the window is at least the minimum size" is
%   already true of a freshly launched app, so it waits for nothing and reads
%   back the starting geometry - which is exactly the flake this settle fixes,
%   reintroduced one line later.
%
%   See also: waitFor, assumeDesktop, driveModalDialog

app = nestapp;
testCase.addTeardown(@() delete(app));

TIMEOUT = 5;
last = [];
t = tic;
while toc(t) < TIMEOUT
    drawnow;
    pos = app.UIFigure.Position;
    if isequal(pos, last)
        return
    end
    last = pos;
end

testCase.assertFail(sprintf( ...
    ['the app window was still moving after %g s, so nothing written to its ' ...
     'geometry can be relied on'], TIMEOUT));
end
