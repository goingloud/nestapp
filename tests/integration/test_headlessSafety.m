
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_headlessSafety < matlab.unittest.TestCase
% TEST_HEADLESSSAFETY  Without a UI, a step must fail - never wait.
%
%   The behaviour under test, from the caller's side: run a step under the
%   conditions a parallel worker sees (uiFigure = []) and it must return or
%   raise. A step that prompts there blocks a batch that is already running,
%   with no window to answer and nothing in the log to explain it.
%
%   Re-Reference is the case that mattered: it prompted with inputdlg when the
%   configured reference channel was absent. That is an error path, so
%   flagging the whole step interactive would have warned on the many
%   pipelines that use it correctly - it needed a guard, not a flag.
%
%   This runs the real pipeline rather than checking that a guard appears
%   before a call in the source. The source ordering is one way to get this
%   right; the behaviour is the requirement.

    properties
        setPath
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
            global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>
            evalc('[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab(''nogui'');');

            d = tempname; mkdir(d);
            fx = charFixture('epoched');
            evalc('pop_saveset(fx, ''filename'', ''hl.set'', ''filepath'', d);');
            tc.setPath = fullfile(d, 'hl.set');
            tc.addTeardown(@() rmdir(d, 's'));
        end
    end

    methods (Test)
        function reReference_to_a_missing_channel_fails_without_a_ui(tc)
            % The fixture montage has no channel called 'NOSUCHCHAN'. With no
            % UI the step must raise rather than open a dialog nobody can see.
            reg  = stepRegistry();
            step = makePipelineStep('Re-Reference', reg);
            step.params.ref = 'NOSUCHCHAN';
            spec = [makePipelineStep('Load Data', reg), step];

            err = [];
            try
                evalc(['processOneFile(spec, tc.setPath, ' ...
                       'struct(''pipelineName'',''headless'',''fileIndex'',1,''uiFigure'',[]));']);
            catch e
                err = e;
            end

            tc.assertNotEmpty(err, ...
                'Re-Reference to a missing channel must fail without a UI, not prompt');
            tc.verifyTrue(contains(err.message, 'NOSUCHCHAN'), ...
                'The failure must name the reference that could not be resolved');
            tc.verifyTrue(contains(lower(err.message), 'available') || ...
                          contains(err.message, 'Cz'), ...
                'The failure should list the channels that ARE present, so it is actionable');
        end

        function reReference_to_a_present_channel_still_works(tc)
            % The guard must not have broken the ordinary path.
            reg  = stepRegistry();
            step = makePipelineStep('Re-Reference', reg);
            step.params.ref = 'Cz';
            spec = [makePipelineStep('Load Data', reg), step];

            err = [];
            try
                evalc(['processOneFile(spec, tc.setPath, ' ...
                       'struct(''pipelineName'',''headless'',''fileIndex'',1,''uiFigure'',[]));']);
            catch e
                err = e;
            end
            tc.verifyEmpty(err, 'Re-referencing to a channel that exists must succeed');
        end
    end
end
