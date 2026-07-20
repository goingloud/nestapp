
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_dispatchCoverage < matlab.unittest.TestCase
% TEST_DISPATCHCOVERAGE  Every offered step must actually run something.
%
%   The behaviour under test: if a step can be selected, dispatching it must
%   reach an implementation. A step with no implementation used to fall
%   straight through the dispatch switch and be logged as a completed step
%   having done nothing - the quietest possible failure, and how a deleted
%   `case` label went unnoticed through a full green suite.
%
%   These use the smallest fixture every step accepts: the question is
%   "does anything run for this name", not "what does it compute", and a
%   suite slow enough to skip protects nothing.
%
%   These run the real dispatch rather than reading its source. An earlier
%   version of this file searched processOneFile.m for `case` labels, which
%   passes or fails on how the code is WRITTEN rather than what it DOES: it
%   would go green for a case label that exists but is unreachable, and red
%   for a correct implementation that happened to be reorganised.

    properties
        registry
    end

    methods (TestClassSetup)
        function setup(tc)
            if ~exist('eeglab', 'file')
                tc.assumeFail('EEGLAB not on path');
            end
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            addpath(fullfile(root, 'tests', 'helpers'));
            tc.registry = stepRegistry();

            global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>
            evalc('[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab(''nogui'');');
        end
    end

    methods (Test)
        function every_registry_step_reaches_an_implementation(tc)
            % Dispatch each step and check it is not rejected as unimplemented.
            % Most will fail for their own reasons on a generic fixture -
            % wrong data shape, absent events, a plugin that wants more setup -
            % and that is fine here: any error other than nestapp:unknownStep
            % proves the step was recognised and ran.
            unimplemented = {};
            for i = 1:numel(tc.registry)
                name = tc.registry(i).name;
                if isInteractive(tc.registry(i))
                    continue   % would open a window and wait; covered elsewhere
                end
                err = dispatchOnce(tc, name);
                if ~isempty(err) && strcmp(err.identifier, 'nestapp:unknownStep')
                    unimplemented{end+1} = name; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(unimplemented, sprintf( ...
                ['These steps can be selected but nothing runs for them:\n  %s\n' ...
                 'A step with no implementation is silently skipped.'], ...
                strjoin(unimplemented, sprintf('\n  '))));
        end

        function an_unimplemented_step_is_reported_not_skipped(tc)
            % The guarantee the test above relies on, asserted directly: a step
            % name with no implementation must raise, not quietly do nothing.
            spec = struct('name', {'Load Data', 'No Such Step As This'}, ...
                          'params', {struct(), struct()});
            err = runSpec(tc, spec);
            tc.assertNotEmpty(err, ...
                'An unimplemented step completed silently - it must raise');
            % Assert the observable contract, not the identifier: the run fails
            % and the message names the step and says nothing ran for it. The
            % identifier is chosen by the error-wrapping layer above dispatch,
            % which is free to change without this behaviour changing.
            tc.verifyTrue(contains(err.message, 'No Such Step As This'), ...
                'The failure must name the offending step');
            tc.verifyTrue(contains(err.message, 'no implementation'), ...
                'The failure must say why: nothing runs for that step');
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function tf = isInteractive(step)
tf = (isfield(step, 'interactive') && ~isempty(step.interactive) && step.interactive);
end

function err = dispatchOnce(tc, name)
% Run [Load Data, <step>] on a small fixture and return the error, if any.
reg = tc.registry;
spec = [makePipelineStep('Load Data', reg), makePipelineStep(name, reg)];
err = runSpec(tc, spec);
end

function err = runSpec(tc, spec)
persistent setPath
if isempty(setPath) || ~exist(setPath, 'file')
    d = tempname; mkdir(d);
    fx = charFixture('tiny');
    evalc('pop_saveset(fx, ''filename'', ''dispatch.set'', ''filepath'', d);');
    setPath = fullfile(d, 'dispatch.set');
    tc.addTeardown(@() rmdir(d, 's'));
end
err = [];
try
    evalc(['processOneFile(spec, setPath, ' ...
           'struct(''pipelineName'',''dispatchCoverage'',''fileIndex'',1));']);
catch e
    err = e;
end
end
