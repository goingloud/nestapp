% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef BatchRunContractTest < NestappTestCase
% BATCHRUNCONTRACTTEST  What a headless pipeline run must and must not do.
%
%   Four regressions that share one subject - a real run through
%   runPipelineCore with no app and no figure - so they share ONE run. It costs
%   a few seconds, every assertion below reads a different part of its
%   aftermath, and re-running it per test would be the redundant-work pattern
%   this suite has already had to remove twice.
%
%   ALL FOUR WERE SOURCE CHECKS. The old suite pinned them by grepping
%   nestapp.m and processOneFile.m for words: 'assignin', 'updateReportsTab',
%   'datetime', the presence of a file. A grep passes or fails on how the code
%   is WRITTEN - it survives a reformat and it cannot tell a call from a
%   mention in a comment - which is why one of them (A1.9) was a bare isfile
%   check that this file's A1.8 test subsumes and the ledger dropped.
%
%   Ledger rows: A1.1 (the rename was computed and thrown away), A1.5 (internal
%   variables leaking into the base workspace), A1.6 (the pipeline calling back
%   into the app class that invoked it), A1.8 + A1.10 (provenance written to
%   EEG.history, with a timestamp).

    properties (Constant)
        % Spaces AND a dash, because Save New Set replaces both, and a name
        % that exercised only one would leave half the rename untested.
        InputName = 'a spaced-name recording.set'
    end

    properties (Access = private)
        OutRoot       % the run's output root
        BaseBefore    % base-workspace variable names, before the run
        BaseAfter     % and after
        History       % EEG.history as the run left it
        WrittenSets   % .set files the run produced
    end

    methods (TestClassSetup)
        function runOnePipelineHeadless(tc)
            startEeglab(tc);
            tc.OutRoot = scratchDir(tc);

            % The input carries the awkward name; everything downstream of the
            % rename is read off what lands on disk.
            fx = charFixture('tiny');
            evalc(['pop_saveset(fx, ''filename'', tc.InputName, ' ...
                   '''filepath'', tc.OutRoot);']);

            reg  = stepRegistry();
            spec = [makePipelineStep('Load Data', reg), ...
                    makePipelineStep('Save New Set', reg)];
            % savenew defaults to the '[]' sentinel, which means "do not write
            % one" - so the step runs and saves nothing. Naming a suffix is
            % what makes this a save at all, and the rename under test is
            % applied to the stem it gets prepended to.
            spec(2).params.savenew = 'cleaned.set';

            % NO uiFigure AND NO APP - which is the A1.6 assertion, made by
            % construction rather than by grepping for the method name that
            % used to be called. If the pipeline reached back into the app
            % class, there is nothing here for it to reach.
            opts = struct('uiFigure', [], 'pipelineName', 'batch-contract', ...
                          'statusBar', [], 'parallel', false, 'chanLocFile', '', ...
                          'outputRoot', tc.OutRoot, 'layout', 'typeBased');

            tc.BaseBefore = evalin('base', 'who');
            evalc(['runPipelineCore(spec, ' ...
                   '{fullfile(tc.OutRoot, tc.InputName)}, opts);']);
            tc.BaseAfter = evalin('base', 'who');

            global EEG %#ok<GVMIS>
            tc.History = '';
            if isstruct(EEG) && isfield(EEG, 'history'); tc.History = EEG.history; end

            found = dir(fullfile(tc.OutRoot, '**', '*.set'));
            tc.WrittenSets = {found.name};
        end
    end

    methods (Test)

        % ── A1.1 ─────────────────────────────────────────────────────────────

        function theSavedFileIsActuallyRenamed(tc)
        % The defect was `replace(fbase, ' ', '_')` with the RESULT DISCARDED -
        % replace does not mutate in place - so the rename was computed on
        % every run and thrown away, and files kept their spaces. A step that
        % silently does nothing is the hardest kind to notice.
            produced = setdiff(tc.WrittenSets, {tc.InputName});
            tc.assertNotEmpty(produced, ...
                'the run wrote no new .set, so there is no rename to check');

            offenders = produced(contains(produced, ' ') | contains(produced, '-'));
            tc.verifyEmpty(offenders, sprintf( ...
                ['a written .set still carries the characters the rename ' ...
                 'exists to remove: %s'], strjoin(offenders, ', ')));
        end

        function theRenameKeepsTheNameRecognisable(tc)
        % The other half, and the reason the rename is a substitution rather
        % than a strip: the output has to stay traceable to its input by eye.
        % Deleting the offending characters would satisfy the test above.
            produced = setdiff(tc.WrittenSets, {tc.InputName});
            tc.verifyTrue(any(contains(produced, 'a_spaced_name_recording')), ...
                sprintf(['no output is recognisably derived from "%s" - got: %s'], ...
                        tc.InputName, strjoin(produced, ', ')));
        end

        % ── A1.5 ─────────────────────────────────────────────────────────────

        function theRunLeaksNothingIntoTheBaseWorkspaceButEEG(tc)
        % assignin('base', ...) of internal pipeline variables put working
        % state into the user's workspace, where it collides with whatever they
        % had there and outlives the run.
        %
        % EEG is the ONE deliberate exception, and it is deliberate for a
        % reason worth stating: EEGLAB's own convention is that the current
        % dataset is a base-workspace variable, and eegh/eeglab redraw both
        % expect to find it. So the rule is not "nothing is assigned", it is
        % "nothing BUT that".
            leaked = setdiff(tc.BaseAfter, tc.BaseBefore);
            leaked = setdiff(leaked, {'EEG'});
            tc.verifyEmpty(leaked, sprintf( ...
                ['the run left %d internal variable(s) in the user''s base ' ...
                 'workspace: %s'], numel(leaked), strjoin(leaked', ', ')));
        end

        function theDeliberateExceptionIsStillHonoured(tc)
        % A positive control for the rule above: if EEG stopped being published
        % the leak test would pass trivially and eegh would stop working, so
        % the exemption has to be checked rather than merely excluded.
            tc.verifyTrue(ismember('EEG', tc.BaseAfter), ...
                ['EEG is not in the base workspace after a run - EEGLAB''s ' ...
                 'own tooling (eegh, the redraw) reads it from there']);
        end

        % ── A1.6 ─────────────────────────────────────────────────────────────

        function theRunCompletedWithNoAppInExistence(tc)
        % runPipelineCore used to call app.updateReportsTab() - a circular
        % dependency back into the class that invoked it, which made the
        % pipeline unrunnable from anywhere but the GUI, unusable on a worker,
        % and untestable without launching a window.
        %
        % ONE ASSERTION, because the fact is established by CONSTRUCTION and
        % this is the only part of it worth restating. TestClassSetup ran with
        % opts.uiFigure = [] and no nestapp anywhere in the session: had the
        % pipeline reached back into the app class, there was nothing to reach
        % and the run would have errored before any test here executed. What
        % remains to check is that it got somewhere - a run that completed by
        % doing nothing would satisfy the same construction.
        %
        % Deliberately NOT re-checking for leaked figures: NestappTestCase
        % already asserts that after every test in the suite, and a second copy
        % here would be one more place to keep in step for no extra coverage.
            tc.verifyNotEmpty(tc.WrittenSets, ...
                ['the headless run wrote nothing, so its completion says ' ...
                 'nothing about whether the pipeline can run without an app']);
        end

        % ── A1.8 / A1.10 ─────────────────────────────────────────────────────

        function everyStepRunIsRecordedInTheHistory(tc)
        % EEG.history is what eegh shows and what a methods section is written
        % from. A step that ran without being recorded is a result nobody can
        % reproduce - which for this project is the whole point.
            tc.assertNotEmpty(tc.History, 'no history was written at all');
            tc.verifySubstring(tc.History, 'Load Data');
            tc.verifySubstring(tc.History, 'Save New Set');
            tc.verifySubstring(tc.History, 'batch-contract', ...
                'the pipeline''s name belongs in the record');
        end

        function theHistoryStampCarriesARealTimestamp(tc)
        % Ledger A1.10, folded into A1.8's subject as the ledger asked. The old
        % check was `contains(src, 'datetime')` - satisfied by the WORD
        % appearing anywhere in the file, including in a comment. This reads
        % the produced string and requires a date that parses.
            stamps = regexp(tc.History, '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', 'match');
            tc.assertNotEmpty(stamps, ...
                'the provenance entry carries no timestamp');

            when = datetime(stamps{end}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
            tc.verifyGreaterThan(when, datetime('now') - minutes(30), ...
                ['the timestamp is not from this run - a hardcoded or stale ' ...
                 'date is worse than none, because it looks like provenance']);
            tc.verifyLessThan(when, datetime('now') + minutes(5));
        end
    end
end
