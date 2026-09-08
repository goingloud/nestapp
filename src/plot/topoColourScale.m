% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [perColumn, shared] = topoColourScale(vals, byColumn, override)
% TOPOCOLOURSCALE  Decide the colour limits for a grid of scalp maps.
%   [perColumn, shared] = TOPOCOLOURSCALE(vals)
%   [perColumn, shared] = TOPOCOLOURSCALE(vals, byColumn)
%   [perColumn, shared] = TOPOCOLOURSCALE(vals, byColumn, override)
%
%   vals       nRows-by-nCols cell, each holding one map's channel values.
%              A row is a group; a column is a window.
%   byColumn   false (default) - one limit across the whole grid
%              true            - one limit per column, shared down its rows
%   override   [] to derive; a scalar uV to pin the limits at +/- that value;
%              or an explicit 2-element [lo hi], which wins outright.
%
%   A LOGICAL RATHER THAN A MODE STRING, deliberately. Both callers name this
%   choice in their own vocabulary - drawGroupTopo calls it "per map",
%   drawTEPTopo "per window" - and each had grown the same two-line adapter
%   translating its word into a third one this function understood. Taking a
%   boolean lets each caller pass matchesChoice(opts.<its own field>, '<its
%   own word>') in one line, with no duplicated translation and without this
%   function learning either caller's domain naming. Teaching it those words
%   would re-couple pure arithmetic to the registry's wording, which is how
%   three drifted copies of one enum comparison happened.
%
%   perColumn  1-by-nCols cell of [lo hi], the limits each column's maps use.
%   shared     [lo hi] when every column shares one, and EMPTY when they do
%              not. That emptiness is a contract, not a convenience: a caller
%              hanging one colour bar over maps that no longer share a scale
%              would state a voltage that means something else in the map
%              beside it, which is a wrong number on a published figure.
%
%   ONE FUNCTION FOR TWO CALLERS, because they turned out to be the same
%   operation. drawGroupTopo lays out one map per group - a single row - and
%   calls its alternative to 'shared' PER MAP; drawTEPTopo lays out groups by
%   windows and calls it PER WINDOW. Per-map over a one-row grid IS per-column,
%   so the two were the same rule written twice, differing only in what the
%   grid meant.
%
%   THE LIMITS ARE ALWAYS SYMMETRIC ABOUT ZERO. drawScalpTopo pairs them with a
%   diverging colormap whose neutral midpoint is white; an off-centre zero puts
%   white somewhere other than no-deflection and the polarity misreads. That is
%   why an override is a scalar magnitude rather than a pair - the pair form
%   exists only for a caller that has already computed limits and is passing
%   them straight through.
%
%   A ZERO OR NON-FINITE override means "derive one". A symmetric range of zero
%   width is not a scale, and honouring it would clip every map to +/-1 uV and
%   hide all of the data - which is precisely the state the plot-options form
%   leaves behind when its Default checkbox is unticked before a number is
%   typed, so it has to be harmless.
%
%   Extracted from drawGroupTopo and drawTEPTopo, which both decided this
%   BEFORE drawing anything, yet were only reachable through a full render:
%   about 21 tests were drawing roughly 100 topoplots to read back one number,
%   and three of them built a figure and required EEGLAB on the path to prove
%   an argument-count error.
%
%   See also: drawScalpTopo, drawGroupTopo, drawTEPTopo, sharedColorbar

if nargin < 2 || isempty(byColumn); byColumn = false; end
if nargin < 3;                      override = [];    end

nCols = size(vals, 2);
if isempty(vals)
    perColumn = {};
    shared    = [0 0];
    return
end

% A zero or non-finite pin names no scale at all, so it is read as "derive
% one" before the precedence chain below sees it.
if ~isempty(override) && (~isfinite(override(1)) || override(1) == 0)
    override = [];
end

% ONE decision - what is the shared limit - then perColumn is derived from it.
% Precedence: an explicit pair, then a pinned magnitude, then the mode.
if numel(override) == 2
    shared = override(:)';
elseif ~isempty(override)
    m      = abs(override(1));
    shared = [-m m];
elseif byColumn
    shared = [];        % nothing for one colour bar to describe
else
    shared = symmetricLimit(vals(:));
end

if isempty(shared)
    perColumn = cell(1, nCols);
    for k = 1:nCols
        perColumn{k} = symmetricLimit(vals(:, k));
    end
else
    perColumn = repmat({shared}, 1, nCols);
end
end

function lim = symmetricLimit(cells)
% Widest absolute value across these maps, symmetric about zero. An all-zero or
% degenerate set falls back to a unit range so the colormap still has an extent.
m = max(cellfun(@(v) max(abs(v(:))), cells(:)));
if isempty(m) || ~isfinite(m) || m == 0
    m = 1;
end
lim = [-m m];
end
