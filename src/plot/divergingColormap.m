
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function cmap = divergingColormap(n)
% DIVERGINGCOLORMAP  Blue -> white -> red map for signed scalp/field data.
%   cmap = DIVERGINGCOLORMAP()  returns a 256x3 map.
%   cmap = DIVERGINGCOLORMAP(n) returns an nx3 map (n >= 2).
%
%   MATLAB ships no diverging colormap. Topographies are signed data whose
%   reference is zero, so the map needs a neutral midpoint and two balanced
%   limbs: paired with a symmetric CLim ([-m m]), white reads as "no
%   deflection" and equal magnitudes of opposite sign get equally saturated
%   colours. Rows equidistant from the centre sit equally far from white. With
%   an odd n the centre row is exactly white; with an even n the two central
%   rows straddle it.
%
%   See also: drawScalpTopo, topoplot

% Memoized on n. It is called once per scalp map, and a grid of twelve maps
% rebuilt the same 256x3 matrix twelve times a repaint for nothing.
persistent cachedN cachedMap
if nargin < 1 || isempty(n)
    n = 256;
end
if ~isempty(cachedN) && isequal(cachedN, n)
    cmap = cachedMap;
    return
end
validateattributes(n, {'numeric'}, {'scalar', 'integer', '>=', 2}, mfilename, 'n');

% t runs -1 (cold end) .. 0 (neutral midpoint) .. +1 (warm end).
t = linspace(-1, 1, n)';
w = abs(t);                 % distance from the neutral midpoint

% The two end colours are chosen equidistant from white (sum(1-rgb) = 1.88
% for both), so the limbs are balanced and a +5 uV deflection reads as
% exactly as strong as a -5 uV one.
COLD = [0.13 0.31 0.68];    % blue  at t = -1
WARM = [0.79 0.14 0.19];    % red   at t = +1
NEUTRAL = [1 1 1];          % white at t =  0

endColor = COLD .* (t < 0) + WARM .* (t >= 0);
cmap     = NEUTRAL .* (1 - w) + endColor .* w;

cachedN   = n;
cachedMap = cmap;
end
