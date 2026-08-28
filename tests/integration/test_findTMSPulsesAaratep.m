% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_findTMSPulsesAaratep
% TEST_FINDTMSPULSESAARATEP  AARATEP's own pulse detector, as a nestapp step.
%
%   Upstream ships c_TMSEEG_findTMSPulses but never calls it - its pipeline
%   assumes the events already exist. This wires it up as a step so the AARATEP
%   template can detect with the same toolbox it cleans with.
%
%   Beyond "does it find pulses": the events must be labelled 'TMS', because
%   upstream would write 'Pulse' and the orchestrator matches pulseEvents by
%   type - a mismatch there means it epochs on nothing. And minNumPulses must
%   stay unexposed, since below that count upstream can reach a `keyboard`
%   that would hang a headless run.
%
%   Run: runtests('tests/integration/test_findTMSPulsesAaratep')
tests = functiontests(localfunctions);
end

% -- fixture --------------------------------------------------------------

function setupOnce(testCase)
r = repoRoot();
addpath(r);
addpath(genpath(fullfile(r, 'src')));
if isempty(which('eeg_emptyset'))
    testCase.assumeFail('EEGLAB not on path');
end
ensureAaratepOnPath();
if isempty(which('c_TMSEEG_findTMSPulses'))
    testCase.assumeFail('Vendored AARATEP not available');
end
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

function EEG = pulsedEEG(nPulses, srate)
% Continuous data with unmistakable synchronous artifacts. The detector needs
% more than a quarter of channels supra-threshold at the same sample, so every
% channel spikes together at each pulse.
nChan = 16;
nPnts = (nPulses + 1) * srate;
rng(7, 'twister');
EEG = eeg_emptyset();
EEG.nbchan = nChan;
EEG.pnts   = nPnts;
EEG.trials = 1;
EEG.srate  = srate;
EEG.xmin   = 0;
EEG.xmax   = (nPnts - 1) / srate;
EEG.times  = (0:nPnts-1) / srate * 1000;
EEG.data   = single(randn(nChan, nPnts) * 5);
for k = 1:nPulses
    EEG.data(:, k * srate) = single(6000);   % well over minPulseThreshold
end
for k = 1:nChan
    EEG.chanlocs(k).labels = sprintf('E%d', k);
end
EEG = eeg_checkset(EEG);
end

function outEEG = detectVia(testCase, EEG, varargin)
% Run the step through processOneFile - the real dispatch path - and read the
% result back off disk, since processOneFile returns a report, not an EEG.
dir_ = fullfile(tempdir, ['nestapp_fp_', char(matlab.lang.internal.uuid())]);
mkdir(dir_);
testCase.addTeardown(@() rmdir(dir_, 's'));
evalc('pop_saveset(EEG, ''filename'', ''in.set'', ''filepath'', dir_);');

reg    = stepRegistry();
loader = makePipelineStep('Load Data', reg);
spec   = makePipelineStep('Find TMS Pulses (AARATEP)', reg);
for k = 1:2:numel(varargin)
    spec.params.(varargin{k}) = varargin{k+1};
end
saver = makePipelineStep('Save New Set', reg);
saver.params.savenew = 'detected';

opts = struct('uiFigure', [], 'pipelineName', 'test', 'statusBar', [], ...
              'parallel', false, 'chanLocFile', '', 'fileIndex', 1, ...
              'batchCtx', buildBatchContext({fullfile(dir_, 'in.set')}, 'test', ...
                                            'typeBased', dir_));
processOneFile([loader, spec, saver], fullfile(dir_, 'in.set'), opts);

hits = dir(fullfile(dir_, '**', '*detected*.set'));
testCase.assertNotEmpty(hits, 'the saved dataset should exist');
outEEG = pop_loadset('filename', hits(1).name, 'filepath', hits(1).folder);
end

% -- detection ------------------------------------------------------------

function test_detectsThePulsesAndLabelsThemTMS(testCase)
out = detectVia(testCase, pulsedEEG(8, 1000));
types = {out.event.type};
testCase.verifyEqual(sum(strcmp(types, 'TMS')), 8, 'one event per pulse');
testCase.verifyFalse(any(strcmp(types, 'Pulse')), ...
    'Must use nestapp''s TMS label, not upstream''s Pulse default');
end

function test_worksOnARecordingWithNoEventsAtAll(testCase)
% The detector's whole purpose, and upstream cannot do it unaided: it builds
% its events with c_struct_createEmptyCopy(EEG.event), which asserts isstruct,
% while EEGLAB leaves EEG.event as [] when there are no events. The dispatch
% seeds the struct so this case works.
EEG = pulsedEEG(6, 1000);
EEG.event = [];
testCase.assertFalse(isstruct(EEG.event), 'fixture must have no events');

out = detectVia(testCase, EEG);
testCase.verifyEqual(sum(strcmp({out.event.type}, 'TMS')), 6);
end

function test_eventLabelIsConfigurable(testCase)
out = detectVia(testCase, pulsedEEG(5, 1000), 'addEventsOfType', 'ZAP');
testCase.verifyEqual(sum(strcmp({out.event.type}, 'ZAP')), 5);
end

function test_epochedDataIsRefusedWithAnActionableMessage(testCase)
EEG = pulsedEEG(4, 1000);
EEG = eeg_regepochs(EEG, 'recurrence', 1, 'limits', [-0.2 0.4]);
testCase.assertGreaterThan(EEG.trials, 1, 'fixture should be epoched');

% processOneFile wraps a failing step as nestapp:stepFailed, so the check is
% on the message: it has to say what is wrong AND what to do about it.
msg = '';
try
    detectVia(testCase, EEG);
catch err
    msg = err.message;
end
testCase.assertNotEmpty(msg, 'Epoched data should have been refused');
testCase.verifyTrue(contains(msg, 'continuous'), ...
    'The message must say the step needs continuous data');
testCase.verifyTrue(contains(msg, 'before Epoching'), ...
    'and must name the fix');
end

% -- wiring ---------------------------------------------------------------

function test_templateDetectsWhatTheOrchestratorEpochsOn(testCase)
% The whole reason the label is overridden: detection and cleaning have to
% agree on the event type, or the orchestrator epochs on nothing.
S = load(fullfile(repoRoot(), 'src', 'templates', '4_aaratep.mat'));
names = {S.spec.name};
testCase.verifyTrue(ismember('Find TMS Pulses (AARATEP)', names), ...
    'The template should use upstream''s own detector');

detector     = S.spec(strcmp(names, 'Find TMS Pulses (AARATEP)'));
orchestrator = S.spec(strcmp(names, 'AARATEP Pipeline (whole)'));
testCase.verifyTrue(ismember(detector.params.addEventsOfType, ...
    cellstr(orchestrator.params.pulseEvents)), sprintf( ...
    'Detector writes "%s" but the orchestrator epochs on "%s"', ...
    detector.params.addEventsOfType, ...
    strjoin(cellstr(orchestrator.params.pulseEvents), ',')));

testCase.verifyLessThan(find(strcmp(names, 'Find TMS Pulses (AARATEP)')), ...
    find(strcmp(names, 'AARATEP Pipeline (whole)')), ...
    'Detection has to come first');
end

function test_minNumPulsesIsNotOffered(testCase)
% Upstream calls `keyboard` when it cannot reach minNumPulses, which would drop
% a headless run into the debugger. Leaving the control out is what keeps that
% branch unreachable - a deliberate omission, not an oversight.
reg = stepRegistry();
k   = find(strcmp({reg.name}, 'Find TMS Pulses (AARATEP)'), 1);
testCase.assertNotEmpty(k);
testCase.verifyFalse(isfield(reg(k).defaults, 'minNumPulses'), ...
    'minNumPulses must stay unexposed - it can reach a keyboard call');
testCase.verifyFalse(ismember('minNumPulses', {reg(k).params.key}));
end

function test_bothDetectorsAreOfferedTogether(testCase)
TAX = stepTaxonomy();
variants = {};
for c = 1:numel(TAX)
    for o = 1:numel(TAX(c).ops)
        if strcmp(TAX(c).ops(o).name, 'Find TMS Pulses')
            variants = {TAX(c).ops(o).variants.step};
        end
    end
end
testCase.verifyTrue(ismember('Find TMS Pulses (AARATEP)', variants));
testCase.verifyTrue(ismember('Find TMS Pulses (TESA)', variants), ...
    'The TESA detector stays available as the alternative');
end
