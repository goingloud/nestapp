
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function EEG = charFixture(kind)
% CHARFIXTURE  Deterministic EEG fixtures for the characterization tests.
%   EEG = CHARFIXTURE(kind) builds a small synthetic dataset. kind is one of:
%
%     'tiny'          8 ch x 100 samples x 4 trials, pulse at t=0 - the
%                     cheapest fixture every step will accept
%     'continuous'    32 ch x 20 s @ 1 kHz, TMS pulse events every 2 s
%     'epoched'       32 ch x 600 samples x 24 trials @ 1 kHz, [-200, 400) ms
%     'epochedPulses' as 'epoched', plus a TMS event at t=0 in every epoch
%     'epochedICA'    as 'epoched', plus a full ICA decomposition
%
%   Every fixture is seeded (rng(42), per the project convention) and built
%   from that seed alone, so the same call always produces bit-identical data.
%   That is the whole point: a golden-value test is worthless if its input
%   drifts, and the existing per-test fixtures use bare randn().
%
%   The signal is deliberately structured rather than pure noise - a slow
%   drift, an alpha oscillation, line noise, and a decaying post-pulse
%   transient - so that steps which filter, detrend, or remove artifacts have
%   something real to act on. A step that does nothing to white noise can look
%   identical to one that works.
%
%   See also: eegDigest, test_stepCharacterization

nChan = 32;
rng(42, 'twister');

switch lower(kind)
    case 'continuous'
        srate = 1000; nSec = 20; nPnts = srate * nSec;
        t = (0:nPnts-1) / srate;
        EEG = baseStruct(nChan, nPnts, 1, srate);
        EEG.data  = synthSignal(nChan, t, srate);
        EEG.xmin  = 0;
        EEG.xmax  = (nPnts-1)/srate;
        EEG.times = t * 1000;
        EEG = addPulses(EEG, srate, 2, nSec);

    case 'epoched'
        srate = 1000; nPnts = 600; nTrial = 24;
        t = (0:nPnts-1) / srate;
        EEG = baseStruct(nChan, nPnts, nTrial, srate);
        d = zeros(nChan, nPnts, nTrial);
        for k = 1:nTrial
            d(:, :, k) = synthSignal(nChan, t, srate) + postPulseDecay(nChan, nPnts, srate);
        end
        EEG.data  = d;
        EEG.xmin  = -0.2;
        EEG.xmax  = 0.399;
        EEG.times = linspace(-200, 399, nPnts);

    case 'tiny'
        % Smallest thing every step will still accept: 8 channels, 100
        % samples, 4 trials, with a pulse event at t=0. For tests that ask
        % "does this run at all" across every step - ICA on 8x400 is a
        % moment's work, on 32x14400 it is not, and a suite slow enough to
        % skip protects nothing.
        srate = 1000; nPnts = 100; nTrial = 4; nCh = 8;
        t = (0:nPnts-1) / srate;
        EEG = baseStruct(nCh, nPnts, nTrial, srate);
        d = zeros(nCh, nPnts, nTrial);
        for k = 1:nTrial
            d(:, :, k) = synthSignal(nCh, t, srate);
        end
        EEG.data  = d;
        EEG.xmin  = -0.02;
        EEG.xmax  = 0.079;
        EEG.times = linspace(-20, 79, nPnts);
        onset = find(EEG.times >= 0, 1);
        for k = 1:nTrial
            EEG.event(k).type     = 'TMS';
            EEG.event(k).latency  = (k-1)*nPnts + onset;
            EEG.event(k).duration = 0;
            EEG.event(k).epoch    = k;
        end
        EEG = eeg_checkset(EEG, 'eventconsistency');

    case 'epochedpulses'
        % Epoched, with a TMS event at t=0 in every epoch. Steps that cut or
        % interpolate the pulse window locate it by event, not by time, so
        % they no-op (or throw) on the plain 'epoched' fixture.
        EEG = charFixture('epoched');
        onset = find(EEG.times >= 0, 1);
        for k = 1:EEG.trials
            EEG.event(k).type     = 'TMS';
            EEG.event(k).latency  = (k-1)*EEG.pnts + onset;
            EEG.event(k).duration = 0;
            EEG.event(k).epoch    = k;
        end
        EEG = eeg_checkset(EEG, 'eventconsistency');

    case 'epochedica'
        EEG = charFixture('epoched');
        % A fixed, well-conditioned mixing matrix - not random - so the
        % decomposition is identical on every run.
        n = EEG.nbchan;
        [q, ~] = qr(magic(n));
        EEG.icaweights  = q;
        EEG.icasphere   = eye(n);
        EEG.icawinv     = inv(q);
        EEG.icachansind = 1:n;
        EEG.icaact      = [];
        EEG.reject.gcompreject = false(1, n);

    otherwise
        error('charFixture:UnknownKind', ...
            ['Unknown fixture kind "%s". Use tiny | continuous | epoched | ' ...
             'epochedPulses | epochedICA.'], kind);
end

EEG = eeg_checkset(EEG);
end

% ── builders ────────────────────────────────────────────────────────────────
function EEG = baseStruct(nChan, nPnts, nTrial, srate)
EEG = struct();
EEG.setname   = 'charFixture';
EEG.filename  = '';
EEG.filepath  = '';
EEG.subject   = '';
EEG.group     = '';
EEG.condition = '';
EEG.session   = [];
EEG.comments  = '';
EEG.ref       = 'common';
EEG.nbchan    = nChan;
EEG.pnts      = nPnts;
EEG.trials    = nTrial;
EEG.srate     = srate;
EEG.event     = struct('type', {}, 'latency', {}, 'duration', {});
EEG.urevent   = struct('type', {}, 'latency', {});
EEG.icaweights = [];
EEG.icasphere  = [];
EEG.icawinv    = [];
EEG.icaact     = [];
EEG.icachansind = [];
EEG.reject    = struct();
EEG.chanlocs  = montage(nChan);
end

function locs = montage(nChan)
% Ring montage on the unit sphere. Real 3-D coordinates matter: several steps
% (RANSAC, SOUND, interpolation) refuse to run or silently degrade without X/Y/Z.
labels = {'Fp1','Fp2','F7','F3','Fz','F4','F8','FC5','FC1','FC2','FC6', ...
          'T7','C3','Cz','C4','T8','CP5','CP1','CP2','CP6','P7','P3','Pz', ...
          'P4','P8','PO3','PO4','O1','Oz','O2','AF3','AF4'};
locs = struct('labels', {}, 'X', {}, 'Y', {}, 'Z', {}, 'theta', {}, 'radius', {});
for c = 1:nChan
    az = 2*pi*(c-1)/nChan;
    el = pi/2 * (0.35 + 0.5*mod(c,3)/3);
    locs(c).labels = labels{c};
    locs(c).X = cos(el)*cos(az);
    locs(c).Y = cos(el)*sin(az);
    locs(c).Z = sin(el);
    locs(c).theta  = az*180/pi;
    locs(c).radius = 0.5;
end
end

function x = synthSignal(nChan, t, srate)
% Slow drift + alpha + line noise + broadband noise, with a per-channel phase
% offset so channels are correlated but not identical (RANSAC and
% interpolation need neighbours that predict each other).
n = numel(t);
x = zeros(nChan, n);
for c = 1:nChan
    ph = 2*pi*c/nChan;
    x(c, :) = 8  * sin(2*pi*0.3*t + ph) ...       % drift
            + 5  * sin(2*pi*10 *t + ph) ...       % alpha
            + 2  * sin(2*pi*60 *t) ...            % line noise
            + 1.5* randn(1, n);                   % broadband
end
x = x * (1 + 0.001*srate/1000);
end

function d = postPulseDecay(nChan, nPnts, srate)
% Exponentially decaying transient just after t=0 (sample 200 in the epoched
% fixture), the artifact shape the TMS-EEG steps exist to remove.
d = zeros(nChan, nPnts);
onset = round(0.2 * srate) + 1;
k = 0:(nPnts - onset);
d(:, onset:end) = repmat(40 * exp(-k / (0.02 * srate)), nChan, 1);
end

function EEG = addPulses(EEG, srate, everySec, nSec)
% TMS pulse events, plus a matching spike in the data so pulse detection has
% something to find.
lat = (everySec:everySec:(nSec-everySec)) * srate;
for k = 1:numel(lat)
    EEG.event(k).type     = 'TMS';
    EEG.event(k).latency  = lat(k);
    EEG.event(k).duration = 0;
    % urevent is left for eeg_checkset to build - populating it by hand trips
    % its consistency check and it discards the whole struct with a warning.
    span = lat(k):min(lat(k)+round(0.005*srate), size(EEG.data,2));
    EEG.data(:, span) = EEG.data(:, span) + 300;
end
end
