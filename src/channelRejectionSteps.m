
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
%   reasons, so that every such step is counted the same way - otherwise a
%   pipeline using one of them under-reports its rejected channels.

names = {'Remove Bad Channels', ...
         'Remove Bad Channels (manual)', ...
         'Interactive Channel Reject (TESA)', ...
         'Detect Bad Channels (TESA)', ...
         'Remove un-needed Channels', ...
         'Automatic Cleaning Data', ...
         'Clean Artifacts', ...
         'Automatic Continuous Rejection'};
end
