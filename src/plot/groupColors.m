% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function C = groupColors(n)
% GROUPCOLORS  A categorical palette that scales to any number of groups.
%   C = GROUPCOLORS(n) returns an n-by-3 RGB matrix, one row per group.
%
%   The base palette is Okabe & Ito's eight-colour qualitative set, designed to
%   stay distinguishable under the common forms of colour vision deficiency.
%   That matters more here than house style: these colours end up in figures
%   where the only thing separating two conditions is the colour of a line, and
%   roughly one in twelve male readers cannot separate a red line from a green
%   one. The set is also close to what the TEP literature already uses - grey,
%   orange and blue for three groups.
%
%   The first colour is a dark neutral rather than a hue, so the single-group
%   case - the common one - draws in near-black instead of an arbitrary colour.
%
%   Beyond eight groups the palette repeats with reduced lightness rather than
%   inventing new hues. Nine categorical colours cannot be told apart reliably
%   anyway; a repeat that is visibly darker at least signals "second lap"
%   instead of silently colliding.
%
%   See also: drawTEPOverlay, divergingColormap

BASE = [ ...
    0.15 0.15 0.15    % near-black   (the sensible single-group default)
    0.90 0.62 0.00    % orange
    0.34 0.71 0.91    % sky blue
    0.00 0.62 0.45    % bluish green
    0.00 0.45 0.70    % blue
    0.84 0.37 0.00    % vermillion
    0.80 0.47 0.65    % reddish purple
    0.94 0.89 0.26];  % yellow

if nargin < 1 || isempty(n); n = 1; end
n = max(0, round(n));
if n == 0; C = zeros(0, 3); return; end

nBase = size(BASE, 1);
C     = zeros(n, 3);
for i = 1:n
    lap        = floor((i - 1) / nBase);          % 0 on the first pass
    shade      = 0.7 ^ lap;                        % each lap is darker
    C(i, :)    = BASE(mod(i - 1, nBase) + 1, :) * shade;
end
C = min(max(C, 0), 1);
end
