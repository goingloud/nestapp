
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function names = icaDecompositionSteps()
% ICADECOMPOSITIONSTEPS  Step names that produce a fresh ICA decomposition.
%   names = ICADECOMPOSITIONSTEPS() lists every pipeline step that computes a
%   new ICA decomposition (populates EEG.icaweights). processOneFile opens a
%   new ICA "round" in the report for each of these so a multi-pass pipeline
%   records each decomposition - and the components it removes - separately.
%
%   Why this matters: the per-engine steps ('Run ICA (Picard|FastICA|
%   Infomax)') were once omitted here, so only 'Run TESA ICA' opened a round.
%   In a two-pass pipeline (e.g. TESA ICA, then a Picard + ICLabel pass) the
%   second pass never opened a round, so addICARemoval folded its removal into
%   the FIRST round and discarded its variance figure - making the
%   Picard->ICLabel pass look like it removed nothing even though the data was
%   cleaned. Keep every decomposition step in this list.
%
%   See also: openICARound, addICARemoval, recomputeICATotals, processOneFile

names = {'Run ICA', ...            % legacy generic name (older saved pipelines)
         'Run TESA ICA', ...
         'Run ICA (FastICA)', ...
         'Run ICA (Infomax)', ...
         'Run ICA (Picard)'};
end
