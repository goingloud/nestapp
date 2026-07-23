
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function p = stepFlagIcon()
% STEPFLAGICON  Path to the small amber dot that flags in-house / vendored steps.
%   p = STEPFLAGICON() returns the path to a cached PNG - a filled amber circle
%   on a transparent ground - used as the tree-node Icon for steps supplied by
%   AARATEP (vendored) or nestapp (in-house), rather than a first-tier toolbox.
%   It implies provenance at a glance without any tier label. Generated once
%   and cached under tempdir.
%
%   See also: stepTaxonomy

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

p = fullfile(tempdir, 'nestapp_step_flag.png');
imwrite(uint8(img * 255), p, 'Alpha', double(mask));
cached = p;
end
