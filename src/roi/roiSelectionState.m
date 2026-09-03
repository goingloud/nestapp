% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = roiSelectionState(current, available, optional)
% ROISELECTIONSTATE  What the ROI picker should show, as plain data.
%   s = ROISELECTIONSTATE(current, available) resolves an incoming ROI and the
%   electrodes the data offers into everything the dialog needs to render:
%
%     .labels       1xN canonical electrode names, in diagram order
%     .selected     1xN logical - switched on
%     .enabled      1xN logical - present in every loaded file
%     .partial      1xN logical - present in SOME file but not all; selectable
%                   only when the caller offers the override
%     .offLabels    1xM names the diagram has no position for, but which the
%                   data carries or the incoming ROI already names
%     .offSelected  1xM logical
%     .offEnabled   1xM logical - as .enabled, for the off-diagram names
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
%   THE OFF-DIAGRAM LIST IS NOT COSMETIC. This project's own recordings carry
%   FT9 and FT10 (32 files) and Iz (3), none of which has a spot on the head
%   image. They load, they pass availability, and they are legal ROI members.
%   The picker used to name them in a text line and offer no way to pick one -
%   and worse, since the accepted ROI was rebuilt from the diagram's labels
%   alone, opening the dialog on an ROI containing FT9 and pressing accept
%   DELETED FT9, silently. So the list is built from `available` UNION
%   `current`: what the data offers, plus whatever the ROI already holds, so
%   nothing a user had can be destroyed by looking at it.
%
%   .partial exists because "not in every file" and "not in any file" are
%   different answers. An electrode in 30 of 32 files is a real methodological
%   choice - the ROI mean would then be over different channels in different
%   files - so it is offered behind an explicit override rather than being
%   silently unavailable or silently included.
%
%   See also: roiPicker, roiMontageLayout, electrodeAvailability, applyRoiPreset

if nargin < 1 || isempty(current);   current   = {}; end
if nargin < 2;                       available = {}; end
if nargin < 3;                       optional  = {}; end
if ischar(current)   || isstring(current);   current   = cellstr(current);   end
if ischar(available) || isstring(available); available = cellstr(available); end
if ischar(optional)  || isstring(optional);  optional  = cellstr(optional);  end
current = current(:)'; available = available(:)'; optional = optional(:)';

layout   = roiMontageLayout();
s.labels = {layout.label};

% electrodeAvailability owns "present in every set", including the documented
% rule that no sets means everything is offered. One file's labels is one set.
sets = {};
if ~isempty(available); sets = {available}; end
s.enabled = electrodeAvailability(s.labels, sets);

s.selected = ismember(lower(s.labels), lower(current));
s.partial  = ~s.enabled & ismember(lower(s.labels), lower(optional));

% Off-diagram: what the data carries plus what the ROI already names, so an
% incoming ROI cannot be silently narrowed by the dialog that displays it.
off = [available, optional, current];
off = off(~ismember(lower(off), lower(s.labels)));
[~, keep]    = unique(lower(off), 'stable');
s.offLabels  = off(sort(keep));
s.offSelected = ismember(lower(s.offLabels), lower(current));
s.offEnabled  = isempty(available) | ismember(lower(s.offLabels), lower(available));
end
