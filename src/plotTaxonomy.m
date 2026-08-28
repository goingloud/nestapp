% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tax = plotTaxonomy()
% PLOTTAXONOMY  Hand-ordered grouping of plots for the picker.
%
%   tax = PLOTTAXONOMY() returns a 1-by-C struct array:
%     .name  category heading
%     .plots cellstr of plot names, in the order they should be offered
%
%   Separate from plotRegistry for the same reason stepTaxonomy is separate
%   from stepRegistry: the registry is what a plot IS, the taxonomy is how it
%   is presented. Presentation order is a judgement about what a user reaches
%   for first, and it should be editable without touching the definitions.
%
%   Order here is the order of a working session: look at the waveform, then
%   the scalp distribution behind it, then quantify. Any registry entry the
%   taxonomy forgets still appears in the picker under "Other" - the same
%   safety net the step picker has - so adding a plot and forgetting this file
%   degrades the ordering rather than hiding the feature.
%
%   See also: plotRegistry, availablePlots, plotAvailability

tax = struct('name', {}, 'plots', {});

tax(end+1) = struct('name', 'Waveform', 'plots', {{ ...
    'TEP (ROI mean)', ...
    'GMFP (all channels)', ...
    'LMFP (ROI only)', ...
    'Difference wave'}});

tax(end+1) = struct('name', 'Topography', 'plots', {{ ...
    'Scalp map'}});
end
