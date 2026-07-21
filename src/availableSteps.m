
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [steps, hidden] = availableSteps(registry)
% AVAILABLESTEPS  The steps the picker should offer on this machine.
%   [steps, hidden] = AVAILABLESTEPS() returns the registry entries a user can
%   actually select, and those withheld. A step is withheld when:
%
%     listed = false     it is not a free-standing step at all (the AARATEP
%                        orchestrator arrives only with its template)
%     unavailable        a declared requirement is unmet - most often a
%                        plugin older than the step's minVersion
%
%   Withholding is deliberate: a step that cannot run should not be offered,
%   because the alternative is a user building a pipeline around it and
%   finding out at the pre-flight. It does NOT make an unavailable step
%   invisible everywhere - a saved pipeline that references one still loads,
%   and the pre-flight blocks the run naming the step and what it needs. Being
%   unable to build a broken pipeline and being told why an existing one will
%   not run are different problems, and both want answering.
%
%   Both places that populate the step list call this - createComponents at
%   construction and startupFcn at launch - so the list cannot differ between
%   them, which it could when each dumped stepRegistry() itself.
%
%   See also: stepAvailability, tesaVersion, stepRegistry

if nargin < 1 || isempty(registry)
    registry = stepRegistry();
end

keep = true(1, numel(registry));
for i = 1:numel(registry)
    if isfield(registry(i), 'listed') && ~isempty(registry(i).listed) ...
            && ~registry(i).listed
        keep(i) = false;
        continue
    end
    % No file selection at list time, so format-specific requirements are not
    % evaluated here - they are checked at the pre-flight, when the files are
    % known.
    keep(i) = stepAvailability(registry(i));
end

steps  = registry(keep);
hidden = registry(~keep);
end
