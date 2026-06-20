
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function body = pipelineProse(report)
% PIPELINEPROSE  Ordered methods-paragraph body for a single report's pipeline.
%   body = PIPELINEPROSE(report) walks report.steps in run order, turns each
%   into a clause via methodsClause, drops empties and exact-duplicate clauses
%   (so a step repeated with identical settings is stated once), and returns a
%   punctuated string of sentences. Returns '' when no step carries parameters
%   (e.g. a legacy report saved before stepRec.params existed), which lets the
%   callers fall back to an outcomes-only sentence.
%
%   The text is generated from the report's own parameters - it copies no
%   external source. See methodsClause for the per-step wording.
%
%   See also: methodsClause, methodsNarrative, methodsParagraphAggregate

    body = '';
    if ~isfield(report, 'steps') || isempty(report.steps)
        return
    end
    steps   = report.steps;
    clauses = {};
    seen    = {};                 % exact-duplicate suppression
    firstTmsWin = '';             % so a re-cut at the same window is not repeated

    for i = 1:numel(steps)
        s = steps{i};
        if ~isstruct(s) || ~isfield(s, 'name') || ~isfield(s, 'params')
            continue            % legacy record without params - skip
        end

        % TMS artifact re-cuts: state the window once; if a later cut widens it,
        % say so instead of repeating the whole sentence.
        if strcmp(s.name, 'Remove TMS Artifacts (TESA)') ...
                && isfield(s.params, 'cutTimesTMS') && numel(s.params.cutTimesTMS) >= 2
            win = sprintf('%g to %g', s.params.cutTimesTMS(1), s.params.cutTimesTMS(2));
            if isempty(firstTmsWin)
                firstTmsWin = win;
                c = methodsClause(s.name, s.params);
            elseif ~strcmp(win, firstTmsWin)
                c = sprintf('the artifact-removal window was later extended to %s ms', win);
                firstTmsWin = win;
            else
                c = '';
            end
        else
            c = methodsClause(s.name, s.params);
        end

        if isempty(c) || any(strcmp(c, seen))
            continue
        end
        seen{end+1}    = c;   %#ok<AGROW>
        clauses{end+1} = c;   %#ok<AGROW>
    end

    if isempty(clauses)
        return
    end
    for i = 1:numel(clauses)
        clauses{i} = [upper(clauses{i}(1)), clauses{i}(2:end)];
    end
    body = [strjoin(clauses, '. '), '.'];
end
