% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function startEeglab(testCase)
% STARTEEGLAB  Bring an EEGLAB session up for a test class, headless.
%   STARTEEGLAB(testCase)
%
%   Call from TestClassSetup. run_tests has already established that EEGLAB is
%   on the path - this is the session itself, which the step layer needs
%   because processOneFile reads and writes the EEGLAB globals rather than
%   passing an EEG struct around.
%
%   THE GLOBALS ARE THE POINT, and they are why this is shared. The two eeglab/
%   classes had each written their own startup: one declared all four globals
%   and took eeglab's return values into them, the other just called
%   eeglab('nogui') and relied on it to populate them as a side effect. Both
%   work today, so nothing would have caught them drifting apart - which is
%   exactly the shape of the old suite's three name-and-signature collisions
%   (fakeEEG twice, makeEEG twice, makeSyntheticEEG twice), where one fact had
%   several private spellings and no single place to correct.
%
%   The explicit assignment is the version kept: relying on a side effect means
%   a future EEGLAB that returns them without setting them breaks the suite in
%   a way that looks like a nestapp bug.
%
%   The assert is here rather than at the call sites because a session that
%   came up without pop_saveset is not a test failure in whatever ran first -
%   it is this function not having done its job.
%
%   See also: saveFixtureSet, addNestappPath, run_tests

global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>
evalc('[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab(''nogui'');');

testCase.assertNotEmpty(which('pop_saveset'), ...
    'EEGLAB came up but pop_saveset does not resolve - the session is unusable');
end
