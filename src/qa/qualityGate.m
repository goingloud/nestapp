
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function gate = qualityGate(EEG, params, context)
% QUALITYGATE  Apply numeric quality thresholds and emit a verdict.
%   gate = QUALITYGATE(EEG, params)
%   gate = QUALITYGATE(EEG, params, context)
%
%   Measures a battery of quality metrics on EEG and compares each to a
%   HARD threshold from the step's params struct. The optional context
%   struct carries the running channel / trial rejection tally from
%   processOneFile (fileReport.channels and fileReport.trials), used by
%   the maxRejected*Pct metrics below.
%
%   Each metric is a plain threshold with an optional warn level:
%     value beyond the threshold        -> Fail
%     value beyond the *WarnAt (if set) -> Marginal
%     otherwise                         -> Pass
%   A threshold of 0 disables that check. A *WarnAt of 0 means "no
%   Marginal band" for that metric (it goes straight Pass -> Fail).
%
%   params fields (all optional except gateLabel, which carries a default):
%     gateLabel              string shown in CSV / report
%     expectedChans          exact-match check on EEG.nbchan
%     expectedSrate          exact-match check on EEG.srate
%     minTriggers            EEG.event count must be >= threshold
%     maxTriggers            EEG.event count must be <= threshold (catches
%                              over-detection of TMS pulses)
%     maxFlatChans           count of var ~ 0 channels must be <= threshold
%     maxSatChans            count of |data| > 250 uV channels must be <= threshold
%     maxGmfaPeak            peak GMFA (std across channels of the TRIAL-MEAN)
%                              within gmfaWindowMs must be <= threshold [uV].
%                              Catches an elevated / blown grand-average TEP.
%     gmfaWindowMs           [lo hi] ms window for maxGmfaPeak (default [20 300]).
%     minRankRatio           rank(EEG.data) / nbchan must be >= threshold
%     maxRejectedChanPct     % of original channels removed by the pipeline
%                              so far must be <= threshold
%                              (needs context.channels.original/.nRejected)
%     maxRejectedTrialPct    % of original trials removed must be <= threshold
%                              (needs context.trials)
%     minTrials              EEG.trials must be >= threshold
%     maxTrials              EEG.trials must be <= threshold (catches
%                              over-segmentation from spurious triggers)
%     maxEMGFraction         ICA classifier emg fraction must be <= threshold
%     maxElectrodeCount      ICA electrode-artifact count must be <= threshold
%     <metric>WarnAt         optional Marginal cutoff for the metric above.
%                              For a max metric set it below the threshold;
%                              for a min metric set it above the threshold.
%
%   Output gate:
%     .label
%     .verdict      'Pass' | 'Marginal' | 'Fail'
%     .reasons      cellstr - one per check that flagged (empty for Pass)
%     .metrics      struct of raw metric values (one field per enabled check)
%     .thresholds   struct mirroring the thresholds that were used (for logs)
%
%   Reuses Phase 1 helpers:
%     computeAttributeMatrix    SM matrix + flat/sat masks + per-axis medians
%     computeICAQualityMetrics  source-aware ICA classification
%
%   See also: computeAttributeMatrix, computeICAQualityMetrics

if nargin < 2 || ~isstruct(params), params = struct(); end
if nargin < 3 || ~isstruct(context), context = struct(); end
params = applyDefaults(params);

gate = struct( ...
    'label',      params.gateLabel, ...
    'verdict',    'Pass', ...
    'reasons',    {{}}, ...
    'metrics',    struct(), ...
    'thresholds', struct());

gate.metrics    = collectMetrics(EEG, params, context);
gate.thresholds = enabledThresholds(params);
[gate.verdict, gate.reasons] = evaluate(gate.metrics, params);
end

% -- metric collection ----------------------------------------------------

function m = collectMetrics(EEG, params, context)
% Compute every metric used by the gate. Cheap operations always run;
% SM-derived metrics only when at least one SM-using check is enabled.

m.nbchan    = getField(EEG, 'nbchan', size(EEG.data, 1));
m.srate     = getField(EEG, 'srate', NaN);
m.nTriggers = numEvents(EEG);
m.nTrials   = getField(EEG, 'trials', max(size(EEG.data, 3), 1));
m.rankRatio = computeRankRatio(EEG);

% Cumulative rejection metrics pulled from the report context. NaN
% when the context is missing or the original count is zero (e.g. a
% trials metric before any Epoching step has run).
m.rejectedChanPct  = rejectionPct(context, 'channels', 'nRejected');
m.rejectedTrialPct = rejectionPct(context, 'trials',   'rejected');

needsSM = anyEnabled(params, {'maxFlatChans','maxSatChans'});
if needsSM
    [~, sm] = computeAttributeMatrix(EEG, ...
        struct('attribute', 'minmax_no_tms'));
    m.nFlatChans = sum(sm.flatChanMask);
    m.nSatChans  = sum(sm.satChanMask);
else
    m.nFlatChans = NaN;
    m.nSatChans  = NaN;
end

needsICA = anyEnabled(params, {'maxEMGFraction','maxElectrodeCount'});
if needsICA
    icaM = computeICAQualityMetrics(EEG);
    if isempty(icaM)
        m.emgFraction   = NaN;
        m.electrodeCount = NaN;
    else
        labels = {icaM.classification};
        m.emgFraction    = ratioOf(labels, {'EMG','Muscle','TMS Muscle'});
        m.electrodeCount = countOf(labels, ...
            {'Electrode','Elec Noise','Channel Noise'});
    end
else
    m.emgFraction    = NaN;
    m.electrodeCount = NaN;
end

% Output-TEP metric: only computed when enabled, and only meaningful on
% epoched data with a time axis (NaN -> check skipped otherwise, e.g. on a
% continuous-data gate).
needsTEP = anyEnabled(params, {'maxGmfaPeak'});
if needsTEP
    m.gmfaPeakUv = tepGmfaPeak(EEG, params.gmfaWindowMs);
else
    m.gmfaPeakUv = NaN;
end

end

function v = tepGmfaPeak(EEG, win)
% Peak GMFA (std across channels of the trial-averaged TEP) within win [ms].
% Trial-averaging first is what makes this blind to a lone monster trial and
% sensitive to a genuinely elevated grand-average response.
v = NaN;
if ndims(EEG.data) ~= 3 || getField(EEG, 'trials', 1) < 2, return, end
if ~isfield(EEG, 'times') || isempty(EEG.times), return, end
idx = EEG.times >= win(1) & EEG.times <= win(2);
if ~any(idx), return, end
trialMean = mean(double(EEG.data), 3);   % channels x time
gmfa      = std(trialMean, 0, 1);        % 1 x time
v         = max(gmfa(idx));
end

% -- evaluation -----------------------------------------------------------

function [verdict, reasons] = evaluate(m, p)
verdict = 'Pass';
reasons = {};

% Exact match checks (no Marginal tier).
if p.expectedChans > 0 && m.nbchan ~= p.expectedChans
    [verdict, reasons] = bump(verdict, reasons, 'Fail', ...
        sprintf('nbchan %d != expected %d', m.nbchan, p.expectedChans));
end
if p.expectedSrate > 0 && abs(m.srate - p.expectedSrate) > eps
    [verdict, reasons] = bump(verdict, reasons, 'Fail', ...
        sprintf('srate %g != expected %g Hz', m.srate, p.expectedSrate));
end

% Min checks: fail if metric < threshold; marginal if threshold <=
% metric < WarnAt (only when WarnAt is set above threshold).
[verdict, reasons] = checkMin(verdict, reasons, m.nTriggers,  p.minTriggers, ...
    p.minTriggersWarnAt,  'triggers');
[verdict, reasons] = checkMin(verdict, reasons, m.rankRatio,  p.minRankRatio, ...
    p.minRankRatioWarnAt, 'rank/nbchan');
[verdict, reasons] = checkMin(verdict, reasons, m.nTrials,    p.minTrials, ...
    p.minTrialsWarnAt,    'trials');

% Max checks: fail if metric > threshold; marginal if metric > WarnAt
% (only when WarnAt is set below threshold).
[verdict, reasons] = checkMax(verdict, reasons, m.nTriggers,        p.maxTriggers, ...
    p.maxTriggersWarnAt,          'triggers');
[verdict, reasons] = checkMax(verdict, reasons, m.nTrials,          p.maxTrials, ...
    p.maxTrialsWarnAt,            'trials');
[verdict, reasons] = checkMax(verdict, reasons, m.nFlatChans,       p.maxFlatChans, ...
    p.maxFlatChansWarnAt,         'flat channels');
[verdict, reasons] = checkMax(verdict, reasons, m.nSatChans,        p.maxSatChans, ...
    p.maxSatChansWarnAt,          'saturated channels');
[verdict, reasons] = checkMax(verdict, reasons, m.gmfaPeakUv,       p.maxGmfaPeak, ...
    p.maxGmfaPeakWarnAt,          'GMFA peak uV');
[verdict, reasons] = checkMax(verdict, reasons, m.rejectedTrialPct, p.maxRejectedTrialPct, ...
    p.maxRejectedTrialPctWarnAt,  '% rejected trials');
[verdict, reasons] = checkMax(verdict, reasons, m.rejectedChanPct,  p.maxRejectedChanPct, ...
    p.maxRejectedChanPctWarnAt,   '% rejected channels');
[verdict, reasons] = checkMax(verdict, reasons, m.emgFraction,      p.maxEMGFraction, ...
    p.maxEMGFractionWarnAt,       'EMG fraction');
[verdict, reasons] = checkMax(verdict, reasons, m.electrodeCount,   p.maxElectrodeCount, ...
    p.maxElectrodeCountWarnAt,    'electrode-artifact comps');
end

function [verdict, reasons] = checkMin(verdict, reasons, value, threshold, warnAt, name)
if threshold <= 0 || isnan(value), return, end
% The marginal band is [threshold, warnAt), used only when WarnAt is set
% above threshold. With WarnAt <= threshold (including the default 0) there
% is no marginal band - any value below threshold fails outright.
if value < threshold
    [verdict, reasons] = bump(verdict, reasons, 'Fail', ...
        sprintf('%s %g < %g', name, value, threshold));
elseif warnAt > threshold && value < warnAt
    [verdict, reasons] = bump(verdict, reasons, 'Marginal', ...
        sprintf('%s %g near min %g', name, value, warnAt));
end
end

function [verdict, reasons] = checkMax(verdict, reasons, value, threshold, warnAt, name)
if threshold <= 0 || isnan(value), return, end
% The marginal band is (warnAt, threshold], used only when WarnAt is set
% (below threshold). With WarnAt of 0 there is no marginal band.
if value > threshold
    [verdict, reasons] = bump(verdict, reasons, 'Fail', ...
        sprintf('%s %g > %g', name, value, threshold));
elseif warnAt > 0 && value > warnAt
    [verdict, reasons] = bump(verdict, reasons, 'Marginal', ...
        sprintf('%s %g near max %g (warn %g)', name, value, threshold, warnAt));
end
end

function [verdict, reasons] = bump(verdict, reasons, newVerdict, reason)
verdict = worstVerdict(verdict, newVerdict);
reasons{end+1} = reason;
end

function v = worstVerdict(a, b)
order = {'Pass', 'Marginal', 'Fail'};
ia = find(strcmp(a, order));
ib = find(strcmp(b, order));
if isempty(ia), ia = 0; end
if isempty(ib), ib = 0; end
v = order{max(ia, ib)};
end

% -- small math helpers ---------------------------------------------------

function pct = rejectionPct(context, groupField, rejField)
% Cumulative rejection percentage pulled from the processOneFile
% context. Returns NaN when context is missing, the group isn't
% populated, or the original count is zero (e.g. trials before any
% Epoching step has run).
pct = NaN;
if ~isfield(context, groupField), return, end
g = context.(groupField);
if ~isstruct(g) || ~isfield(g, 'original') || ~isfield(g, rejField), return, end
orig = g.original;
rej  = g.(rejField);
if isempty(orig) || isempty(rej) || ~isnumeric(orig) || orig <= 0, return, end
pct = 100 * double(rej) / double(orig);
end

function r = computeRankRatio(EEG)
if ~isfield(EEG, 'data') || isempty(EEG.data) || EEG.nbchan == 0
    r = NaN;
    return
end
data2D = reshape(EEG.data, size(EEG.data, 1), []);
% Compute rank at the data's OWN precision. Real pipeline data is single;
% upcasting single->double before rank() turns float32 quantization noise
% into a spurious extra dimension, so every single-precision dataset (e.g.
% average-referenced, which is exactly rank-deficient) reported full rank.
% rank() derives its tolerance from the class of its input, so single input
% gets a single-appropriate tolerance. Only non-float data needs a cast.
if ~isfloat(data2D)
    data2D = double(data2D);
end
r = rank(data2D) / EEG.nbchan;
end

function n = numEvents(EEG)
if isfield(EEG, 'event') && ~isempty(EEG.event)
    n = numel(EEG.event);
else
    n = 0;
end
end

function frac = ratioOf(labels, targets)
hits = false(size(labels));
for k = 1:numel(targets)
    hits = hits | strcmp(labels, targets{k});
end
frac = sum(hits) / numel(labels);
end

function c = countOf(labels, targets)
hits = false(size(labels));
for k = 1:numel(targets)
    hits = hits | strcmp(labels, targets{k});
end
c = sum(hits);
end

% -- param plumbing -------------------------------------------------------

function p = applyDefaults(p)
defs = struct( ...
    'gateLabel',                'gate', ...
    'expectedChans',            0, ...
    'expectedSrate',            0, ...
    'minTriggers',              0, ...
    'maxTriggers',              0, ...
    'maxFlatChans',             0, ...
    'maxSatChans',              0, ...
    'maxGmfaPeak',              0, ...
    'gmfaWindowMs',             [20 300], ...
    'minRankRatio',             0, ...
    'maxRejectedTrialPct',      0, ...
    'maxRejectedChanPct',       0, ...
    'minTrials',                0, ...
    'maxTrials',                0, ...
    'maxEMGFraction',           0, ...
    'maxElectrodeCount',        0, ...
    'minTriggersWarnAt',        0, ...
    'maxTriggersWarnAt',        0, ...
    'maxFlatChansWarnAt',       0, ...
    'maxSatChansWarnAt',        0, ...
    'maxGmfaPeakWarnAt',        0, ...
    'minRankRatioWarnAt',       0, ...
    'maxRejectedTrialPctWarnAt',0, ...
    'maxRejectedChanPctWarnAt', 0, ...
    'minTrialsWarnAt',          0, ...
    'maxTrialsWarnAt',          0, ...
    'maxEMGFractionWarnAt',     0, ...
    'maxElectrodeCountWarnAt',  0);

fns = fieldnames(defs);
for k = 1:numel(fns)
    if ~isfield(p, fns{k}) || isempty(p.(fns{k}))
        p.(fns{k}) = defs.(fns{k});
    end
end
if ischar(p.gateLabel) || isstring(p.gateLabel)
    p.gateLabel = char(p.gateLabel);
end
end

function t = enabledThresholds(p)
% Mirror of the thresholds, kept for log / report readability.
fields = {'expectedChans','expectedSrate','minTriggers','maxTriggers','maxFlatChans', ...
    'maxSatChans','maxGmfaPeak','minRankRatio', ...
    'maxRejectedTrialPct','maxRejectedChanPct', ...
    'minTrials','maxTrials','maxEMGFraction','maxElectrodeCount'};
warnFields = {'minTriggersWarnAt','maxTriggersWarnAt','maxFlatChansWarnAt', ...
    'maxSatChansWarnAt','maxGmfaPeakWarnAt','minRankRatioWarnAt', ...
    'maxRejectedTrialPctWarnAt','maxRejectedChanPctWarnAt', ...
    'minTrialsWarnAt','maxTrialsWarnAt','maxEMGFractionWarnAt','maxElectrodeCountWarnAt'};
t = struct();
for k = 1:numel(fields)
    t.(fields{k}) = p.(fields{k});
end
for k = 1:numel(warnFields)
    if isfield(p, warnFields{k})
        t.(warnFields{k}) = p.(warnFields{k});
    end
end
end

function tf = anyEnabled(p, fields)
tf = false;
for k = 1:numel(fields)
    if isfield(p, fields{k}) && p.(fields{k}) > 0
        tf = true; return
    end
end
end

function v = getField(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
