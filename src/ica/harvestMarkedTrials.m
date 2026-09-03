
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function badTrials = harvestMarkedTrials(tmprej, pnts, trials)
% HARVESTMARKEDTRIALS  Trials the user marked in an eegplot window.
%   badTrials = HARVESTMARKEDTRIALS(tmprej, pnts, trials) converts the region
%   array eegplot hands to its 'command' callback (TMPREJ) into a sorted row
%   vector of trial indices.
%
%   tmprej may be empty, meaning the user confirmed without marking anything -
%   which is a real answer ("reject nothing"), not a missing one, and returns
%   an empty index list rather than falling back to some other selection.
%
%   Why this is a function and not four lines inside the dispatch: it is the
%   step where a user's decision enters the pipeline, and it was silently
%   losing that decision (pop_rejmenu reports through the base workspace,
%   which a pipeline running with `global EEG` never sees). Behaviour that
%   matters is behaviour worth testing directly, and this can be tested
%   without opening a window.
%
%   See also: eegplot, eegplot2trial, processOneFile

if nargin < 3
    error('harvestMarkedTrials:NargIn', ...
        'Usage: harvestMarkedTrials(tmprej, pnts, trials)');
end

badTrials = zeros(1, 0);
if isempty(tmprej)
    return
end

% Drop duplicate regions before converting. eegplot2trial reduces the regions
% to unique trial indices but still indexes the full region list for the
% per-electrode columns, so a repeated region makes it throw a size mismatch
% - and an error here would discard the user's ENTIRE selection over a
% double-drag on one trial.
tmprej = unique(tmprej, 'rows', 'stable');

rejVector = eegplot2trial(tmprej, pnts, trials);
badTrials = reshape(find(logical(rejVector)), 1, []);
end
