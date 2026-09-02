% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [total, rows] = paramFormHeight(meta)
% PARAMFORMHEIGHT  Pixels paramForm needs for a list of settings.
%   [total, rows] = PARAMFORMHEIGHT(meta)
%
%   total  height of the whole form, including the bottom pad
%   rows   per-setting heights, in the order meta is given
%
%   Separate from paramForm because a caller has to MINT THE PANEL before the
%   form can be built into it, so it needs the height first. paramForm then
%   reads its row heights from here rather than keeping its own copy - two
%   tables would drift, and the failure is a form that quietly overflows the
%   panel it was sized for, with the last setting cut off or invisible.
%
%   Most rows are one line. A multi-select is the exception: a listbox showing
%   one item at a time is worse than the text field it replaced. It is sized
%   for SIX items, because the six standard TEP components are what the one
%   multi-select in the catalogue normally holds - having to scroll a
%   six-item list to see what is selected is the annoyance the row height
%   exists to remove.
%
%   See also: paramForm, plotOptionsDialog, makeParam

ROW_H  = 34;
LIST_H = 152;   % about six items plus the label above them
PAD    = 8;

rows = repmat(ROW_H, 1, numel(meta));
for k = 1:numel(meta)
    if strcmpi(widgetOverride(meta(k)), 'multiselect')
        rows(k) = LIST_H;
    end
end
total = sum(rows) + PAD;
end

function w = widgetOverride(m)
w = '';
if isfield(m, 'widget'); w = char(m.widget); end
end
