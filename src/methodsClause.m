
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function clause = methodsClause(stepName, params)
% METHODSCLAUSE  One journal-style clause describing a pipeline step.
%   clause = METHODSCLAUSE(stepName, params) returns a single natural-language
%   clause (lower-case start, no trailing period) describing what the step did,
%   carrying only its methods-relevant parameter values - or '' for steps that
%   do not belong in a methods paragraph (data I/O, plotting, quality gates,
%   analysis-only steps).
%
%   The clauses are ordered, de-duplicated and punctuated by the assemblers
%   (methodsNarrative / methodsParagraphAggregate). Only established algorithm
%   names appear (FastICA, infomax, ICLabel, SOUND, RANSAC, clean_rawdata/ASR,
%   CleanLine); nestapp's internal step labels and parameter keys never do.
%
%   See also: methodsNarrative, methodsParagraphAggregate, stepRegistry

    clause = '';
    p = params;
    if ~isstruct(p); p = struct(); end

    switch stepName
        case 'Remove un-needed Channels'
            if (isfield(p,'nochannel') && ~isempty(p.nochannel)) || ...
               (isfield(p,'channel')   && ~isempty(p.channel))
                clause = 'the recording was reduced to the scalp montage';
            end

        case 'Epoching'
            if isfield(p,'timelim') && numel(p.timelim) >= 2
                ev = 'each event';
                if isfield(p,'types') && iscell(p.types) && ~isempty(p.types) ...
                        && any(contains(lower(string(p.types)), 'tms'))
                    ev = 'the TMS pulse';
                end
                clause = sprintf('the data were segmented into epochs from %s ms relative to %s', ...
                    rng2(p.timelim, 1000), ev);
            end

        case 'Remove Baseline'
            tr = getf(p, 'timerange', []);
            if ~isempty(tr) && numel(tr) >= 2
                if tr(2) <= 0
                    clause = sprintf('the data were baseline-corrected from %s ms', rng2(tr));
                else
                    clause = 'the data were demeaned over the whole epoch';
                end
            elseif ~isempty(getf(p, 'pointrange', []))
                clause = 'the data were baseline-corrected over the pre-stimulus interval';
            else
                clause = 'the data were demeaned over the whole epoch';
            end

        case 'Remove TMS Artifacts (TESA)'
            if isfield(p,'cutTimesTMS') && numel(p.cutTimesTMS) >= 2
                clause = sprintf('the TMS pulse and early muscle artifact (%s ms) were removed', ...
                    rng2(p.cutTimesTMS));
            end

        case 'Interpolate Missing Data (TESA)'
            m = getf(p, 'interpolation', 'linear');
            clause = sprintf('the excised window was reconstructed by %s interpolation', m);

        case 'Interpolate Missing Data (AR-Blend)'
            clause = sprintf(['the peri-pulse window (%g to %g ms) was reconstructed by ' ...
                'autoregressive-blended interpolation'], ...
                getf(p,'artifactStartMs',-2), getf(p,'artifactEndMs',12));

        case 'Re-Sample'
            clause = sprintf('the data were downsampled to %g Hz', getf(p,'freq',1000));

        case 'Remove Bad Epoch'
            clause = 'improbable epochs were rejected automatically';

        case 'Reject Bad Trials (ARTIST)'
            clause = sprintf('artifactual trials were rejected by a z-score criterion (%g SD)', ...
                getf(p,'zThreshold',3));

        case 'Remove Bad Channels'
            meas = measureName(getf(p,'measure','kurt'));
            clause = sprintf('bad channels were identified by %s (>%g SD) and removed', ...
                meas, getf(p,'threshold',5));

        case 'Remove Bad Channels (ARTIST)'
            clause = sprintf('bad channels were identified by RANSAC (correlation < %g) and removed', ...
                getf(p,'corrThreshold',0.8));

        case 'Frequency Filter'
            lo = getf(p,'locutoff',0); hi = getf(p,'hicutoff',0);
            if lo > 0 && hi > 0
                clause = sprintf('the data were band-pass filtered from %g to %g Hz', lo, hi);
            elseif lo > 0
                clause = sprintf('the data were high-pass filtered at %g Hz', lo);
            elseif hi > 0
                clause = sprintf('the data were low-pass filtered at %g Hz', hi);
            end

        case 'Frequency Filter (TESA)'
            clause = tesaFilterClause(p);

        case 'Frequency Filter (CleanLine)'
            clause = sprintf('line noise was removed with CleanLine (%s Hz)', ...
                joinHz(getf(p,'linefreqs',[60 120])));

        case 'Automatic Cleaning Data'
            clause = asrClause(p);

        case {'Run ICA', 'Run TESA ICA'}
            clause = sprintf('the data were decomposed into independent components by %s', ...
                icaName(stepName, p));

        case 'Flag ICA Components for Rejection'
            cats = iclabelCategories(p);
            if ~isempty(cats)
                clause = sprintf('components classified by ICLabel as %s were removed', ...
                    listJoin(cats));
            end

        case 'Remove ICA Components (TESA)'
            cats = tesaCompCategories(p);
            if ~isempty(cats)
                clause = sprintf('%s components were removed', listJoin(cats));
            end

        case 'Flag ICA Components (ARTIST Decay)'
            clause = 'components reflecting early TMS-decay artifact were removed';

        case 'Flag ICA Components (AARATEP Muscle)'
            clause = 'residual muscle components identified by the AARATEP classifier were also removed';

        case 'Remove Recording Noise (SOUND)'
            clause = 'sensor noise was suppressed using the SOUND algorithm';

        case 'Remove Decay Artifact'
            per = ''; if strcmpi(getf(p,'perTrial','off'),'on'); per = ' on a per-trial basis'; end
            clause = sprintf('residual TMS-evoked decay was removed%s (%g to %g ms)', ...
                per, getf(p,'artifactStartMs',-2), getf(p,'artifactEndMs',12));

        case 'Interpolate Channels'
            clause = sprintf('removed channels were interpolated (%s)', getf(p,'method','spherical'));

        case 'Re-Reference'
            clause = rerefClause(p);

        % All other steps (Load Data, Load Channel Location, Find TMS Pulses,
        % Save New Set, Quality Gate, Plot*, Extract/Peak TEP, Remove Flagged ICA
        % Components, Label ICA Components, …) contribute no methods sentence.
        otherwise
            clause = '';
    end
end

% ── per-step helpers ──────────────────────────────────────────────────────────

function s = tesaFilterClause(p)
% Butterworth band-pass / band-stop (TESA pop_tesa_filtbutter): 'high' is the
% high-pass edge, 'low' the low-pass edge.
    type = getf(p,'type','bandpass');
    hi = getf(p,'high',1); lo = getf(p,'low',80); ord = ord2(getf(p,'ord',4));
    switch lower(type)
        case 'bandpass'
            s = sprintf('the data were band-pass filtered from %g to %g Hz (%s Butterworth)', hi, lo, ord);
        case 'bandstop'
            s = sprintf('the data were band-stop filtered at %g-%g Hz (%s Butterworth)', hi, lo, ord);
        case 'highpass'
            s = sprintf('the data were high-pass filtered at %g Hz (%s Butterworth)', hi, ord);
        case 'lowpass'
            s = sprintf('the data were low-pass filtered at %g Hz (%s Butterworth)', lo, ord);
        otherwise
            s = '';
    end
end

function s = asrClause(p)
    parts = {};
    fl = getf(p,'FlatlineCriterion',[]);
    if isnumeric(fl) && ~isempty(fl); parts{end+1} = sprintf('flatline %g s', fl); end
    ch = getf(p,'ChannelCriterion',[]);
    if isnumeric(ch) && ~isempty(ch); parts{end+1} = sprintf('channel correlation %g', ch); end
    bu = getf(p,'BurstCriterion',[]);
    if isnumeric(bu) && ~isempty(bu); parts{end+1} = sprintf('burst threshold %g SD', bu); end
    s = 'bad channels and noisy data segments were removed using clean_rawdata/ASR';
    if ~isempty(parts); s = sprintf('%s (%s)', s, strjoin(parts, ', ')); end
end

function name = icaName(stepName, p)
    if strcmp(stepName, 'Run TESA ICA'); name = 'FastICA'; return; end
    switch lower(getf(p,'icatype','fastica'))
        case 'fastica'; name = 'FastICA';
        case 'runica';  name = 'infomax';
        case 'picard';  name = 'Picard';
        case 'binica';  name = 'infomax (binica)';
        otherwise;      name = getf(p,'icatype','independent component analysis');
    end
end

function cats = iclabelCategories(p)
% ICLabel categories the step actually targets (non-[NaN NaN] thresholds).
    cats = {};
    map = {'Eye','eye'; 'Muscle','muscle'; 'Heart','cardiac'; ...
           'LineNoise','line-noise'; 'ChannelNoise','channel-noise'; 'Other','other'};
    for i = 1:size(map,1)
        v = getf(p, map{i,1}, [NaN NaN]);
        if ~all(isnan(v)); cats{end+1} = map{i,2}; end %#ok<AGROW>
    end
    b = getf(p, 'Brain', [NaN NaN]);
    if ~all(isnan(b)); cats{end+1} = 'non-brain'; end
end

function cats = tesaCompCategories(p)
% Enabled TESA compselect detectors → readable artifact names.
    cats = {};
    map = {'tmsMuscle','TMS-evoked muscle'; 'blink','eye-blink'; ...
           'move','eye-movement'; 'muscle','muscle'; 'elecNoise','electrode-noise'};
    for i = 1:size(map,1)
        if strcmpi(getf(p, map{i,1}, 'off'), 'on'); cats{end+1} = map{i,2}; end %#ok<AGROW>
    end
end

function s = rerefClause(p)
    ref = getf(p, 'ref', 'Cz');
    if isempty(ref) || (ischar(ref) && (isempty(strtrim(ref)) || strcmp(strtrim(ref),'[]')))
        s = 'the data were re-referenced to the common average';
    elseif ischar(ref) || isstring(ref)
        s = sprintf('the data were re-referenced to %s', char(ref));
    else
        s = 'the data were re-referenced to the common average';
    end
end

% ── formatting helpers ────────────────────────────────────────────────────────

function v = getf(p, key, dflt)
    if isfield(p, key); v = p.(key); else; v = dflt; end
end

function s = rng2(v, scale)
% Format a [a b] window as "a to b", optionally scaled (e.g. s→ms).
    if nargin < 2; scale = 1; end
    v = double(v(:))' * scale;
    if numel(v) >= 2
        s = sprintf('%g to %g', v(1), v(2));
    elseif ~isempty(v)
        s = sprintf('%g', v(1));
    else
        s = '';
    end
end

function s = ord2(n)
% Small ordinal as a word ("fourth-order").
    words = {'first-order','second-order','third-order','fourth-order', ...
             'fifth-order','sixth-order'};
    n = round(n);
    if n >= 1 && n <= numel(words); s = words{n}; else; s = sprintf('order-%g', n); end
end

function s = measureName(m)
    switch lower(m)
        case 'kurt'; s = 'kurtosis';
        case 'spec'; s = 'spectral power';
        case 'prob'; s = 'probability';
        otherwise;   s = m;
    end
end

function s = joinHz(v)
% "60 and 120" from [60 120].
    v = v(:)';
    s = listJoin(arrayfun(@(x) sprintf('%g', x), v, 'UniformOutput', false));
end

function s = listJoin(c)
% Oxford-comma join of a cellstr: {a} → "a"; {a,b} → "a and b";
% {a,b,c} → "a, b, and c".
    c = c(:)';
    switch numel(c)
        case 0; s = '';
        case 1; s = c{1};
        case 2; s = sprintf('%s and %s', c{1}, c{2});
        otherwise
            s = sprintf('%s, and %s', strjoin(c(1:end-1), ', '), c{end});
    end
end
