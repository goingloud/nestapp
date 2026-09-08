
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = softwareSentence(report)
% SOFTWARESENTENCE  Opening sentence of a methods paragraph.
%   s = SOFTWARESENTENCE(report) returns "<modality> were preprocessed in MATLAB
%   using <toolbox> (nestapp <ver>).", with the modality (TMS-EEG vs EEG) and
%   toolbox (whether TESA was used) inferred from the steps that ran. Shared by
%   methodsNarrative and methodsParagraphAggregate.
%
%   See also: methodsNarrative, methodsParagraphAggregate, reportStepNames

    names    = reportStepNames(report);
    isTMS    = any(contains(names, 'TMS')) || any(contains(names, '(TESA)'));
    usesTesa = any(contains(names, '(TESA)'));
    modality = 'EEG data';
    if isTMS; modality = 'TMS-EEG data'; end
    tool = 'EEGLAB';
    if usesTesa; tool = 'EEGLAB and the TESA toolbox'; end
    s = sprintf('%s were preprocessed in MATLAB using %s (nestapp %s).', ...
        modality, tool, nestappVersion());
end
