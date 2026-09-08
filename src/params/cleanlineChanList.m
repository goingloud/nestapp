
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function chans = cleanlineChanList(rng, nbchan)
% CLEANLINECHANLIST  Resolve the CleanLine channel range to real indices.
%   chans = CLEANLINECHANLIST(rng, nbchan) turns the step's [first last]
%   channel range into the explicit index vector pop_cleanline expects,
%   clamped to the channels the dataset actually has.
%
%   rng forms:
%     []          -> all channels (1:nbchan), matching upstream's own default
%     [first last]-> first:last, clamped to [1, nbchan]
%     scalar      -> that single channel
%
%   Clamping (not erroring) on an over-range top edge is deliberate: the
%   shipped default [1 64] must mean "all of them" on a 32-channel file and
%   must not abort on a 64-channel file.

if isempty(rng)
    chans = 1:nbchan;
    return;
end

if isscalar(rng)
    chans = rng;
    return;
end

lo = max(1, rng(1));
hi = min(nbchan, rng(end));
chans = lo:hi;
end
