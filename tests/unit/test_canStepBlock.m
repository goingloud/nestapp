% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_canStepBlock
% TEST_CANSTEPBLOCK  The predicate behind the step picker's amber dot.
%
%   canStepBlock answers "could this step ever wait for me?", which is what
%   the picker needs before any parameters exist. It is deliberately separate
%   from interactivePipelineSteps, which answers "will this spec block as
%   configured" and needs the params to say so.
%
%   Run: runtests('tests/unit/test_canStepBlock')
tests = functiontests(localfunctions);
end

% ── setup ─────────────────────────────────────────────────────────────────

function setupOnce(testCase) %#ok<INUSD>
r = repoRoot();
addpath(r);
addpath(fullfile(r, 'src'));
end

function r = repoRoot()
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

% ── the predicate ─────────────────────────────────────────────────────────

function test_plainStepDoesNotBlock(testCase)
[tf, always] = canStepBlock(struct('name', 'Re-Reference'));
testCase.verifyFalse(tf);
testCase.verifyFalse(always);
end

function test_interactiveFlagBlocksAlways(testCase)
[tf, always] = canStepBlock(struct('name', 'x', 'interactive', true));
testCase.verifyTrue(tf);
testCase.verifyTrue(always, 'An unconditional interactive step blocks always');
end

function test_interactiveWhenBlocksConditionally(testCase)
rule = struct('param', 'compCheck', 'values', {{'on'}});
[tf, always] = canStepBlock(struct('name', 'x', 'interactiveWhen', rule));
testCase.verifyTrue(tf, 'A step that can block in some mode must be marked');
testCase.verifyFalse(always, 'It does not block unconditionally');
end

function test_emptyFlagsDoNotBlock(testCase)
% A registry entry that carries the fields but leaves them empty - the shape
% blankStep produces - must not be marked.
testCase.verifyFalse(canStepBlock( ...
    struct('name', 'x', 'interactive', [], 'interactiveWhen', [])));
end

% ── applied to the real registry ──────────────────────────────────────────

function test_theMarkedSetIsWhatWeExpect(testCase)
% Pins which steps carry the dot. If a new interactive step appears this
% fails, which is the prompt to confirm it should be marked - not a reason to
% loosen the test.
reg = stepRegistry();
marked = {};
for k = 1:numel(reg)
    if canStepBlock(reg(k)); marked{end+1} = reg(k).name; end %#ok<AGROW>
end
expected = { ...
    'AARATEP Pipeline (whole)', ...
    'Find Artifacts EDM (TESA)', ...
    'Interactive Channel Reject (TESA)', ...
    'Remove Bad Channels (manual)', ...
    'Remove Bad Trials', ...
    'Remove ICA Components (TESA)', ...
    'Visualize EEG Data'};
testCase.verifyEqual(sort(marked), sort(expected));
end

function test_hiddenOrchestratorBlocksButIsNotOffered(testCase)
% AARATEP Pipeline (whole) blocks, but it is the hidden orchestrator: absent
% from both availableSteps and the taxonomy, so it never becomes a tree leaf
% and never carries a dot. Six steps are dotted in the picker, not seven -
% this pins the difference so the tooltip's count and the dots cannot drift.
reg = stepRegistry();
k   = find(strcmp({reg.name}, 'AARATEP Pipeline (whole)'), 1);
testCase.assertNotEmpty(k);
testCase.verifyTrue(canStepBlock(reg(k)));
testCase.verifyFalse(ismember('AARATEP Pipeline (whole)', {availableSteps().name}), ...
    'The orchestrator must stay out of the picker');

offered = {availableSteps().name};
dotted  = {};
for j = 1:numel(reg)
    if canStepBlock(reg(j)) && ismember(reg(j).name, offered)
        dotted{end+1} = reg(j).name; %#ok<AGROW>
    end
end
testCase.verifyNumElements(dotted, 6, ...
    'Exactly six offered steps should carry the amber dot');
end

function test_markedStepsAreASmallMinority(testCase)
% The dot earns its place by being rare. A marker on most rows would say
% nothing - that is why provenance (true of every step) is text, not a dot.
reg = stepRegistry();
marked = sum(arrayfun(@(r) canStepBlock(r), reg));
testCase.verifyLessThan(marked / numel(reg), 0.25, ...
    'If most steps are marked the dot has stopped carrying information');
end

function test_agreesWithInteractivePipelineStepsForAlwaysBlockers(testCase)
% The two functions answer different questions, but an always-blocking step
% must be reported by both - one from the registry entry, one from a spec.
reg  = stepRegistry();
name = 'Remove Bad Trials';
k    = find(strcmp({reg.name}, name), 1);
testCase.assertNotEmpty(k, 'fixture step missing from the registry');
testCase.verifyTrue(canStepBlock(reg(k)));

spec = struct('name', name, 'params', struct());
testCase.verifyTrue(ismember(name, interactivePipelineSteps(spec, reg)), ...
    'interactivePipelineSteps must agree for an unconditional blocker');
end
