% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef StepGoldenTest < NestappTestCase
% STEPGOLDENTEST  What each pipeline step currently does, pinned to a recording.
%
%   Ten steps run through the REAL dispatch - processOneFile on a saved .set -
%   and their output is digested and compared to a JSON golden recorded when
%   the step was known good. This is the only thing protecting the step layer,
%   because nothing else in the suite executes an EEGLAB step end to end.
%
%   ONE CASE PER GOLDEN. The old version looped over all ten inside a single
%   test, accumulated failures into a cell, and finished with one verifyEmpty -
%   so ten genuinely distinct behaviours reported as one result, and a run that
%   broke three steps looked exactly like a run that broke one. That is the
%   inverse of SuiteHygieneTest, where one rule over many files IS one fact;
%   here each golden is its own fact, and TestParameter is the right tool.
%
%   RE-RECORDING IS A DECISION, NOT A CHORE. recordGoldens.m says so in its own
%   header, and it is the rule that matters most in this file: a golden
%   regenerated to make a red test green throws away the only protection the
%   step layer has. If one of these fails, the question is what changed in the
%   step - not how to refresh the file.
%
%   Steps that are NOT characterized are documented with a reason in
%   characterizationCases.m - blocking dialogs, internal RNG, de-registered.
%   That list is part of the contract too: it says what this file does not
%   cover, so nobody assumes it covers everything.

    properties (TestParameter)
        % Built from the shared case table, so this file cannot drift from
        % what recordGoldens records. The parameter name is the step name,
        % which is what makes each result readable.
        goldenCase = StepGoldenTest.casesByName()
    end

    properties (Access = private)
        % Class-scoped, so the ten cases share the three .set files they save
        % between them. scratchDir teardown follows the scope that called it,
        % and TestClassSetup is the scope that makes the sharing correct.
        FixtureDir
    end

    methods (TestClassSetup)
        function eeglabIsUp(tc)
            startEeglab(tc);
            tc.FixtureDir = scratchDir(tc);
        end
    end

    methods (Test)

        function theStepStillDoesWhatItWasRecordedDoing(tc, goldenCase)
            gf = fullfile(goldenDir(), [goldenFileStem(goldenCase.name) '.json']);
            tc.assertTrue(isfile(gf), sprintf( ...
                ['no golden for "%s". Record one deliberately with ' ...
                 'recordGoldens(''%s'') - never as a reaction to a red test.'], ...
                goldenCase.name, goldenCase.name));

            expected = jsondecode(fileread(gf));
            actual   = tc.digestAfterRunning(goldenCase);

            [same, why] = digestsMatch(expected, actual);
            tc.verifyTrue(same, sprintf('%s: %s', goldenCase.name, why));
        end

        function everyGoldenOnDiskHasACaseThatUsesIt(tc)
        % An orphaned golden is a step that stopped being characterized without
        % anyone noticing - the file stays, nothing reads it, and the step is
        % silently unprotected.
            d      = dir(fullfile(goldenDir(), '*.json'));
            onDisk = strrep({d.name}, '.json', '');
            rows   = characterizationCases();
            named  = cellfun(@goldenFileStem, rows(:, 1), 'UniformOutput', false);
            tc.verifyEmpty(setdiff(onDisk, named'), ...
                'golden files with no case in characterizationCases');
        end

        function theFixturesAreReproducible(tc)
        % A precondition rather than a test of production code, and kept for
        % that reason: if charFixture stopped being deterministic, every golden
        % above would fail for a reason having nothing to do with the steps.
            for kind = {'epoched', 'epochedPulses', 'epochedTmsArtifact'}
                a = eegDigest(charFixture(kind{1}));
                b = eegDigest(charFixture(kind{1}));
                tc.verifyTrue(isequaln(a, b), sprintf( ...
                    'charFixture(''%s'') is not reproducible', kind{1}));
            end
        end
    end

    methods (Access = private)
        function d = digestAfterRunning(tc, c)
        % Build the fixture, run [Load Data, prereqs..., step] through the real
        % dispatch, digest what comes out. processOneFile operates on the
        % EEGLAB global, which is why that is where the result is read from.
            global EEG %#ok<GVMIS>

            % Named by KIND, not by step, so the ten cases share the three
            % files between them - six use epochedPulses, three epoched, one
            % epochedTmsArtifact. Each is loaded and worked on in the EEGLAB
            % globals, so sharing the input is safe.
            setPath = saveFixtureSet(tc.FixtureDir, c.kind);

            reg  = stepRegistry();
            spec = makePipelineStep('Load Data', reg);
            for j = 1:numel(c.prereqs)
                spec(end+1) = makePipelineStep(c.prereqs{j}, reg); %#ok<AGROW>
            end
            step = makePipelineStep(c.name, reg);
            for k = fieldnames(c.overrides)'
                step.params.(k{1}) = c.overrides.(k{1});
            end
            spec(end+1) = step;

            rng(42, 'twister');   % any step with a stochastic component
            evalc(['processOneFile(spec, setPath, ' ...
                   'struct(''pipelineName'', ''golden'', ''fileIndex'', 1));']);
            d = eegDigest(EEG);
        end
    end

    methods (Static, Access = private)
        function s = casesByName()
        % The case table as a TestParameter struct, keyed by a valid MATLAB
        % field name derived from the step name.
            rows = characterizationCases();
            s = struct();
            for i = 1:size(rows, 1)
                key = matlab.lang.makeValidName(rows{i, 1});
                s.(key) = struct('name', rows{i, 1}, 'kind', rows{i, 2}, ...
                                 'overrides', rows{i, 3}, 'prereqs', {rows{i, 4}});
            end
        end
    end
end

% ── file-level helpers ───────────────────────────────────────────────────────

