
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function cases = characterizationCases()
% CHARACTERIZATIONCASES  The steps pinned by the characterization suite.
%   cases = CHARACTERIZATIONCASES() returns an N x 4 cell array:
%
%     {stepName, fixtureKind, paramOverrides, prerequisiteSteps}
%
%   Single source of truth for both the recorder and the test, so a case
%   cannot be pinned under one configuration and verified under another.
%
%   Overrides are used only where a shipped default cannot apply to a
%   600-sample fixture (e.g. a detrend window running past the end of the
%   epoch) or where a default targets an event type the fixture does not
%   carry. Everywhere else the shipped defaults are used, so the golden pins
%   the configuration users actually run.
%
%   Prerequisites are real pipeline steps run before the step under test.
%   Several steps are only meaningful after another has prepared the data;
%   running them bare characterises an error path, not the behaviour.
%
%   NOT CHARACTERIZED, and why:
%     Remove Bad Trials    calls pop_rejmenu + uiconfirm and waits for the
%                          user. It cannot run headless - and, more to the
%                          point, it will hang a batch run.
%     Visualize EEG Data   opens a plot window; no data output to pin.
%     Choose Data Set      operates on ALLEEG session state, not on a file.
%     Manual Command       evaluates arbitrary user code; nothing fixed to pin.
%     Clean Artifacts,     ASR / clean_rawdata based. Stochastic in ways that
%     Automatic Cleaning     survive rng seeding (internal RNG use), so a
%     Data, Automatic        golden would flap. Worth revisiting with a
%     Continuous Rejection   tolerance-based comparison rather than exact.
%     SSP SIR              needs a TMS-artifact-bearing montage with real
%                          spatial structure; the synthetic ring montage does
%                          not produce a meaningful projection.
%     Detect Bad Channels  vendored AARATEP detectors; need a lead field and a
%     (PREP/DDWiener)        realistic montage to behave.
%     Modified Bandpass    superseded by the TESA 1.2 step; will be pinned
%     Filter (AARATEP)       when that lands.

cases = {
  'De-Trend Epoch',                    'epoched',       struct(),                              {}
  'TESA De-Trend',                     'epoched',       struct('timeWin', [11 380]),           {}
  'Median Filter 1D',                  'epochedPulses', struct('event_type', 'TMS'),           {}
  'Remove Bad Epoch',                  'epoched',       struct(),                              {}
  'Remove TMS Artifacts (TESA)',       'epochedPulses', struct(),                              {}
  'Interpolate Missing Data (TESA)',   'epochedPulses', struct(),     {'Remove TMS Artifacts (TESA)'}
  'Flag ICA Components (AARATEP Peak)','epochedICA',    struct(),                              {}
  'Extract TEP (TESA)',                'epochedPulses', struct(),                              {}
  'Find TEP Peaks (TESA)',             'epochedPulses', struct(),        {'Extract TEP (TESA)'}
  'TEP Peak Output',                   'epochedPulses', struct('tablePlot','off'), ...
                                        {'Extract TEP (TESA)','Find TEP Peaks (TESA)'}
};
end
