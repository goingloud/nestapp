
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
%
%   Most of this file tests behaviour through interactivePipelineSteps - given
%   a pipeline, does it name the steps that will block? The last test is
%   deliberately a LINT over the dispatch source, not a behaviour test: the
%   only way to observe "this step blocks" at runtime is to let it block, and
%   a test that hangs is worse than no test. It is a cheap tripwire for a new
%   blocking call added without a flag, and it is fallible in both directions
%   - it cannot see blocking inside a wrapped function (which is why
%   interactiveWhen has to be declared by hand for TESA compselect).

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
                body = codeOnly(cases(i).body);
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


        function helper_finds_flagged_steps_in_a_spec(tc)
            spec = struct('name', {'Load Data', 'Visualize EEG Data', 'Re-Reference'});
            found = interactivePipelineSteps(spec, tc.registry);
            tc.verifyEqual(found, {'Visualize EEG Data'});
        end

        function helper_returns_empty_for_a_clean_spec(tc)
            spec = struct('name', {'Load Data', 'Re-Reference'});
            tc.verifyEmpty(interactivePipelineSteps(spec, tc.registry));
        end

        function compselect_blocks_only_with_manual_review_on(tc)
            % TESA compselect opens tesa_compplot and blocks on waitfor only
            % when compCheck is on. Warning about it with review off would be
            % noise; missing it with review on would hang a parallel batch.
            reg = tc.registry;
            k = find(strcmp({reg.name}, 'Remove ICA Components (TESA)'), 1);
            tc.assertNotEmpty(k);
            tc.verifyFalse(reg(k).interactive, ...
                'Not unconditionally interactive - only in manual-review mode');
            tc.verifyNotEmpty(reg(k).interactiveWhen, ...
                'Must declare the mode in which it blocks');

            on  = struct('name', 'Remove ICA Components (TESA)', ...
                         'params', struct('compCheck', 'on'));
            off = struct('name', 'Remove ICA Components (TESA)', ...
                         'params', struct('compCheck', 'off'));
            tc.verifyEqual(interactivePipelineSteps(on, reg), ...
                {'Remove ICA Components (TESA)'});
            tc.verifyEmpty(interactivePipelineSteps(off, reg));
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

function out = codeOnly(body)
% Strip whole-line comments. These scans look for calls, and a comment that
% explains why a call was REMOVED must not read as the call still being
% present - which is exactly how this test first failed: the note recording
% that pop_rejmenu had been replaced matched a search for pop_rejmenu.
lines = strsplit(body, newline);
keep  = ~startsWith(strtrim(lines), '%');
out   = strjoin(lines(keep), newline);
end
