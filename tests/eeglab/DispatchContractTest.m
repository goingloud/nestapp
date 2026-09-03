% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef DispatchContractTest < NestappTestCase
% DISPATCHCONTRACTTEST  Every offered step runs, and none of them waits for a human.
%
%   The registry is a menu. Two things must be true of it that nothing else
%   checks: every entry on the menu reaches an implementation, and nothing on
%   it blocks a batch by opening a dialog.
%
%   BEHAVIOURAL, NOT A SOURCE SCRAPE. An earlier version of the coverage check
%   grepped processOneFile for `case` labels, and the file that replaced it
%   documented why: a scrape "passes or fails on how the code is WRITTEN rather
%   than what it DOES". A step can have a case label and still be unreachable,
%   and a step can be reachable through a shared branch with no label of its
%   own. So each step is dispatched for real, and only nestapp:unknownStep
%   counts as a failure - every other error proves the step was recognised.
%
%   Ledger row C5 is here too, because only a real run goes through
%   runPipelineCore.

    properties (Access = private)
        Registry
        ProbeSet     % one saved fixture, reused by every dispatch
        Outcomes     % containers.Map: step name -> the error it threw ([] if none)
    end

    methods (TestClassSetup)
        function dispatchEveryStepOnce(tc)
        % EVERY STEP IS DISPATCHED ONCE, HERE, and both tests below read the
        % result. An earlier version dispatched inside each test, so 55 steps
        % were run twice and the fixture was rebuilt and re-saved 110 times -
        % which is the redundant pop_saveset pattern the audit found in the old
        % suite, reproduced by me. One save, one pass.
            global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>
            evalc('[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab(''nogui'');');

            tc.Registry = stepRegistry();
            tc.assertNotEmpty(tc.Registry);

            tmp = scratchDir(tc);
            evalc(['pop_saveset(charFixture(''epochedPulses''), ' ...
                   '''filename'', ''probe.set'', ''filepath'', tmp);']);
            tc.ProbeSet = fullfile(tmp, 'probe.set');

            tc.Outcomes = containers.Map();
            for i = 1:numel(tc.Registry)
                name = tc.Registry(i).name;
                if tc.isInteractive(tc.Registry(i)); continue; end
                tc.Outcomes(name) = tc.dispatchOnce(name);
            end
        end
    end

    methods (Test)

        function everyOfferedStepReachesAnImplementation(tc)
        % A step with no implementation is silently skipped: the user picks it,
        % the run reports success, and nothing happened.
            unimplemented = {};
            for name = tc.Outcomes.keys()
                if tc.isUnimplemented(tc.Outcomes(name{1}))
                    unimplemented{end+1} = name{1}; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(unimplemented, sprintf( ...
                'these steps can be selected but nothing runs for them:\n  %s', ...
                strjoin(unimplemented, sprintf('\n  '))));
        end

        function theUnimplementedDetectorActuallyFires(tc)
        % The control the test above rests on, and it is not optional: without
        % it, "no step looked unimplemented" is satisfied by a detector that
        % never matches anything.
        %
        % That was not hypothetical. This file first tested for the identifier
        % nestapp:unknownStep, which processOneFile never raises - it catches
        % the inner error and rethrows as nestapp:stepFailed. So the coverage
        % check above would have passed for ANY registry, including one where
        % every step was unimplemented. Detecting on the message is what makes
        % it mean something.
            err = tc.dispatchOnce('No Such Step As This');
            tc.assertNotEmpty(err, 'an unknown step completed silently');
            tc.verifyTrue(tc.isUnimplemented(err), ...
                'the detector must recognise a step with no implementation');
        end

        function noStepFlaggedNonInteractiveOpensADialog(tc)
        % The batch runs unattended. A step that prompts stops the whole run at
        % a window nobody is watching, and the file it was processing is the
        % one nobody finds out about.
            blocked = {};
            for name = tc.Outcomes.keys()
                if tc.looksLikeAPrompt(tc.Outcomes(name{1}))
                    blocked{end+1} = name{1}; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(blocked, sprintf( ...
                'these steps are not flagged interactive but wait for input:\n  %s', ...
                strjoin(blocked, sprintf('\n  '))));
        end

        function theVendoredAaratepHelpersResolve(tc)
        % The AARATEP steps call c_* functions from a vendored tree that is not
        % on the path until ensureAaratepOnPath adds it. If that stops working
        % the steps fail at run time, on a real file, in a batch.
            ensureAaratepOnPath();
            missing = {};
            for f = {'c_TMSEEG_findTMSPulses', 'c_TMSEEG_Preprocess_AARATEPPipeline'}
                if isempty(which(f{1})); missing{end+1} = f{1}; end %#ok<AGROW>
            end
            tc.verifyEmpty(missing, sprintf('vendored AARATEP helper missing: %s', ...
                                            strjoin(missing, ', ')));
        end

        % ── ledger C5 ────────────────────────────────────────────────────────

        function theLayoutOverrideBeatsTheUserPreference(tc)
        % Ledger C5. runPipelineCore had an override for outputRoot and none
        % for its twin, so a test that carefully isolated the root still
        % inherited whichever layout the user last chose in Preferences - and
        % failed five ways on a machine set to perInput while the run itself
        % was entirely correct.
            tmp = scratchDir(tc);
            tc.runTinyPipeline(tmp, 'perInput');

            batchRoot = tc.soleBatchFolder(tmp);
            tc.verifyTrue(isfolder(fullfile(batchRoot, '_batch')), ...
                'perInput puts batch artifacts in _batch');
            tc.verifyFalse(isfolder(fullfile(batchRoot, 'batch')), ...
                'and not where typeBased would');
        end

        function theSameRunUnderTypeBasedLandsSomewhereElse(tc)
        % The control. Without it the test above passes for an override that is
        % ignored, as long as the machine happens to be set to perInput.
            tmp = scratchDir(tc);
            tc.runTinyPipeline(tmp, 'typeBased');

            batchRoot = tc.soleBatchFolder(tmp);
            tc.verifyTrue(isfolder(fullfile(batchRoot, 'batch')));
            tc.verifyFalse(isfolder(fullfile(batchRoot, '_batch')));
        end
    end

    % ── machinery ────────────────────────────────────────────────────────────
    methods (Access = private)

        function err = dispatchOnce(tc, name)
        % Run [Load Data, <step>] on a generic fixture and hand back whatever
        % it threw. Most steps fail for their own reasons here - wrong data
        % shape, no events, a plugin wanting more setup - and that is fine:
        % any error but nestapp:unknownStep proves the step was recognised.
            err = [];
            try
                tc.runSpec(tc.specFor(name));
            catch e
                err = e;
            end
        end

        function tf = isUnimplemented(~, err)
        % processOneFile catches the dispatch error and rethrows it wrapped as
        % nestapp:stepFailed, so the identifier alone cannot distinguish "no
        % implementation" from "the step ran and failed on this fixture" -
        % which is the whole distinction this file rests on. The inner message
        % is what carries it.
            tf = ~isempty(err) && contains(err.message, 'has no implementation');
        end

        function tf = looksLikeAPrompt(~, err)
        % A prompt in a headless session errors rather than blocking, so the
        % check is on the error a blocked dialog raises - not on a timeout.
        % Reads the outcome collected once in setup rather than dispatching
        % again.
            tf = ~isempty(err) && ( ...
                 contains(lower(err.message), 'inputdlg') || ...
                 contains(lower(err.message), 'uiconfirm') || ...
                 contains(lower(err.message), 'waiting for input'));
        end

        function spec = specFor(tc, name)
            reg = tc.Registry;
            if any(strcmp({reg.name}, name))
                spec = [makePipelineStep('Load Data', reg), ...
                        makePipelineStep(name, reg)];
            else
                % An unknown name has no registry entry to build from, so the
                % spec is assembled by hand - which is the only way to ask
                % what the dispatch does with a step it has never heard of.
                spec = struct('name', {'Load Data', name}, ...
                              'params', {struct(), struct()});
            end
        end

        function runSpec(tc, spec)
            evalc(['processOneFile(spec, tc.ProbeSet, ' ...
                   'struct(''pipelineName'', ''dispatch'', ''fileIndex'', 1));']);
        end

        function runTinyPipeline(tc, outRoot, layout)
        % Two steps, so the run completes and writes its batch artifacts.
            reg   = tc.Registry;
            fname = 'layout_probe.set';
            evalc('pop_saveset(charFixture(''tiny''), ''filename'', fname, ''filepath'', outRoot);');
            spec  = [makePipelineStep('Load Data', reg), ...
                     makePipelineStep('Save New Set', reg)];
            opts  = struct('uiFigure', [], 'pipelineName', 'layout-probe', ...
                           'statusBar', [], 'parallel', false, 'chanLocFile', '', ...
                           'outputRoot', outRoot, 'layout', layout);
            evalc('runPipelineCore(spec, {fullfile(outRoot, fname)}, opts);');
        end

        function p = soleBatchFolder(tc, outRoot)
        % The one timestamped folder the run just made, ignoring the .set the
        % probe wrote alongside it.
            d = dir(outRoot);
            d = d([d.isdir] & ~startsWith({d.name}, '.'));
            tc.assertNumElements(d, 1, 'expected exactly one batch folder');
            p = fullfile(outRoot, d(1).name);
        end

        function tf = isInteractive(~, entry)
            tf = isfield(entry, 'interactive') && ~isempty(entry.interactive) ...
                 && entry.interactive;
        end
    end
end
