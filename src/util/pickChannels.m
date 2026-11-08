% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function dlg = pickChannels(parentFig, current, available, title, onDone)
% PICKCHANNELS  Choose channel labels from a list, plus any typed by hand.
%   dlg = PICKCHANNELS(parentFig, current, available, title, onDone)
%
%   current    labels already chosen (selected when the dialog opens)
%   available  labels to offer, e.g. from the selected data (see
%              channelLabelChoices); chosen labels not in it are offered too
%   onDone     called with the chosen labels (cellstr) when OK is pressed;
%              not called on Cancel
%
%   Does not wait: the result arrives through onDone, so nothing blocks MATLAB
%   while the dialog is open.
%
%   See also: channelLabelChoices, settingsForm

current = reshape(cellstr(current), 1, []);
current = current(~cellfun(@isempty, current));
items   = unique([reshape(cellstr(available), 1, []), current], 'stable');

pos = [0 0 320 440];
if ~isempty(parentFig) && isvalid(parentFig)
    p = parentFig.Position;
    pos(1:2) = p(1:2) + (p(3:4) - pos(3:4)) / 2;
end
dlg = appWindow('Name', title, 'Position', pos, 'WindowStyle', 'modal', 'Resize', 'off');
uilabel(dlg, 'Position', [12 408 296 22], 'Text', 'Select channels (Ctrl/Shift for several)', ...
    'FontColor', nestColours('navy'), 'FontWeight', 'bold');
lb = uilistbox(dlg, 'Position', [12 104 296 300], 'Items', items, 'Multiselect', 'on', ...
    'Value', intersect(current, items, 'stable'));
uilabel(dlg, 'Position', [12 72 296 22], 'Text', 'Other labels (comma-separated):');
other = uieditfield(dlg, 'Position', [12 48 296 24]);
uibutton(dlg, 'Position', [12 10 90 28], 'Text', 'Clear', 'ButtonPushedFcn', @(~, ~) set(lb, 'Value', {}));
uibutton(dlg, 'Position', [122 10 90 28], 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(dlg));
uibutton(dlg, 'Position', [218 10 90 28], 'Text', 'OK', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) finish());

    function finish()
        typed = strtrim(strsplit(other.Value, ','));
        chosen = unique([reshape(cellstr(lb.Value), 1, []), typed(~cellfun(@isempty, typed))], 'stable');
        delete(dlg);
        onDone(chosen);
    end
end
