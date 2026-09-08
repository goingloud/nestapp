% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function pos = centreOn(anchor, w, h)
% CENTREON  A w-by-h window position centred on anchor, or on the screen.
%   pos = CENTREON(anchor, w, h) returns [left bottom w h]. anchor may be any
%   figure, or empty for the screen centre.
%
%   The final clamp keeps the top-left corner on screen. Without it a dialog
%   centred on an app window near a screen edge - or on a secondary monitor
%   placed left of or below the primary - opens at negative coordinates with
%   its title bar out of reach.
%
%   Extracted because this had four verbatim copies (roiPicker,
%   exploreFilesTable, and both new param dialogs) and they had already
%   diverged: the two newer ones were missing the clamp. Same argument as
%   fillDefaults and clampWindowPosition - it is not the lines saved, it is
%   that four copies is three chances to disagree.
%
%   See also: clampWindowPosition, roiPicker, plotOptionsDialog

if ~isempty(anchor) && isvalid(anchor)
    p   = anchor.Position;
    pos = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2, w, h];
else
    s   = get(groot, 'ScreenSize');
    pos = [(s(3) - w)/2, (s(4) - h)/2, w, h];
end
pos(1:2) = max(pos(1:2), 1);
end
