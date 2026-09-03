% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function waitFor(testCase, predicate, what, timeout)
% WAITFOR  Pump the event queue until a predicate holds, then return.
%   WAITFOR(testCase, predicate, what)
%   WAITFOR(testCase, predicate, what, timeout)
%
%   predicate  a function handle returning a logical scalar
%   what       what is being waited for, for the failure message
%   timeout    seconds before giving up (default 5)
%
%   Fails the test if the predicate never holds. Returns as soon as it does,
%   so the common case costs one drawnow rather than the whole timeout.
%
%   A CONDITION, NEVER A SLEEP. A `pause(0.3)` after a resize is a guess about
%   how long a callback takes, and a guess that is right most of the time is a
%   FLAKY test - which is worse than no test, because a suite that cries wolf
%   stops being run, and a suite that stops being run is how the old one
%   reached the state that prompted this rewrite. This was not hypothetical
%   here: the first version of AppStartupTest's resize test used a fixed pause
%   and failed roughly one run in four.
%
%   The same reasoning is already written down in driveModalDialog, which waits
%   on the nestappModalReady appdata flag rather than sleeping. This is that
%   idea with no dialog involved.
%
%   drawnow rather than pause inside the loop: the thing being waited for is
%   almost always a graphics callback, and drawnow is what lets it run.
%
%   See also: driveModalDialog, launchApp

if nargin < 4 || isempty(timeout); timeout = 5; end

t = tic;
while toc(t) < timeout
    drawnow;
    if predicate()
        return
    end
end

testCase.verifyTrue(predicate(), sprintf( ...
    '%s did not happen within %g s', what, timeout));
end
