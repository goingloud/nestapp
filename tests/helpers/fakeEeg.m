% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function EEG = fakeEeg(varargin)
% FAKEEEG  A minimal, deterministic EEG struct for tests that do not need EEGLAB.
%   EEG = FAKEEEG()
%   EEG = FAKEEEG('nbchan', 8, 'pnts', 500, 'trials', 4, 'srate', 1000, ...)
%
%   Name-value options, all with defaults:
%     nbchan  8        channels
%     pnts    500      samples per trial
%     trials  1        1 gives continuous-shaped data (2-D), >1 gives epochs
%     srate   1000     Hz
%     labels  {}       channel labels; default E1..En
%     xmin   -0.1      epoch start, seconds
%     events  0        number of evenly spaced 'TMS' events to insert
%
%   Deterministic: seeded with rng(42) and restored afterwards, so a test that
%   compares two fixtures gets the same numbers and a test that runs after this
%   one does not inherit a reseeded generator.
%
%   WHY THIS EXISTS. The suite this replaced contained ELEVEN local fake-EEG
%   builders, including three exact name-and-signature collisions - fakeEEG
%   twice, makeEEG twice, makeSyntheticEEG twice - in files that could not see
%   each other. Meanwhile tests/helpers/charFixture.m, a good seeded fixture,
%   had zero callers anywhere in tests/unit. The duplication was not a failure
%   of intent; it was that finding the helper cost more than writing four lines.
%
%   WHEN NOT TO USE THIS. If the test needs realistic signal - drift, alpha,
%   line noise, a post-pulse transient - or is comparing against a recorded
%   golden, use charFixture(kind) instead. That one exists to be REALISTIC;
%   this one exists to be SMALL and to need no EEGLAB. Keeping the two apart is
%   what stops either from growing into the other, which is how eleven builders
%   happened.
%
%   See also: charFixture, fakeGroupResult, NestappTestCase

o = parse(varargin);

prev = rng(42, 'twister');
restore = onCleanup(@() rng(prev));

EEG = struct();
EEG.setname  = 'fakeEeg';
EEG.filename = '';
EEG.filepath = '';
EEG.nbchan   = o.nbchan;
EEG.pnts     = o.pnts;
EEG.trials   = o.trials;
EEG.srate    = o.srate;
EEG.xmin     = o.xmin;
EEG.xmax     = o.xmin + (o.pnts - 1) / o.srate;
EEG.times    = linspace(EEG.xmin, EEG.xmax, o.pnts) * 1000;   % ms, as EEGLAB
EEG.data     = single(randn(o.nbchan, o.pnts, o.trials));
if o.trials == 1
    EEG.data = EEG.data(:, :, 1);   % 2-D, the shape continuous data really has
end

labels = o.labels;
if isempty(labels)
    labels = arrayfun(@(k) sprintf('E%d', k), 1:o.nbchan, 'UniformOutput', false);
end
EEG.chanlocs = struct('labels', labels(:)');

EEG.event = struct('type', {}, 'latency', {});
for k = 1:o.events
    EEG.event(k).type    = 'TMS';
    EEG.event(k).latency = round(k * o.pnts / (o.events + 1));
end

EEG.icaweights = [];
EEG.icasphere  = [];
EEG.icawinv    = [];
EEG.etc        = struct();
EEG.history    = '';
end

function o = parse(args)
o = struct('nbchan', 8, 'pnts', 500, 'trials', 1, 'srate', 1000, ...
           'labels', {{}}, 'xmin', -0.1, 'events', 0);
if mod(numel(args), 2) ~= 0
    error('nestapp:fakeEeg:oddArgs', 'Name-value arguments must come in pairs.');
end
for i = 1:2:numel(args)
    key = lower(char(args{i}));
    if ~isfield(o, key)
        error('nestapp:fakeEeg:unknownOpt', 'Unknown option "%s".', args{i});
    end
    o.(key) = args{i+1};
end
end
