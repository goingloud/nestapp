% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function plots = plotRegistry()
% PLOTREGISTRY  Metadata for every plot the Explore workspace can draw.
%
%   plots = PLOTREGISTRY() returns a 1-by-N struct array. Each element:
%     .name      unique display name, and the key a saved session stores
%     .category  taxonomy heading ('Waveform', 'Topography', 'Quantification')
%     .info      one-paragraph description for the Info panel
%     .draw      name of the drawing function, as a char. Resolved with
%                str2func at draw time rather than stored as a handle, so the
%                registry stays plain data: it can be saved into a session
%                file, compared in a test, and checked for existence the way
%                stepAvailability checks a plugin function.
%     .mode      curve mode passed to groupCurves ('TEP'|'GMFP'|'LMFP'), or ''
%                for plots that do not reduce to a single ROI curve
%     .requires  what must be true before this can render:
%                  .groups   'any' (>=1) | 1 | 2 | '2+'
%                  .windows  true when windows of interest are needed
%                  .chanlocs true when electrode positions are needed
%     .params    makeParam metadata, one per setting the plot accepts. Each
%                key is EXACTLY an option name of the draw function, so the
%                edited values are handed straight to it with no translation
%                table to keep in step.
%
%   This mirrors stepRegistry / stepTaxonomy / stepAvailability / availableSteps
%   deliberately. The app already solved "an extensible catalogue of named
%   things, grouped for a picker, each declaring what it needs and greyed out
%   with a reason when it cannot run" - for pipeline steps. Plot types are the
%   same problem, and a second, different mechanism for them would mean two
%   places to add a feature and two ways for the UI to explain itself.
%
%   It also absorbs the old Plot Type radio buttons: TEP, GMFP and LMFP are
%   entries here, not a separate selector, so there is one catalogue rather
%   than a radio group plus a view switcher that have to agree.
%
%   Parameter DEFAULTS are deliberately not stored here. The draw function
%   already declares them in its own fillDefaults call, and a second copy in
%   the registry would be a second thing to keep true. What is stored is a
%   placeholder NAMING the default - '(on)', '(-50 300)' - so the table reads
%   as "leave this alone and you get this" while the value itself stays in one
%   place. Only params the user actually sets are passed to the draw function.
%
%   To add a plot: append one block below, add it to plotTaxonomy, and write
%   the draw function. Nothing in the tab needs to change.
%
%   See also: plotTaxonomy, plotAvailability, availablePlots, groupCurves

persistent cached
if ~isempty(cached)
    plots = cached;
    return
end

plots = struct('name', {}, 'category', {}, 'info', {}, 'draw', {}, ...
               'mode', {}, 'requires', {}, 'params', {});

%% ---- Waveform --------------------------------------------------------
p = blankPlot();
p.name     = 'TEP (ROI mean)';
p.category = 'Waveform';
p.mode     = 'TEP';
p.draw     = 'drawTEPOverlay';
p.info     = ['The signed TEP waveform: the mean across the ROI electrodes ' ...
              'of the trial-averaged data, one curve per group with a ' ...
              'confidence band. The default view, and the one the windows of ' ...
              'interest are measured on.'];
p.params   = waveformParams();
plots(end+1) = p;

p = blankPlot();
p.name     = 'GMFP (all channels)';
p.category = 'Waveform';
p.mode     = 'GMFP';
p.draw     = 'drawTEPOverlay';
p.info     = ['Global mean field power: the standard deviation across ALL ' ...
              'electrodes at each timepoint, computed on the trial average. ' ...
              'Identical to TESA''s GMFA. Being a spread rather than a ' ...
              'signed mean, it is always positive and ignores the ROI.'];
p.params   = waveformParams();
plots(end+1) = p;

p = blankPlot();
p.name     = 'LMFP (ROI only)';
p.category = 'Waveform';
p.mode     = 'LMFP';
p.draw     = 'drawTEPOverlay';
p.info     = ['Local mean field power: GMFP restricted to the ROI ' ...
              'electrodes. Useful when a global measure is dominated by ' ...
              'activity far from the coil.'];
p.params   = waveformParams();
plots(end+1) = p;

p = blankPlot();
p.name     = 'Difference wave';
p.category = 'Waveform';
p.mode     = 'TEP';
p.draw     = 'drawDifferenceWave';
p.requires.groups = 2;
p.info     = ['The second group minus the first, with a confidence interval ' ...
              'on the difference itself. Needs exactly two groups, because a ' ...
              'difference is only defined between a pair. In a paired design ' ...
              'this is the contrast the statistics are actually about.'];
% No confidence-band switch: the interval IS the plot here, and a difference
% wave without one invites reading noise as an effect.
p.params   = [timeRangeParam(), shadeWindowsParam('off')];
plots(end+1) = p;

%% ---- Topography ------------------------------------------------------
p = blankPlot();
p.name     = 'Scalp map';
p.category = 'Topography';
p.mode     = 'TEP';
p.draw     = 'drawGroupTopo';
p.requires.chanlocs = true;
p.info     = ['The scalp distribution averaged over a time window, one map ' ...
              'per group on a shared symmetric microvolt scale so the groups ' ...
              'can be compared by eye.'];
p.params   = makeParam('window', 'Time window', 'ms', 't1 t2', ...
    ['The interval to average over. Left unset it follows the FIRST window ' ...
     'of interest, so the map keeps describing the same interval as the ' ...
     'measures table when that window is edited.'], ...
    'type', 'vector', 'placeholder', '(first window of interest)');
plots(end+1) = p;

p = blankPlot();
p.name     = 'TEP-topo';
p.category = 'Topography';
p.mode     = 'TEP';
p.draw     = 'drawTEPTopo';
p.requires.chanlocs = true;
p.requires.windows  = true;
p.info     = ['The waveforms with a grid of scalp maps above them: one column ' ...
              'per window of interest, one row per group, on one shared ' ...
              'microvolt scale. Each map averages over its window rather than ' ...
              'sampling a latency, so a map and the measure beside it describe ' ...
              'the same interval - move a window and both follow.'];
p.params   = [timeRangeParam(), shadeWindowsParam('on')];
plots(end+1) = p;

cached = plots;
end

% ── helpers ─────────────────────────────────────────────────────────────────

function p = blankPlot()
% An entry with the permissive defaults: available for any number of groups,
% needing neither windows nor electrode positions, and no settings of its own.
% Each block above then states only what makes it special, so a new entry
% cannot silently inherit a requirement it does not have.
p = struct('name', '', 'category', '', 'info', '', 'draw', '', 'mode', '', ...
           'requires', struct('groups', 'any', 'windows', false, 'chanlocs', false), ...
           'params', emptyParams());
end

function p = emptyParams()
% A 0x0 array of the makeParam shape - NOT struct([]), which has no fields and
% would make numel/fieldnames behave differently for a plot with no settings
% than for one whose settings were all removed.
p = makeParam('', '', '', '', '');
p(:) = [];
end

function p = waveformParams()
% The settings every group-overlay waveform accepts. Shared rather than
% repeated so TEP, GMFP and LMFP cannot drift apart in what they offer.
p = [timeRangeParam(), ...
     makeParam('showBand', 'Confidence band', '', 'on|off', ...
        ['Shade each group''s confidence interval. Turning it off leaves ' ...
         'the mean lines alone, which is a cleaner picture and a less ' ...
         'honest one - the band is what says how well the mean is pinned.'], ...
        'type', 'logical', 'placeholder', '(on)'), ...
     makeParam('legend', 'Legend', '', 'on|off', ...
        'Name each group and its subject count on the plot.', ...
        'type', 'logical', 'placeholder', '(on)'), ...
     shadeWindowsParam('off')];
end

function p = timeRangeParam()
p = makeParam('xlim', 'Time range', 'ms', 't1 t2', ...
    ['Time axis limits. The default starts before the pulse so the ' ...
     'pre-stimulus baseline is visible, which is where a reader judges ' ...
     'whether the post-stimulus deflections mean anything.'], ...
    'type', 'vector', 'placeholder', '(-50 300)');
end

function p = shadeWindowsParam(dflt)
p = makeParam('showBands', 'Shade windows', '', 'on|off', ...
    ['Mark the windows of interest on the time axis, so each measured ' ...
     'interval can be seen against the waveform it was measured on.'], ...
    'type', 'logical', 'placeholder', ['(' dflt ')']);
end
