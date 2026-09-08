
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function EEG = runIcaEngine(EEG, icatype, vars)
% RUNICAENGINE  Decompose EEG into independent components with one ICA engine.
%   EEG = RUNICAENGINE(EEG, icatype, vars) is the shared runner behind the
%   per-method "Run ICA (FastICA|Infomax|Picard)" pipeline steps. It resolves
%   the 'pca' option and calls pop_runica with the requested engine.
%
%   vars is a name-value cell holding ONLY that engine's parameters - each
%   Run ICA step exposes only the keys valid for its engine (FastICA:
%   approach/g/stabilization; Infomax: extended; Picard: mode/maxiter), so no
%   cross-engine option stripping happens here. pop_runica forwards any option
%   it does not recognise itself straight to the engine.
%
%   'pca' handling: 0 or empty = off; a negative value = reduce to the data's
%   numerical rank (via dataNumericalRank - the well-posed count, stable across
%   files); an integer >= 1 = fixed component count; 0 < value < 1 = retain that
%   fraction of variance (component count computed from the data via
%   numPCsForVariance). EEGLAB applies the reduction inside pop_runica.
%   Recommended on rank-deficient data (after average reference or channel
%   interpolation) to avoid over-decomposition.
%
%   Inputs:
%     EEG     - EEGLAB struct.
%     icatype - 'fastica' | 'runica' | 'picard'.
%     vars    - name-value cell of engine params (e.g. {'mode','standard','pca',0.999}).
%
%   Output:
%     EEG with icaweights/icasphere/icawinv populated.

    EEG.data = double(EEG.data);
    pidx = find(strcmpi(vars, 'pca'), 1);
    nKeep = [];                          % resolved component count (empty = off)
    if ~isempty(pidx)
        pcaVal = vars{pidx + 1};
        if isempty(pcaVal) || pcaVal == 0
            vars(pidx:pidx+1) = [];          % off
        elseif pcaVal < 0
            nKeep = dataNumericalRank(EEG.data);   % rank-based (well-posed count)
            vars{pidx + 1} = nKeep;
            fprintf('runIcaEngine: PCA -> numerical rank = %d components (of %d channels)\n', ...
                nKeep, size(EEG.data, 1));
        elseif pcaVal < 1
            nKeep = numPCsForVariance(EEG.data, pcaVal);
            vars{pidx + 1} = nKeep;
            fprintf('runIcaEngine: PCA -> %.4g variance = %d components (of %d channels)\n', ...
                pcaVal, nKeep, size(EEG.data, 1));
        else
            nKeep = round(pcaVal);
            vars{pidx + 1} = nKeep;
        end
    end

    % pop_runica honours the 'pca' option for runica/binica/picard but NOT for
    % fastica - it forwards 'pca' straight to fastica(), which errors with
    % "Unrecognized parameter: 'pca'". Translate to fastica's own PCA
    % dimension-reduction keys (lastEig/numOfIC) so the step's PCA param works.
    if strcmpi(icatype, 'fastica') && ~isempty(nKeep) && ~isempty(pidx)
        vars(pidx:pidx+1) = [];
        vars = [vars, {'lastEig', nKeep, 'numOfIC', nKeep}];
    end

    EEG = pop_runica(EEG, 'icatype', icatype, vars{:});
    EEG = eeg_checkset(EEG);
end
