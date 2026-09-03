
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [tf, always] = canStepBlock(regEntry)
% CANSTEPBLOCK  Could this step ever stop and wait for a human?
%   tf            = CANSTEPBLOCK(regEntry)
%   [tf, always]  = CANSTEPBLOCK(regEntry)
%
%   tf     - true if the step opens a modal, a rejection menu, or a plot the
%            user must close, under ANY parameter settings.
%   always - true when it blocks unconditionally; false when it blocks only in
%            certain modes (registry `interactiveWhen`), e.g. TESA component
%            removal waits only when component review is switched on.
%
%   This answers the step-picker's question - "could this one wait for me?" -
%   before any parameters have been chosen. It is deliberately distinct from
%   interactivePipelineSteps, which answers the run-time question, "will this
%   spec block *as configured*", and needs the params to say so.
%
%   Why the picker cares: a blocking step cannot run on a parallel worker, and
%   until now that only surfaced after the pipeline was built and Run Analysis
%   was pressed.
%
%   See also: interactivePipelineSteps, stepRegistry, populateStepsTree

% isequal already rejects [] and 0, so no emptiness test is needed here.
always = isfield(regEntry, 'interactive') && isequal(regEntry.interactive, true);
conditional = isfield(regEntry, 'interactiveWhen') && ~isempty(regEntry.interactiveWhen);
tf = always || conditional;
end
