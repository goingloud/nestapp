
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function rescaleComponents(app, sX, sY)
% RESCALECOMPONENTS  Scale every UI component from its captured base geometry.
%   Called from UIFigureSizeChanged. Geometry comes from app.baseLayout, a
%   snapshot taken once at startup (see captureBaseLayout) of the positions set
%   in createComponents - so the coordinates are NOT duplicated here, and any
%   component added to createComponents is rescaled automatically.
%
%   Per component: position scales by [sX sY]; fixed-height controls keep their
%   base height; font-scaled components scale by min(sX,sY) with an 8 pt floor.
%   StatusBar (full width, fixed height, pinned bottom) and TabGroup (height
%   computed from the figure) are handled explicitly.
    STATUS_H = 20;
    if isempty(app.baseLayout)
        return   % not captured yet (an early resize during construction)
    end

    sf    = min(sX, sY);
    L     = app.baseLayout;
    names = fieldnames(L);
    for i = 1:numel(names)
        n = names{i};
        if ~isprop(app, n); continue; end
        h = app.(n);
        if ~(isscalar(h) && isgraphics(h)); continue; end
        e = L.(n);
        p = e.pos;
        if e.fixedH
            h.Position = [round(p(1)*sX), round(p(2)*sY), round(p(3)*sX), p(4)];
        else
            h.Position = round(p .* [sX, sY, sX, sY]);
        end
        if ~isempty(e.font)
            h.FontSize = max(8, round(e.font * sf));
        end
    end

    % Status bar: fixed height, pinned to the bottom, full width.
    app.StatusBar.Position = round([0, 0, 867*sX, STATUS_H]);
    % TabGroup fills all coordinate space above the status bar.
    figH = round(sY * app.originalSize(2));
    app.TabGroup.Position = [1, STATUS_H, round(867*sX), figH - STATUS_H];
end
