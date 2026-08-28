% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [layout, headSize] = roiMontageLayout()
% ROIMONTAGELAYOUT  Where each electrode sits on the head diagram.
%   [layout, headSize] = ROIMONTAGELAYOUT() returns a struct array with .label
%   and .pos ([x y w h]) per electrode, plus the size of the Head.png the
%   coordinates assume.
%
%   Positions are data because they cannot be derived: a hand-drawn PNG is not
%   a projection, so a 10-20 name says where an electrode sits on a scalp, not
%   where it lands on this drawing.
%
%   This table is the authority on POSITION only, never on which electrodes
%   exist - names come from electrodeList, and what a user may actually choose
%   comes from their data. roiPicker reports channels it cannot place rather
%   than dropping them, because a picker that silently loses a channel is worse
%   than one that admits its diagram is incomplete.
%
%   Coordinates are relative to the head image's own origin rather than the tab
%   the buttons used to sit on, so the montage drops into any container. They
%   are absolute pixels against a 350x336 Head.png; replacing that image means
%   re-placing these rows, which is why the picker does not resize.
%
%   The rows were extracted verbatim from the 69 near-identical uibutton blocks
%   in createComponents (637 of its 1326 lines, plus 69 class properties), so
%   the diagram is unchanged. Those blocks are STILL THERE and still drive the
%   Visualizing tab: this is a staged replacement, and they come out when the
%   Explore tab takes over the space they occupy.
%
%   See also: roiPicker, electrodeList, roiChannelIndex, electrodeAvailability

BUTTON_W = 25;
BUTTON_H = 23;
headSize = [350 336];      % size of Head.png that these positions assume

% label, x, y  (button bottom-left, relative to the head image)
T = {
    'AF3', 109, 245;
    'FP1', 132, 268;
    'FPz', 162, 274;
    'FP2', 192, 268;
    'AF4', 216, 244;
    'F8', 267, 225;
    'F6', 241, 220;
    'F4', 215, 215;
    'F2', 188, 220;
    'F5',  81, 220;
    'F3', 108, 215;
    'Fz', 162, 221;
    'FC2', 193, 183;
    'FC4', 223, 183;
    'FC6', 253, 185;
    'F1', 135, 220;
    'C4', 230, 151;
    'C6', 263, 151;
    'FT8', 286, 189;
    'F7',  56, 226;
    'FC1', 131, 183;
    'FCz', 162, 184;
    'FC3', 100, 183;
    'C1', 129, 151;
    'Cz', 162, 151;
    'C2', 196, 151;
    'CP3',  98, 118;
    'CP1', 129, 119;
    'CP2', 193, 119;
    'T8', 294, 151;
    'FT7',  37, 189;
    'FC5',  69, 185;
    'C5',  60, 151;
    'C3',  94, 151;
    'T7',  27, 151;
    'TP7',  35, 112;
    'CP5',  63, 114;
    'CPz', 162, 121;
    'CP4', 225, 118;
    'CP6', 259, 114;
    'TP8', 289, 112;
    'P8', 276,  72;
    'P3', 106,  86;
    'P1', 133,  86;
    'P2', 189,  86;
    'P7',  47,  72;
    'P5',  77,  81;
    'Pz', 162,  85;
    'P4', 217,  86;
    'P6', 246,  81;
    'O1', 129,  14;
    'PO3', 107,  51;
    'POz', 162,  46;
    'PO4', 218,  52;
    'PO7',  53,  39;
    'PO5',  79,  50;
    'PO2', 190,  47;
    'PO8', 271,  37;
    'CB1',  99,  24;
    'Oz', 161,  12;
    'O2', 193,  14;
    'CB2', 225,  24;
    'TP10', 303,  88;
    'TP9',  21,  88;
    'AFz', 162, 247;
    'AF7',  80, 254;
    'AF8', 246, 254;
    'PO1', 134,  47;
    'PO6', 244,  50;
};

xy     = cell2mat(T(:, 2:3));
pos    = [xy, repmat([BUTTON_W BUTTON_H], size(xy, 1), 1)];
layout = struct('label', T(:, 1)', 'pos', num2cell(pos, 2)');
end
