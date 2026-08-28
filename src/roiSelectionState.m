% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = roiSelectionState(current, available)
% ROISELECTIONSTATE  What the ROI picker should show, as plain data.
%   s = ROISELECTIONSTATE(current, available) resolves an incoming ROI and the
%   electrodes the data offers into everything the dialog needs to render:
%
%     .labels       1xN canonical electrode names, in diagram order
%     .selected     1xN logical - switched on
%     .enabled      1xN logical - offered by the data
%     .unplaceable  names in `available` that the diagram has no position for
%
%   Extracted from roiPicker so the decisions can be tested without opening a
%   window. That is not only convenience: the picker is modal and blocks on
%   uiwait, so a test that drives it can wedge MATLAB behind a dialog if
%   anything in the driving code goes wrong. Every rule below is a rule about
%   sets of labels, not about widgets, and belongs where it can be checked
%   directly.
%
%   Matching is case-insensitive on the way in and canonical on the way out: an
%   ROI arriving in a file's own spelling ('cz') must still light up the button,
%   and what comes back must be spelled the way electrodeList spells it, or a
%   saved session and the montage it came from disagree.
%
%   .unplaceable is the honest half. This project's own recordings carry FT9 and
%   FT10 (32 files) and Iz (3), none of which has a spot on the head image. They
%   load, they pass availability, and they are legal ROI members - so the picker
%   reports them rather than dropping them, because a channel that silently
%   cannot be chosen looks like a channel that does not exist.
%
%   See also: roiPicker, roiMontageLayout, electrodeAvailability, applyRoiPreset

if nargin < 1 || isempty(current);   current = {};   end
if nargin < 2;                       available = {}; end
if ischar(current) || isstring(current);     current = cellstr(current);     end
if ischar(available) || isstring(available); available = cellstr(available); end

layout   = roiMontageLayout();
s.labels = {layout.label};

% electrodeAvailability owns "present in every set", including the documented
% rule that no sets means everything is offered. One file's labels is one set.
sets = {};
if ~isempty(available); sets = {available}; end
s.enabled = electrodeAvailability(s.labels, sets);

s.selected = ismember(lower(s.labels), lower(current));

avail = available(:)';
s.unplaceable = avail(~ismember(lower(avail), lower(s.labels)));
end
