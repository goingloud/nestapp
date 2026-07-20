
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_interactiveSteps < matlab.unittest.TestCase
% TEST_INTERACTIVESTEPS  Steps that wait for a human must be identifiable.
%
%   A step that opens a modal, a rejection menu, or a plot the user closes
%   cannot run on a parallel worker: workers are handed uiFigure = [] and have
%   no display, so the run errors on every file or blocks with nothing to
%   click - and only after the batch has started. The app checks this before a
%   run and offers to turn parallel off, which only works if every such step
%   is flagged.

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
        function known_blocking_steps_are_flagged(tc)
            for name = {'Visualize EEG Data', 'Remove Bad Trials'}
                k = find(strcmp({tc.registry.name}, name{1}), 1);
                tc.assertNotEmpty(k, sprintf('%s missing from registry', name{1}));
                tc.verifyTrue(tc.registry(k).interactive, ...
                    sprintf('%s blocks on user input and must be flagged interactive', name{1}));
            end
        end

        function every_step_defines_the_flag(tc)
            missing = {};
            for i = 1:numel(tc.registry)
                if ~isfield(tc.registry(i), 'interactive') || isempty(tc.registry(i).interactive)
                    missing{end+1} = tc.registry(i).name; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(missing, sprintf('Steps with no interactive flag:\n  %s', ...
                strjoin(missing, sprintf('\n  '))));
        end

        function no_unflagged_step_blocks_on_user_input(tc)
            % Scan each dispatch case for calls that wait for a human. A step
            % that blocks but is not flagged is exactly the case that hangs a
            % batch, so this guards against adding one.
            blockingCalls = {'uiconfirm', 'pop_rejmenu', 'inputdlg', ...
                             'questdlg', 'uiwait', 'keyboard'};
            flagged = {tc.registry([tc.registry.interactive]).name};
            offenders = {};
            cases = splitDispatchCases(tc.dispatchSrc);
            for i = 1:numel(cases)
                body = cases(i).body;
                names = cases(i).names;
                if any(cellfun(@(c) contains(body, [c '(']), blockingCalls))
                    for j = 1:numel(names)
                        if ~ismember(names{j}, flagged)
                            offenders{end+1} = names{j}; %#ok<AGROW>
                        end
                    end
                end
            end
            % Re-Reference prompts only when the configured reference channel
            % is absent, and now errors instead when there is no UI - so it
            % cannot block a worker and is deliberately not flagged.
            offenders = setdiff(offenders, {'Re-Reference'});
            tc.verifyEmpty(offenders, sprintf( ...
                ['These dispatch cases block on user input but are not flagged\n' ...
                 'interactive, so a parallel run would hang on them:\n  %s'], ...
                strjoin(unique(offenders), sprintf('\n  '))));
        end

        function reReference_errors_instead_of_prompting_without_a_ui(tc)
            % The guard must come BEFORE the inputdlg, or a worker still hangs.
            body = dispatchBody(tc.dispatchSrc, 'Re-Reference');
            tc.assertNotEmpty(body, 'Re-Reference case not found');
            iGuard  = strfind(body, 'isempty(opts.uiFigure)');
            iPrompt = strfind(body, 'inputdlg(');
            tc.verifyNotEmpty(iGuard, 'Re-Reference must check for a UI before prompting');
            tc.verifyNotEmpty(iPrompt);
            tc.verifyLessThan(iGuard(1), iPrompt(1), ...
                'The no-UI guard must precede the inputdlg call');
        end

        function helper_finds_flagged_steps_in_a_spec(tc)
            spec = struct('name', {'Load Data', 'Visualize EEG Data', 'Re-Reference'});
            found = interactivePipelineSteps(spec, tc.registry);
            tc.verifyEqual(found, {'Visualize EEG Data'});
        end

        function helper_returns_empty_for_a_clean_spec(tc)
            spec = struct('name', {'Load Data', 'Re-Reference'});
            tc.verifyEmpty(interactivePipelineSteps(spec, tc.registry));
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function cases = splitDispatchCases(src)
% Split the dispatch switch into (names, body) per case label.
starts = regexp(src, '\n            case [^\n]*', 'start');
labels = regexp(src, '\n            case ([^\n]*)', 'tokens');
cases = struct('names', {}, 'body', {});
for i = 1:numel(starts)
    if i < numel(starts); stop = starts(i+1); else; stop = numel(src); end
    q = regexp(labels{i}{1}, '''([^'']+)''', 'tokens');
    cases(i).names = cellfun(@(t) t{1}, q, 'UniformOutput', false);
    cases(i).body  = src(starts(i):stop);
end
end

function body = dispatchBody(src, name)
cases = splitDispatchCases(src);
body = '';
for i = 1:numel(cases)
    if ismember(name, cases(i).names); body = cases(i).body; return; end
end
end
