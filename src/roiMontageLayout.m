% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [layout, headSize] = roiMontageLayout()
% ROIMONTAGELAYOUT  Where each electrode sits on the head diagram.
%   [layout, headSize] = ROIMONTAGELAYOUT() returns the montage the ROI picker
%   draws: a struct array with .label and .pos ([x y w h]) per electrode, plus
%   the size of the Head.png the coordinates assume.
%
%   These positions are hand-placed against the head image and cannot be
%   derived from the labels - a 10-20 name says where an electrode sits on a
%   scalp, not where it lands on this particular drawing. So they are data.
%
%   They were extracted verbatim from createComponents, where they had been 69
%   near-identical nine-line blocks each building one uibutton: 637 of that
%   file's 1326 lines, plus 69 class properties, to express a 69-row table.
%   The picker builds its buttons from this table, which is why the diagram
%   looks exactly as it did before.
%
%   Coordinates are relative to the head image's own origin rather than to the
%   tab they used to sit on, so the montage can be dropped into any container.
%
%   See also: roiPicker, roiChannelIndex, electrodeAvailability

BUTTON_W = 25;
BUTTON_H = 23;
headSize = [350 336];      % size of Head.png that these positions assume

% label, x, y  (button bottom-left, relative to the head image)
T = {
    'AF3', 109, 245;
    'FP1', 132, 268;
    'FPZ', 162, 274;
    'FP2', 192, 268;
    'AF4', 216, 244;
    'F8', 267, 225;
    'F6', 241, 220;
    'F4', 215, 215;
    'F2', 188, 220;
    'F5',  81, 220;
    'F3', 108, 215;
    'FZ', 162, 221;
    'FC2', 193, 183;
    'FC4', 223, 183;
    'FC6', 253, 185;
    'F1', 135, 220;
    'C4', 230, 151;
    'C6', 263, 151;
    'FT8', 286, 189;
    'F7',  56, 226;
    'FC1', 131, 183;
    'FCZ', 162, 184;
    'FC3', 100, 183;
    'C1', 129, 151;
    'CZ', 162, 151;
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
    'CPZ', 162, 121;
    'CP4', 225, 118;
    'CP6', 259, 114;
    'TP8', 289, 112;
    'P8', 276,  72;
    'P3', 106,  86;
    'P1', 133,  86;
    'P2', 189,  86;
    'P7',  47,  72;
    'P5',  77,  81;
    'PZ', 162,  85;
    'P4', 217,  86;
    'P6', 246,  81;
    'O1', 129,  14;
    'PO3', 107,  51;
    'POZ', 162,  46;
    'PO4', 218,  52;
    'PO7',  53,  39;
    'PO5',  79,  50;
    'PO2', 190,  47;
    'PO8', 271,  37;
    'CB1',  99,  24;
    'OZ', 161,  12;
    'O2', 193,  14;
    'CB2', 225,  24;
    'TP10', 303,  88;
    'TP9',  21,  88;
    'AFZ', 162, 247;
    'AF7',  80, 254;
    'AF8', 246, 254;
    'PO1', 134,  47;
    'PO6', 244,  50;
};

pos    = cellfun(@(x, y) [x, y, BUTTON_W, BUTTON_H], T(:, 2), T(:, 3), ...
                 'UniformOutput', false);
layout = struct('label', T(:, 1), 'pos', pos);
layout = reshape(layout, 1, []);
end
