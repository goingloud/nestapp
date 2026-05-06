function templates = pipelineTemplates()
% PIPELINETEMPLATES  Return all built-in pipeline templates.
%
%   templates = PIPELINETEMPLATES() returns a struct array where each
%   element describes one template:
%
%     .name      - display name (shown in the picker dialog)
%     .steps     - cell array of step label strings; must match stepRegistry
%                  names exactly (and therefore the StepsListBox items)
%     .overrides - cell array of structs, one per step, containing raw
%                  EEGLAB parameter key→value overrides to apply on top of
%                  the step defaults.  Use struct() for no overrides.
%
%   Adding a template: append one block below following the existing
%   pattern and ensure every step name matches an entry in stepRegistry.
%
%   Pipeline designs follow published best practices:
%     TMS-EEG  — Rogasch et al. 2017 (NeuroImage), TESA toolbox documentation
%     Resting  — Bigdely-Shamlo et al. 2015 (PREP), EEGLAB tutorials
%     Minimal  — EEGLAB standard cleaning recommendations
%
%   See also: stepRegistry, nestapp

templates = struct('name', {}, 'steps', {}, 'overrides', {});

%% ---- TMS-EEG / TEP (TESA) -----------------------------------------------
% Two-round ICA pipeline per Rogasch et al. 2017 and the TESA toolbox
% documentation.  Key decisions:
%   - Average re-reference applied after channel interpolation so that all
%     surviving channels contribute equally to the reference (Rogasch 2017).
%   - Two separate FastICA + compselect passes: Round 1 targets TMS-evoked
%     muscle artifact and electrode noise; Round 2 targets blink, eye
%     movement, and residual muscle after the cleaner signal is available.
%   - Baseline correction and bad-epoch rejection come last so that the full
%     artefact-removal chain is complete before any data is discarded.
t = blankTemplate();
t.name = 'TMS-EEG / TEP (TESA)';
t.steps = { ...
    'Load Data', ...
    'Load Channel Location', ...
    'Remove un-needed Channels', ...
    'Find TMS Pulses (TESA)', ...
    'Remove TMS Artifacts (TESA)', ...
    'Interpolate Missing Data (TESA)', ...
    'Re-Sample', ...
    'Frequency Filter (TESA)', ...
    'Epoching', ...
    'Remove Bad Channels', ...
    'Interpolate Channels', ...
    'Re-Reference', ...
    'Run TESA ICA', ...
    'Remove ICA Components (TESA)', ...
    'Run TESA ICA', ...
    'Remove ICA Components (TESA)', ...
    'Remove Baseline', ...
    'Remove Bad Epoch', ...
    'Save New Set'};
ov = repmat({struct()}, 1, numel(t.steps));
% Step 6 — cubic interpolation of removed TMS window (TESA paper recommends
%           cubic; default is linear which is less accurate for the artifact
%           boundary).
ov{6}.interpolation = 'cubic';
% Step 9 — epoch window: [-1, 1] s gives 1 s pre-stim baseline and captures
%           all standard TEP components (N15 through P180) plus the 500-1000 ms
%           post-stim window required by the background-restoration quality metric.
ov{9}.timelim = [-1, 1];
% Step 12 — average re-reference (empty string = average reference in EEGLAB)
ov{12}.ref = '[]';
% Step 16 — Round 2: activate all artifact detectors with default thresholds
%           (detectors default to 'off'; enabling them here makes the template
%           consistent with the middle-of-range validation pipeline).
ov{16}.blink      = 'on';
ov{16}.move       = 'on';
ov{16}.muscle     = 'on';
ov{16}.elecNoise  = 'on';
t.overrides = ov;
templates(end+1) = t;

%% ---- Resting-State EEG --------------------------------------------------
% Continuous-data pipeline per the PREP pipeline (Bigdely-Shamlo 2015) and
% standard EEGLAB recommendations, updated with structural improvements from
% Delorme 2023 (doi:10.1038/s41598-023-27528-0).  Key decisions:
%   - ASR (pop_clean_rawdata) replaces pop_rejchan: removes bad channels AND
%     bad continuous data segments in one pass.
%   - Channel interpolation runs AFTER ICA so the decomposition is not
%     trained on synthetic data.
%   - Average re-reference retained (before ICA) per EEGLAB FAQ and PREP —
%     resting-state differs from Delorme's ERP context here.
%   - LPF at 40 Hz retained — reduces muscle noise entering ICA for
%     typical alpha/beta/theta resting-state analyses.
%   - CleanLine removes line noise via multi-taper decomposition, preserving
%     spectral content better than a notch filter.
%   - Epoching is a downstream analysis step, not part of cleaning.
t = blankTemplate();
t.name = 'Resting-State EEG';
t.steps = { ...
    'Load Data', ...
    'Load Channel Location', ...
    'Remove un-needed Channels', ...
    'Frequency Filter', ...
    'Frequency Filter (CleanLine)', ...
    'Automatic Cleaning Data', ...
    'Re-Reference', ...
    'Run ICA', ...
    'Label ICA Components', ...
    'Flag ICA Components for Rejection', ...
    'Remove Flagged ICA Components', ...
    'Interpolate Channels', ...
    'Save New Set'};
ov = repmat({struct()}, 1, numel(t.steps));
ov{4}.locutoff          = 0.5;   % HPF at 0.5 Hz
ov{4}.hicutoff          = 40;    % LPF at 40 Hz
ov{6}.FlatlineCriterion = 4;     % match Delorme 2023 ASR parameters
ov{6}.ChannelCriterion  = 0.85;
ov{7}.ref               = '[]';  % average reference
ov{13}.savenew          = 'resting';
t.overrides = ov;
templates(end+1) = t;

%% ---- Minimal (Delorme 2023) -----------------------------------------------
% Minimal pipeline based on Delorme 2023 (Sci Rep, "EEG is better left alone",
% doi:10.1038/s41598-023-27528-0).  Key decisions:
%   - HPF at 0.5 Hz only; no LPF (Delorme 2023 omits it — unnecessary and
%     may remove real broadband content before ICA).
%   - ASR (pop_clean_rawdata) removes bad channels AND bad continuous data
%     segments in one pass; pop_rejchan only removes channels.
%   - Channel interpolation runs AFTER ICA so the decomposition is not
%     trained on synthetic data.
%   - No explicit re-reference — omitted per Delorme 2023.
%   - ICA uses FastICA (Delorme used Picard; omitted here to avoid the
%     additional dependency).
t = blankTemplate();
t.name = 'Minimal (Delorme 2023)';
t.steps = { ...
    'Load Data', ...
    'Load Channel Location', ...
    'Remove un-needed Channels', ...
    'Frequency Filter', ...
    'Automatic Cleaning Data', ...
    'Run ICA', ...
    'Label ICA Components', ...
    'Flag ICA Components for Rejection', ...
    'Remove Flagged ICA Components', ...
    'Interpolate Channels', ...
    'Save New Set'};
ov = repmat({struct()}, 1, numel(t.steps));
% Step 4 — HPF only; hicutoff=0 disables the low-pass filter
ov{4}.locutoff          = 0.5;
ov{4}.hicutoff          = 0;
% Step 5 — match Delorme 2023 ASR parameters exactly
ov{5}.FlatlineCriterion = 4;
ov{5}.ChannelCriterion  = 0.85;
% Step 11 — write output file
ov{11}.savenew          = 'minimal';
t.overrides = ov;
templates(end+1) = t;

%% ---- TMS-EEG / TEP — Conservative ---------------------------------------
% Same 19-step TESA pipeline with thresholds biased toward keeping data:
%   - Higher bad-channel SD threshold rejects only extreme outliers.
%   - Fewer ICA components in Round 1 (10) preserves more signal variance.
%   - Higher TMS-muscle threshold in both rounds is less aggressive about
%     flagging borderline early-peak components.
%   - Higher epoch amplitude threshold (1500 µV) keeps more trials.
% Use this variant when data quality is known to be good or when you want
% to establish an upper bound on how much cleaning is beneficial.
t = blankTemplate();
t.name = 'TMS-EEG / TEP — Conservative';
t.steps = { ...
    'Load Data', ...
    'Load Channel Location', ...
    'Remove un-needed Channels', ...
    'Find TMS Pulses (TESA)', ...
    'Remove TMS Artifacts (TESA)', ...
    'Interpolate Missing Data (TESA)', ...
    'Re-Sample', ...
    'Frequency Filter (TESA)', ...
    'Epoching', ...
    'Remove Bad Channels', ...
    'Interpolate Channels', ...
    'Re-Reference', ...
    'Run TESA ICA', ...
    'Remove ICA Components (TESA)', ...
    'Run TESA ICA', ...
    'Remove ICA Components (TESA)', ...
    'Remove Baseline', ...
    'Remove Bad Epoch', ...
    'Save New Set'};
ov = repmat({struct()}, 1, numel(t.steps));
ov{6}.interpolation     = 'cubic';
ov{9}.timelim           = [-1, 1];
% Step 10 — higher SD threshold; only the worst channels removed
ov{10}.threshold        = 8;
ov{12}.ref              = '[]';
% Step 14 — Round 1: higher TMS-muscle threshold (fewer components removed)
ov{14}.tmsMuscleThresh  = 12;
% Step 16 — Round 2: all detectors on, thresholds raised vs defaults
ov{16}.blink            = 'on';
ov{16}.move             = 'on';
ov{16}.muscle           = 'on';
ov{16}.elecNoise        = 'on';
ov{16}.blinkThresh      = 3.5;
ov{16}.moveThresh       = 3.0;
ov{16}.muscleThresh     = 0.8;
ov{16}.elecNoiseThresh  = 6.0;
ov{16}.tmsMuscleThresh  = 12;
% Step 18 — high amplitude threshold: only extreme artefact epochs removed
ov{18}.threshold        = 1500;
% Step 19 — set output suffix so files are saved to disk automatically
ov{19}.savenew          = 'conservative';
t.overrides = ov;
templates(end+1) = t;

%% ---- TMS-EEG / TEP — Aggressive -----------------------------------------
% Same 19-step TESA pipeline with thresholds biased toward removing artefact:
%   - Lower bad-channel SD threshold flags borderline noisy channels.
%   - More ICA components in Round 1 (25) captures subtler artefact sources.
%   - Lower TMS-muscle threshold in both rounds flags more early-peak comps.
%   - Lower epoch amplitude threshold (500 µV) discards more contaminated trials.
% Use this variant to establish a lower bound (over-cleaned) or when the
% recording is known to have heavy artefact contamination.
t = blankTemplate();
t.name = 'TMS-EEG / TEP — Aggressive';
t.steps = { ...
    'Load Data', ...
    'Load Channel Location', ...
    'Remove un-needed Channels', ...
    'Find TMS Pulses (TESA)', ...
    'Remove TMS Artifacts (TESA)', ...
    'Interpolate Missing Data (TESA)', ...
    'Re-Sample', ...
    'Frequency Filter (TESA)', ...
    'Epoching', ...
    'Remove Bad Channels', ...
    'Interpolate Channels', ...
    'Re-Reference', ...
    'Run TESA ICA', ...
    'Remove ICA Components (TESA)', ...
    'Run TESA ICA', ...
    'Remove ICA Components (TESA)', ...
    'Remove Baseline', ...
    'Remove Bad Epoch', ...
    'Save New Set'};
ov = repmat({struct()}, 1, numel(t.steps));
ov{6}.interpolation     = 'cubic';
ov{9}.timelim           = [-1, 1];
% Step 10 — lower SD threshold; borderline noisy channels removed
ov{10}.threshold        = 3;
ov{12}.ref              = '[]';
% Step 14 — Round 1: lower TMS-muscle threshold (more components removed)
ov{14}.tmsMuscleThresh  = 5;
% Step 16 — Round 2: all detectors on, thresholds lowered vs defaults
ov{16}.blink            = 'on';
ov{16}.move             = 'on';
ov{16}.muscle           = 'on';
ov{16}.elecNoise        = 'on';
ov{16}.blinkThresh      = 1.5;
ov{16}.moveThresh       = 1.5;
ov{16}.muscleThresh     = 0.4;
ov{16}.elecNoiseThresh  = 2.5;
ov{16}.tmsMuscleThresh  = 5;
% Step 18 — low amplitude threshold: contaminated trials discarded aggressively
ov{18}.threshold        = 500;
% Step 19 — set output suffix so files are saved to disk automatically
ov{19}.savenew          = 'aggressive';
t.overrides = ov;
templates(end+1) = t;

end

%% ---- helpers ---------------------------------------------------------------

function t = blankTemplate()
t = struct('name', '', 'steps', {{}}, 'overrides', {{}});
end
