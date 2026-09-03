% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function d = goldenDir()
% GOLDENDIR  Where the step characterization goldens live.
%   d = GOLDENDIR()
%
%   ONE definition, for the same reason goldenFileStem is one: the recorder
%   writes these files and the checker reads them, and if the two ever disagree
%   about WHERE, every golden looks missing at once and the obvious next move
%   is to re-record - which discards the only protection the step layer has.
%
%   goldenFileStem already removed that risk for the file NAME. The cutover
%   moved this folder out of the legacy characterization/ tree, which is
%   exactly the event that would have exposed the same risk for the PATH, so
%   it gets the same treatment rather than two callers each composing it.
%
%   See also: goldenFileStem, recordGoldens, StepGoldenTest

d = fullfile(addNestappPath(), 'tests', 'golden');
end
