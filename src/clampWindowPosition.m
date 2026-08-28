% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [newPos, changed] = clampWindowPosition(pos, minSize)
% CLAMPWINDOWPOSITION  Grow a window back to a minimum WITHOUT moving it.
%   [newPos, changed] = CLAMPWINDOWPOSITION(pos, minSize) takes a figure
%   Position [left bottom width height] and the minimum [w h], and returns the
%   Position that restores the minimum while keeping the window's TOP edge
%   where it was. changed is false when pos already met the minimum, in which
%   case newPos is pos untouched.
%
%   The subtlety this exists to contain: Position measures `bottom` from the
%   bottom of the screen, so assigning width and height alone anchors the
%   bottom-left corner and grows the window UPWARD. Dragging the bottom edge
%   up raises `bottom`; restoring the height from there lifts the whole window,
%   and over a stream of resize events it ratchets off the top of the monitor
%   at a constant size. That was a real bug - the window crept upward until it
%   left the screen.
%
%   Pinning the top edge (bottom = top - newHeight) is the fix, and `changed`
%   is what lets the caller write Position only when it genuinely must, so an
%   ordinary resize never touches it at all and cannot re-trigger itself.
%
%   Extracted from the app method it lived in so the arithmetic can be checked
%   without opening a window: every rule here is about four numbers, and a test
%   that has to launch the app to verify them takes the mouse for seconds and
%   can only try the sizes someone thought to list.
%
%   See also: nestapp/UIFigureSizeChanged, rescaleComponents

newSize = [max(pos(3), minSize(1)), max(pos(4), minSize(2))];
changed = ~isequal(newSize, pos(3:4));
if ~changed
    newPos = pos;
    return
end

topEdge = pos(2) + pos(4);
newPos  = [pos(1), topEdge - newSize(2), newSize];
end
