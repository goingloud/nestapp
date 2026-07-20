
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function gate = qualityGate(EEG, params, context)
% QUALITYGATE  Apply numeric quality thresholds and emit a verdict.
%   gate = QUALITYGATE(EEG, params)
%   gate = QUALITYGATE(EEG, params, context)
%
%   Measures a battery of quality metrics on EEG and compares each to a
%   threshold from the step's params struct. The optional context
%   struct carries the running channel / trial rejection tally from
%   processOneFile (fileReport.channels and fileReport.trials), used by
%   the maxRejected*Pct metrics below.
%
%   Disabled checks: any threshold equal to 0 is skipped (the metric
%   is still recorded for batch-mode aggregation).
%
%   params fields (all optional except gateLabel / thresholdMode /
%   marginalSlack / outlierSigmas which always carry defaults):
%     gateLabel              string shown in CSV / report
%     thresholdMode          'absolute' | 'batch'
%     marginalSlack          scalar in (0, 1] - default Marginal width
%                            for max checks (slack * threshold)
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
%                              (Single-trial excursions are handled by the
%                              pre-ICA2 amplitude/probability trial rejection,
%                              not here.)
%     gmfaWindowMs           [lo hi] ms window for maxGmfaPeak (default [20 300]).
%     minRankRatio           rank(EEG.data) / nbchan must be >= threshold
%     maxRejectedChanPct     % of original channels removed by the
%                              pipeline so far must be <= threshold
%                              (needs context.channels.original/.nRejected)
%     maxRejectedTrialPct    % of original trials removed must be <=
%                              threshold (needs context.trials)
%     maxOutlierChanPct      % statistical-outlier channels in current
%                              EEG (SM median > N*MAD above batch
%                              median) must be <= threshold. Useful
%                              BEFORE cleaning; near-zero after.
%     maxOutlierTrialPct     same idea for trials
%     minTrials              EEG.trials must be >= threshold
%     maxTrials              EEG.trials must be <= threshold (catches
%                              over-segmentation from spurious triggers)
%     maxEMGFraction         ICA classifier emg fraction must be <= threshold
%     maxElectrodeCount      ICA electrode-artifact count must be <= threshold
%     outlierSigmas          scalar - N for the median + N * 1.4826 *
%                              MAD rule (drives maxOutlier*Pct and
%                              cross-file batch-mode outlier detection)
%
%   Deprecated aliases (still honored, silently mapped):
%     maxBadChanPct  -> maxOutlierChanPct
%     maxBadTrialPct -> maxOutlierTrialPct
%     (plus the *WarnAt siblings). Their old name described the
%     outlier behavior poorly. The maxRejected* metrics are the ones
%     most users actually want for post-cleanup gates.
%
%   Output gate:
%     .label, .mode
%     .verdict      'Pass' | 'Marginal' | 'Fail' | 'Pending'
%                     ('Pending' in batch mode; resolved by
%                      finalizeBatchVerdicts after the run completes)
%     .reasons      cellstr - one per check that flagged (empty for Pass)
%     .metrics      struct of raw metric values (one field per enabled
%                     check, used by batch-mode finalization)
%     .thresholds   struct mirroring the absolute thresholds that were
%                     used (for log readability and batch fallback)
%
%   Reuses Phase 1 helpers:
%     computeAttributeMatrix    SM matrix + flat/sat masks + per-axis medians
%     computeICAQualityMetrics  source-aware ICA classification
%
%   See also: finalizeBatchVerdicts, computeAttributeMatrix,
%             computeICAQualityMetrics

if nargin < 2 || ~isstruct(params), params = struct(); end
if nargin < 3 || ~isstruct(context), context = struct(); end
params = applyDefaults(params);

gate = struct( ...
    'label',      params.gateLabel, ...
    'mode',       params.thresholdMode, ...
    'verdict',    'Pass', ...
    'reasons',    {{}}, ...
    'metrics',    struct(), ...
    'thresholds', struct());

gate.metrics    = collectMetrics(EEG, params, context);
gate.thresholds = enabledThresholds(params);

if strcmpi(params.thresholdMode, 'batch')
    gate.verdict = 'Pending';
    return
end

[gate.verdict, gate.reasons] = evaluateAbsolute(gate.metrics, params);
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

needsSM = anyEnabled(params, {'maxFlatChans','maxSatChans', ...
    'maxOutlierTrialPct','maxOutlierChanPct'});
if needsSM
    [SM, sm] = computeAttributeMatrix(EEG, ...
        struct('attribute', 'minmax_no_tms'));
    m.nFlatChans       = sum(sm.flatChanMask);
    m.nSatChans        = sum(sm.satChanMask);
    m.pctOutlierTrials = pctOutliers(sm.perTrialMedian, params.outlierSigmas);
    skipMask = sm.flatChanMask | sm.satChanMask;
    chanScores = sm.perChanMedian;
    chanScores(skipMask) = NaN;     % exclude already-flagged channels
    m.pctOutlierChans  = pctOutliers(chanScores, params.outlierSigmas);
    m.smShape          = size(SM);  % stored for batch-mode diagnostics
else
    m.nFlatChans       = NaN;
    m.nSatChans        = NaN;
    m.pctOutlierTrials = NaN;
    m.pctOutlierChans  = NaN;
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

% Output-TEP metrics: only computed when a TEP check is enabled, and only
% meaningful on epoched data with a time axis (NaN -> check skipped otherwise,
% e.g. on a continuous-data gate).
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

% -- absolute-mode evaluation ---------------------------------------------

function [verdict, reasons] = evaluateAbsolute(m, p)
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
% metric < warn cutoff. Warn cutoff = warnAt if set, else threshold /
% slack (symmetric with the max-check default).
[verdict, reasons] = checkMin(verdict, reasons, m.nTriggers,  p.minTriggers, ...
    p.marginalSlack, p.minTriggersWarnAt,  'triggers');
[verdict, reasons] = checkMin(verdict, reasons, m.rankRatio,  p.minRankRatio, ...
    p.marginalSlack, p.minRankRatioWarnAt, 'rank/nbchan');
[verdict, reasons] = checkMin(verdict, reasons, m.nTrials,    p.minTrials, ...
    p.marginalSlack, p.minTrialsWarnAt,    'trials');

% Max checks: fail if metric > threshold; marginal if metric above the
% warn cutoff. Warn cutoff = warnAt if set, else slack * threshold.
[verdict, reasons] = checkMax(verdict, reasons, m.nTriggers,        p.maxTriggers, ...
    p.marginalSlack, p.maxTriggersWarnAt,          'triggers');
[verdict, reasons] = checkMax(verdict, reasons, m.nTrials,          p.maxTrials, ...
    p.marginalSlack, p.maxTrialsWarnAt,            'trials');
[verdict, reasons] = checkMax(verdict, reasons, m.nFlatChans,       p.maxFlatChans, ...
    p.marginalSlack, p.maxFlatChansWarnAt,         'flat channels');
[verdict, reasons] = checkMax(verdict, reasons, m.nSatChans,        p.maxSatChans, ...
    p.marginalSlack, p.maxSatChansWarnAt,          'saturated channels');
[verdict, reasons] = checkMax(verdict, reasons, m.gmfaPeakUv,       p.maxGmfaPeak, ...
    p.marginalSlack, p.maxGmfaPeakWarnAt,          'GMFA peak uV');
[verdict, reasons] = checkMax(verdict, reasons, m.rejectedTrialPct, p.maxRejectedTrialPct, ...
    p.marginalSlack, p.maxRejectedTrialPctWarnAt,  '% rejected trials');
[verdict, reasons] = checkMax(verdict, reasons, m.rejectedChanPct,  p.maxRejectedChanPct, ...
    p.marginalSlack, p.maxRejectedChanPctWarnAt,   '% rejected channels');
[verdict, reasons] = checkMax(verdict, reasons, m.pctOutlierTrials, p.maxOutlierTrialPct, ...
    p.marginalSlack, p.maxOutlierTrialPctWarnAt,   '% outlier trials');
[verdict, reasons] = checkMax(verdict, reasons, m.pctOutlierChans,  p.maxOutlierChanPct, ...
    p.marginalSlack, p.maxOutlierChanPctWarnAt,    '% outlier channels');
[verdict, reasons] = checkMax(verdict, reasons, m.emgFraction,      p.maxEMGFraction, ...
    p.marginalSlack, p.maxEMGFractionWarnAt,       'EMG fraction');
[verdict, reasons] = checkMax(verdict, reasons, m.electrodeCount,   p.maxElectrodeCount, ...
    p.marginalSlack, p.maxElectrodeCountWarnAt,    'electrode-artifact comps');
end

function [verdict, reasons] = checkMin(verdict, reasons, value, threshold, slack, warnAt, name)
% slack is unused for min checks (see comment below) but kept in the
% signature for parity with checkMax.
%#ok<*INUSD>
if threshold <= 0 || isnan(value), return, end
% warnAt sits above threshold for a min check: the marginal band is
% [threshold, warnAt). With warnAt <= threshold (including the default
% of 0) there is no marginal band - any value below threshold fails
% outright. Min metrics like rankRatio are capped at 1.0, so a sensible
% default cannot be derived from slack alone; users opt into the
% marginal band by setting WarnAt above threshold.
warnCutoff = max(warnAt, threshold);
if value < threshold
    [verdict, reasons] = bump(verdict, reasons, 'Fail', ...
        sprintf('%s %g < %g', name, value, threshold));
elseif value < warnCutoff
    [verdict, reasons] = bump(verdict, reasons, 'Marginal', ...
        sprintf('%s %g near min %g', name, value, warnCutoff));
end
end

function [verdict, reasons] = checkMax(verdict, reasons, value, threshold, slack, warnAt, name)
if threshold <= 0 || isnan(value), return, end
warnCutoff = pickCutoff(warnAt, slack * threshold);
if value > threshold
    [verdict, reasons] = bump(verdict, reasons, 'Fail', ...
        sprintf('%s %g > %g', name, value, threshold));
elseif value > warnCutoff
    [verdict, reasons] = bump(verdict, reasons, 'Marginal', ...
        sprintf('%s %g near max %g', name, value, threshold));
end
end

function c = pickCutoff(warnAt, slackCutoff)
% warnAt > 0 overrides the slack-derived boundary; otherwise fall back.
if warnAt > 0
    c = warnAt;
else
    c = slackCutoff;
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

function pct = pctOutliers(values, nSigmas)
% % of finite entries that exceed median + nSigmas * 1.4826 * MAD.
v = values(:);
v = v(~isnan(v));
if isempty(v)
    pct = NaN;
    return
end
med   = median(v);
madV  = median(abs(v - med));
cutoff = med + nSigmas * 1.4826 * madV;
pct    = 100 * sum(v > cutoff) / numel(v);
end

function r = computeRankRatio(EEG)
if ~isfield(EEG, 'data') || isempty(EEG.data) || EEG.nbchan == 0
    r = NaN;
    return
end
data2D = reshape(EEG.data, size(EEG.data, 1), []);
r = rank(double(data2D)) / EEG.nbchan;
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
% Deprecated-key aliasing: see deprecatedGateAliases for the table.
% Saved pipelines using old names still work; a non-zero new value
% wins if both are set.
aliases = deprecatedGateAliases();
for k = 1:size(aliases, 1)
    p = aliasDeprecated(p, aliases{k, 1}, aliases{k, 2});
end

defs = struct( ...
    'gateLabel',                'gate', ...
    'thresholdMode',            'absolute', ...
    'marginalSlack',            0.8, ...
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
    'maxOutlierTrialPct',       0, ...
    'maxOutlierChanPct',        0, ...
    'minTrials',                0, ...
    'maxTrials',                0, ...
    'maxEMGFraction',           0, ...
    'maxElectrodeCount',        0, ...
    'outlierSigmas',            3, ...
    'minTriggersWarnAt',        0, ...
    'maxTriggersWarnAt',        0, ...
    'maxFlatChansWarnAt',       0, ...
    'maxSatChansWarnAt',        0, ...
    'maxGmfaPeakWarnAt',        0, ...
    'minRankRatioWarnAt',       0, ...
    'maxRejectedTrialPctWarnAt',0, ...
    'maxRejectedChanPctWarnAt', 0, ...
    'maxOutlierTrialPctWarnAt', 0, ...
    'maxOutlierChanPctWarnAt',  0, ...
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

function p = aliasDeprecated(p, oldKey, newKey)
% Map an old threshold name onto its new name when set. Silent at the
% per-call level - runPipelineCore emits a one-time deprecation log
% on behalf of the whole spec before the file loop starts.
if isfield(p, oldKey) && ~isempty(p.(oldKey)) && p.(oldKey) ~= 0
    if ~isfield(p, newKey) || isempty(p.(newKey)) || p.(newKey) == 0
        p.(newKey) = p.(oldKey);
    end
end
end

function t = enabledThresholds(p)
% Mirror of params, but only the threshold-bearing fields, kept for log.
fields = {'expectedChans','expectedSrate','minTriggers','maxTriggers','maxFlatChans', ...
    'maxSatChans','maxGmfaPeak','minRankRatio', ...
    'maxRejectedTrialPct','maxRejectedChanPct', ...
    'maxOutlierTrialPct','maxOutlierChanPct', ...
    'minTrials','maxTrials','maxEMGFraction','maxElectrodeCount'};
t = struct();
for k = 1:numel(fields)
    t.(fields{k}) = p.(fields{k});
end
t.marginalSlack = p.marginalSlack;
t.outlierSigmas = p.outlierSigmas;
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
