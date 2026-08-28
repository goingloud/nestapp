% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function labels = electrodeList()
% ELECTRODELIST  The electrode names nestapp knows, in canonical spelling.
%   labels = ELECTRODELIST() returns a 1x69 cellstr.
%
%   One list, because the spelling is load-bearing in a way that hides. Channel
%   matching is case-insensitive everywhere (roiChannelIndex,
%   electrodeAvailability), so a second list can disagree on case indefinitely
%   without anything failing - and then the disagreement surfaces as an ROI
%   written into a CSV or a session file spelled unlike the montage it came
%   from.
%
%   That had already happened. The head-diagram buttons carried FPZ/FZ/FCZ/CZ/
%   CPZ/PZ/POZ/OZ/AFZ while this list has FPz/Fz/FCz/Cz/CPz/Pz/POz/Oz/AFz, and
%   findTEPelecs bridged the two with upper() at the point of use.
%
%   This is the app's own vocabulary, not a claim about what a cap can have.
%   Electrodes a user's montage carries but this list omits - FT9, FT10 and Iz
%   are all present in this project's own recordings - load normally, pass
%   availability, and are legal ROI members. They simply have no place on the
%   head diagram, which roiPicker reports rather than hides.
%
%   See also: roiMontageLayout, roiPicker, electrodeAvailability, roiChannelIndex

labels = { ...
    'FPz', 'FP1', 'FP2', 'AF7', 'AF3', 'AFz', 'AF4', 'AF8', ...
    'F7', 'F5', 'F3', 'F1', 'F2', 'F4', 'F6', 'F8', ...
    'Fz', 'FT7', 'FT8', 'FC5', 'FC3', 'FC1', 'FCz', 'FC2', ...
    'FC4', 'FC6', 'T7', 'T8', 'C5', 'C3', 'C1', 'Cz', ...
    'C2', 'C4', 'C6', 'TP7', 'TP8', 'CP5', 'CP3', 'CP1', ...
    'CPz', 'CP2', 'CP4', 'CP6', 'P7', 'P5', 'P3', 'P1', ...
    'Pz', 'P2', 'P4', 'P6', 'P8', 'PO7', 'PO5', 'PO3', ...
    'PO1', 'POz', 'PO2', 'PO4', 'PO6', 'PO8', 'CB1', 'O1', ...
    'Oz', 'O2', 'CB2', 'TP9', 'TP10' ...
};
end
