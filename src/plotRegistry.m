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
               'mode', {}, 'requires', {});

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
plots(end+1) = p;

p = blankPlot();
p.name     = 'LMFP (ROI only)';
p.category = 'Waveform';
p.mode     = 'LMFP';
p.draw     = 'drawTEPOverlay';
p.info     = ['Local mean field power: GMFP restricted to the ROI ' ...
              'electrodes. Useful when a global measure is dominated by ' ...
              'activity far from the coil.'];
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
plots(end+1) = p;

cached = plots;
end

% ── helpers ─────────────────────────────────────────────────────────────────

function p = blankPlot()
% An entry with the permissive defaults: available for any number of groups,
% needing neither windows nor electrode positions. Each block above then states
% only what makes it special, so a new entry cannot silently inherit a
% requirement it does not have.
p = struct('name', '', 'category', '', 'info', '', 'draw', '', 'mode', '', ...
           'requires', struct('groups', 'any', 'windows', false, 'chanlocs', false));
end
