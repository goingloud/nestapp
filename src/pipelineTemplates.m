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
%   Overrides are applied with ovSet() rather than by hardcoded step index.
%   This means adding or removing a step from a template never silently
%   mis-applies a parameter to the wrong step.
%
%   Pipeline designs follow published best practices:
%     TMS-EEG  — Rogasch et al. 2017 (NeuroImage), TESA toolbox documentation
%     Resting  — Bigdely-Shamlo et al. 2015 (PREP), Delorme 2023 (Sci Rep)
%     Minimal  — Delorme 2023 (Sci Rep, doi:10.1038/s41598-023-27528-0)
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
ov = blankOverrides(t.steps);
% Cubic interpolation of TMS window (TESA paper recommends cubic; default
% linear is less accurate at the artifact boundary).
ov = ovSet(ov, t.steps, 'Interpolate Missing Data (TESA)', 'interpolation', 'cubic');
% Epoch window: [-1 1] s captures N15–P180 and provides 1 s pre-stim baseline.
ov = ovSet(ov, t.steps, 'Epoching', 'timelim', [-1, 1]);
% Average re-reference.
ov = ovSet(ov, t.steps, 'Re-Reference', 'ref', '[]');
% Round 2 — activate all artifact detectors (all default to 'off').
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'blink',     'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'move',      'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'muscle',    'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'elecNoise', 'on', 2);
ov = ovSet(ov, t.steps, 'Save New Set', 'savenew', 'tesa');
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
ov = blankOverrides(t.steps);
ov = ovSet(ov, t.steps, 'Frequency Filter', 'locutoff', 0.5);  % HPF at 0.5 Hz
ov = ovSet(ov, t.steps, 'Frequency Filter', 'hicutoff', 40);   % LPF at 40 Hz
% ASR parameters matching Delorme 2023.
ov = ovSet(ov, t.steps, 'Automatic Cleaning Data', 'FlatlineCriterion', 4);
ov = ovSet(ov, t.steps, 'Automatic Cleaning Data', 'ChannelCriterion',  0.85);
ov = ovSet(ov, t.steps, 'Re-Reference', 'ref', '[]');
% ICLabel thresholds: 0.8 is the practical threshold for resting-state; the
% step default of 0.9 is too strict and commonly flags nothing on real data.
% Heart added because cardiac artifacts are frequent in resting-state.
ov = ovSet(ov, t.steps, 'Flag ICA Components for Rejection', 'Muscle', [0.8, 1]);
ov = ovSet(ov, t.steps, 'Flag ICA Components for Rejection', 'Eye',    [0.8, 1]);
ov = ovSet(ov, t.steps, 'Flag ICA Components for Rejection', 'Heart',  [0.9, 1]);
ov = ovSet(ov, t.steps, 'Save New Set', 'savenew', 'resting');
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
ov = blankOverrides(t.steps);
ov = ovSet(ov, t.steps, 'Frequency Filter', 'locutoff', 0.5);  % HPF only
ov = ovSet(ov, t.steps, 'Frequency Filter', 'hicutoff', 0);    % 0 = no LPF
% ASR parameters matching Delorme 2023.
ov = ovSet(ov, t.steps, 'Automatic Cleaning Data', 'FlatlineCriterion', 4);
ov = ovSet(ov, t.steps, 'Automatic Cleaning Data', 'ChannelCriterion',  0.85);
% ICLabel: 0.8 practical threshold; 0.9 default commonly flags nothing.
ov = ovSet(ov, t.steps, 'Flag ICA Components for Rejection', 'Muscle', [0.8, 1]);
ov = ovSet(ov, t.steps, 'Flag ICA Components for Rejection', 'Eye',    [0.8, 1]);
ov = ovSet(ov, t.steps, 'Flag ICA Components for Rejection', 'Heart',  [0.9, 1]);
ov = ovSet(ov, t.steps, 'Save New Set', 'savenew', 'minimal');
t.overrides = ov;
templates(end+1) = t;

%% ---- TMS-EEG / TEP — Conservative ---------------------------------------
% Same 19-step TESA pipeline with thresholds biased toward keeping data:
%   - Higher bad-channel SD threshold rejects only extreme outliers.
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
ov = blankOverrides(t.steps);
ov = ovSet(ov, t.steps, 'Interpolate Missing Data (TESA)', 'interpolation', 'cubic');
ov = ovSet(ov, t.steps, 'Epoching',           'timelim',       [-1, 1]);
% Higher SD threshold — only the worst channels removed.
ov = ovSet(ov, t.steps, 'Remove Bad Channels', 'threshold',    8);
ov = ovSet(ov, t.steps, 'Re-Reference',        'ref',          '[]');
% Round 1 — higher TMS-muscle threshold (fewer components removed).
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'tmsMuscleThresh', 12, 1);
% Round 2 — all detectors on, thresholds raised vs defaults.
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'blink',          'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'move',           'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'muscle',         'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'elecNoise',      'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'blinkThresh',    3.5,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'moveThresh',     3.0,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'muscleThresh',   0.8,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'elecNoiseThresh',6.0,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'tmsMuscleThresh',12,   2);
% High amplitude threshold — only extreme artefact epochs removed.
ov = ovSet(ov, t.steps, 'Remove Bad Epoch', 'threshold', 1500);
ov = ovSet(ov, t.steps, 'Save New Set',     'savenew',   'conservative');
t.overrides = ov;
templates(end+1) = t;

%% ---- TMS-EEG / TEP — Aggressive -----------------------------------------
% Same 19-step TESA pipeline with thresholds biased toward removing artefact:
%   - Lower bad-channel SD threshold flags borderline noisy channels.
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
ov = blankOverrides(t.steps);
ov = ovSet(ov, t.steps, 'Interpolate Missing Data (TESA)', 'interpolation', 'cubic');
ov = ovSet(ov, t.steps, 'Epoching',           'timelim',       [-1, 1]);
% Lower SD threshold — borderline noisy channels removed.
ov = ovSet(ov, t.steps, 'Remove Bad Channels', 'threshold',    3);
ov = ovSet(ov, t.steps, 'Re-Reference',        'ref',          '[]');
% Round 1 — lower TMS-muscle threshold (more components removed).
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'tmsMuscleThresh', 5,   1);
% Round 2 — all detectors on, thresholds lowered vs defaults.
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'blink',          'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'move',           'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'muscle',         'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'elecNoise',      'on', 2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'blinkThresh',    1.5,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'moveThresh',     1.5,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'muscleThresh',   0.4,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'elecNoiseThresh',2.5,  2);
ov = ovSet(ov, t.steps, 'Remove ICA Components (TESA)', 'tmsMuscleThresh',5,    2);
% Low amplitude threshold — contaminated trials discarded aggressively.
ov = ovSet(ov, t.steps, 'Remove Bad Epoch', 'threshold', 500);
ov = ovSet(ov, t.steps, 'Save New Set',     'savenew',   'aggressive');
t.overrides = ov;
templates(end+1) = t;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Local helpers

function t = blankTemplate()
t = struct('name', '', 'steps', {{}}, 'overrides', {{}});
end

function ov = blankOverrides(steps)
ov = repmat({struct()}, 1, numel(steps));
end

function ov = ovSet(ov, steps, stepName, field, value, occurrence)
% OVSET  Set an override field identified by step name, not position.
%
%   ov = ovSet(ov, steps, stepName, field, value)
%   ov = ovSet(ov, steps, stepName, field, value, occurrence)
%
%   occurrence selects which match to use when a step appears more than
%   once (e.g. two ICA rounds).  1 = first (default), 2 = second, etc.
%   Errors loudly if stepName is not found, so mis-spellings are caught
%   immediately rather than silently writing to the wrong step.
    if nargin < 6; occurrence = 1; end
    idx = find(strcmp(steps, stepName));
    if isempty(idx)
        error('pipelineTemplates:badStep', ...
              'Step "%s" not found in template.', stepName);
    end
    if occurrence < 1 || occurrence > numel(idx)
        error('pipelineTemplates:badOccurrence', ...
              'Step "%s" has %d occurrence(s); requested %d.', ...
              stepName, numel(idx), occurrence);
    end
    ov{idx(occurrence)}.(field) = value;
end
