
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function p = stepInteractiveIcon()
% STEPINTERACTIVEICON  Path to the amber dot marking steps that wait for you.
%   p = STEPINTERACTIVEICON() returns the path to a cached PNG - a filled amber
%   circle on a transparent ground - used as the tree-node Icon for steps that
%   can stop and wait for a human (see canStepBlock). Generated once and cached
%   under tempdir.
%
%   Only about six of fifty steps carry it, which is the point: a marker on
%   every row would say nothing. It previously flagged in-house / vendored
%   provenance, which was true of every row once expanded and is better served
%   as text in the Info panel.
%
%   See also: canStepBlock, interactivePipelineSteps, stepTaxonomy

persistent cached
if ~isempty(cached) && isfile(cached)
    p = cached;
    return
end

col = [0.82 0.52 0.12];        % amber
n   = 16;
r   = 0.55;
[xx, yy] = meshgrid(linspace(-1, 1, n));
mask = (xx.^2 + yy.^2) <= r^2;
img  = ones(n, n, 3);
for ch = 1:3
    layer = img(:, :, ch);
    layer(mask) = col(ch);
    img(:, :, ch) = layer;
end

p = fullfile(tempdir, 'nestapp_step_interactive.png');
imwrite(uint8(img * 255), p, 'Alpha', double(mask));
cached = p;
end
