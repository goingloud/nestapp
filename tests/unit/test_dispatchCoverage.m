
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_dispatchCoverage < matlab.unittest.TestCase
% TEST_DISPATCHCOVERAGE  Every registry step must have a dispatch case.
%
%   Regression: deleting a block of steps from processOneFile's switch took
%   one line too many and removed a neighbouring `case` label. The orphaned
%   body silently became a continuation of the PREVIOUS case, so one step lost
%   its dispatch entirely and another gained code that was never meant to run
%   in it. The full suite stayed green, because neither step had a test.
%
%   That is the failure mode this file exists to make impossible: the registry
%   and the dispatch are two lists that must agree, maintained by hand in two
%   files, and nothing checked that they did.

    properties
        registry
        dispatchSrc
    end

    methods (TestClassSetup)
        function load(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            tc.registry    = stepRegistry();
            tc.dispatchSrc = fileread(fullfile(root, 'src', 'processOneFile.m'));
        end
    end

    methods (Test)
        function every_registry_step_has_a_dispatch_case(tc)
            missing = {};
            for i = 1:numel(tc.registry)
                name = tc.registry(i).name;
                if isempty(dispatchCaseFor(tc.dispatchSrc, name))
                    missing{end+1} = name; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(missing, sprintf( ...
                ['Registry steps with no case in processOneFile''s switch:\n  %s\n' ...
                 'A step without a dispatch case cannot run.'], ...
                strjoin(missing, sprintf('\n  '))));
        end

        function every_dispatch_case_has_a_registry_step(tc)
            % The reverse direction: a case for a step nobody can select is
            % dead code, and usually the residue of an incomplete removal.
            cases  = allDispatchCaseNames(tc.dispatchSrc);
            known  = {tc.registry.name};
            % Legacy names are legitimate: canonicalStepName migrates old saved
            % pipelines onto current names, and the dispatch still answers to
            % the pre-migration spelling as a safety net.
            for k = 1:numel(cases)
                cases{k} = canonicalStepName(cases{k});
            end
            orphans = setdiff(unique(cases), known);
            tc.verifyEmpty(orphans, sprintf( ...
                'Dispatch cases with no registry step:\n  %s', ...
                strjoin(orphans, sprintf('\n  '))));
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function idx = dispatchCaseFor(src, name)
% Match both `case 'Name'` and `case {'A', 'Name'}` groupings.
q = regexptranslate('escape', ['''' name '''']);
idx = regexp(src, ['case\s*\{?[^\n]*' q], 'once');
end

function names = allDispatchCaseNames(src)
% Every quoted string appearing in a `case ...` line of the dispatch switch.
lines = regexp(src, '\n\s*case\s+[^\n]*', 'match');
names = {};
for i = 1:numel(lines)
    q = regexp(lines{i}, '''([^'']+)''', 'tokens');
    for j = 1:numel(q)
        names{end+1} = q{j}{1}; %#ok<AGROW>
    end
end
end
