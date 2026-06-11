
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function names = channelRejectionSteps()
% CHANNELREJECTIONSTEPS  Steps whose drop in channel count is a REJECTION.
%   names = CHANNELREJECTIONSTEPS() returns the pipeline step names for which
%   processOneFile counts a fall in EEG.nbchan as rejected channels (added to
%   report.channels.nRejected, which drives the session summary and the
%   Quality Gate maxRejectedChanPct check).
%
%   A step belongs here when it removes channels for cleaning / bad-channel
%   reasons. "Remove Bad Channels (ARTIST)" pop_select-removes its RANSAC bad
%   channels exactly like "Remove Bad Channels", so it must be counted the
%   same - otherwise the ARTIST pipeline under-reports rejected channels.

names = {'Remove Bad Channels', ...
         'Remove Bad Channels (ARTIST)', ...
         'Remove un-needed Channels', ...
         'Automatic Cleaning Data', ...
         'Clean Artifacts', ...
         'Automatic Continuous Rejection'};
end
