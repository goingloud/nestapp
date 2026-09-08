% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function setPath = saveFixtureSet(folder, kind)
% SAVEFIXTURESET  A charFixture saved as a .set, written once per folder.
%   setPath = SAVEFIXTURESET(folder, kind)
%
%   folder  a directory from scratchDir; ITS lifetime is the reuse window
%   kind    a charFixture kind - 'tiny', 'epoched', 'epochedPulses', ...
%
%   A step test needs a file on disk because processOneFile loads one, and
%   pop_saveset costs a few hundred milliseconds. Ten goldens over three
%   distinct kinds were paying for ten saves. Asking for the same kind in the
%   same folder now returns the file already sitting there.
%
%   NO MEMO, DELIBERATELY. The obvious version of this helper caches paths in a
%   persistent, which is wrong twice over: scratchDir registers its teardown at
%   the scope that called it, so a persistent keyed by kind goes stale every
%   time a per-method folder is removed; and a persistent outlives the class
%   that filled it, which is the leaked-memo pattern this rewrite exists to get
%   rid of. The file on disk is already the cache, and isfile is already the
%   lookup - so the CALLER decides the reuse window by choosing where it calls
%   scratchDir. A folder from TestClassSetup shares across the class; one from a
%   Test method shares within that method and no further. Both are correct
%   without this function knowing which it was handed.
%
%   Safe to share: every consumer LOADS this file and works on a copy in the
%   EEGLAB globals. Nothing writes back to it.
%
%   The evalc lives here rather than at each call site so the suppression is in
%   one place - pop_saveset is chatty, and a test that prints a paragraph per
%   fixture buries its own failures.
%
%   See also: charFixture, scratchDir, StepGoldenTest, DispatchContractTest

setPath = fullfile(folder, [kind '.set']);
if isfile(setPath)
    return
end

fx = charFixture(kind);
evalc('pop_saveset(fx, ''filename'', [kind ''.set''], ''filepath'', folder);');
end
