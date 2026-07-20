
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_methodsClause
% TEST_METHODSCLAUSE  Unit tests for the per-step methods-prose clause map.
%
%   methodsClause(stepName, params) returns one journal-style clause carrying
%   only the methods-relevant parameter values, or '' for steps that do not
%   belong in a methods paragraph. These tests pin the curated wording/values
%   and the omissions.
%
%   Run: runtests('tests/unit/test_methodsClause')
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r); addpath(fullfile(r, 'src'));
end

% ── windows / resampling / baseline ───────────────────────────────────────────

function test_epoching_windowInMs(testCase)
c = methodsClause('Epoching', struct('timelim', [-1 1], 'types', {{'TMS'}}));
testCase.verifyTrue(contains(c, 'epoch'));
testCase.verifyTrue(contains(c, '-1000 to 1000 ms'));        % seconds -> ms
testCase.verifyTrue(contains(c, 'TMS pulse'));
end

function test_epoching_nonTmsSaysEvent(testCase)
c = methodsClause('Epoching', struct('timelim', [-0.2 0.8], 'types', {{}}));
testCase.verifyTrue(contains(c, '-200 to 800 ms'));
testCase.verifyTrue(contains(c, 'each event'));
end

function test_baseline_shortWindowIsBaselineCorrection(testCase)
c = methodsClause('Remove Baseline', struct('timerange', [-500 -10], 'pointrange', []));
testCase.verifyTrue(contains(c, 'baseline-corrected from -500 to -10 ms'));
end

function test_baseline_postStimWindowIsDemean(testCase)
c = methodsClause('Remove Baseline', struct('timerange', [-1000 1000], 'pointrange', []));
testCase.verifyTrue(contains(c, 'demeaned over the whole epoch'));
end

function test_removeTmsArtifacts_window(testCase)
c = methodsClause('Remove TMS Artifacts (TESA)', struct('cutTimesTMS', [-2 10]));
testCase.verifyTrue(contains(c, '(-2 to 10 ms)'));
testCase.verifyTrue(contains(c, 'removed'));
end

function test_resample_rate(testCase)
c = methodsClause('Re-Sample', struct('freq', 1000));
testCase.verifyEqual(c, 'the data were downsampled to 1000 Hz');
end

% ── bad-channel methods ───────────────────────────────────────────────────────

function test_badChannels_kurtosis(testCase)
c = methodsClause('Remove Bad Channels', struct('measure', 'kurt', 'threshold', 5));
testCase.verifyTrue(contains(c, 'kurtosis'));
testCase.verifyTrue(contains(c, '5 SD'));
end

function test_tesaFilter_bandpass(testCase)
c = methodsClause('Frequency Filter (TESA)', ...
    struct('type', 'bandpass', 'high', 1, 'low', 80, 'ord', 4));
testCase.verifyTrue(contains(c, 'band-pass filtered from 1 to 80 Hz'));
testCase.verifyTrue(contains(c, 'fourth-order Butterworth'));
end

function test_tesaFilter_bandstop(testCase)
c = methodsClause('Frequency Filter (TESA)', ...
    struct('type', 'bandstop', 'high', 58, 'low', 62, 'ord', 2));
testCase.verifyTrue(contains(c, 'band-stop filtered at 58-62 Hz'));
testCase.verifyTrue(contains(c, 'second-order Butterworth'));
end

function test_eeglabFilter_bandpassAndHighpass(testCase)
c1 = methodsClause('Frequency Filter', struct('locutoff', 0.5, 'hicutoff', 40));
testCase.verifyTrue(contains(c1, 'band-pass filtered from 0.5 to 40 Hz'));
c2 = methodsClause('Frequency Filter', struct('locutoff', 1, 'hicutoff', 0));
testCase.verifyTrue(contains(c2, 'high-pass filtered at 1 Hz'));
c3 = methodsClause('Frequency Filter', struct('locutoff', 0, 'hicutoff', 200));
testCase.verifyTrue(contains(c3, 'low-pass filtered at 200 Hz'));
end

% ── ICA family ────────────────────────────────────────────────────────────────

function test_runIca_algorithmName(testCase)
% The engine is carried by the step name now, not an icatype parameter.
testCase.verifyTrue(contains(methodsClause('Run ICA (FastICA)', struct()), 'FastICA'));
testCase.verifyTrue(contains(methodsClause('Run ICA (Infomax)', struct()),  'infomax'));
testCase.verifyTrue(contains(methodsClause('Run ICA (Picard)',  struct()),  'Picard'));
testCase.verifyTrue(contains(methodsClause('Run TESA ICA', struct()), 'FastICA'));
end

function test_iclabelCategories_listed(testCase)
p = struct('Brain',[NaN NaN], 'Muscle',[0.8 1], 'Eye',[0.8 1], 'Heart',[0.9 1], ...
           'LineNoise',[NaN NaN], 'ChannelNoise',[NaN NaN], 'Other',[NaN NaN]);
c = methodsClause('Flag ICA Components for Rejection', p);
testCase.verifyTrue(contains(c, 'ICLabel'));
testCase.verifyTrue(contains(c, 'eye') && contains(c, 'muscle') && contains(c, 'cardiac'));
end

function test_tesaCompCategories_onlyEnabled(testCase)
p = struct('tmsMuscle','on','blink','off','move','off','muscle','off','elecNoise','off');
c = methodsClause('Remove ICA Components (TESA)', p);
testCase.verifyTrue(contains(c, 'TMS-evoked muscle'));
testCase.verifyFalse(contains(c, 'eye-blink'));
end

% ── reference / interpolation ─────────────────────────────────────────────────

function test_reref_average(testCase)
testCase.verifyTrue(contains(methodsClause('Re-Reference', struct('ref','[]')), 'common average'));
testCase.verifyTrue(contains(methodsClause('Re-Reference', struct('ref','Cz')),  'Cz'));
end

function test_interpolateChannels_method(testCase)
c = methodsClause('Interpolate Channels', struct('method','spherical'));
testCase.verifyTrue(contains(c, 'spherical'));
end

% ── omitted (housekeeping / analysis) steps ───────────────────────────────────

function test_housekeepingStepsReturnEmpty(testCase)
for nm = {'Load Data','Load Channel Location','Find TMS Pulses (TESA)', ...
          'Save New Set','Quality Gate','Label ICA Components','Remove Flagged ICA Components'}
    testCase.verifyEmpty(methodsClause(nm{1}, struct()), ...
        sprintf('%s must contribute no methods sentence', nm{1}));
end
end

% ── drift guard: every switch case must name a real registry step ─────────────

function test_everyCaseLiteralIsARealRegistryStep(testCase)
% methodsClause keys on exact step-name literals; a registry rename that misses
% this file would silently drop a step's methods sentence (the otherwise branch
% returns ''). Pin the coupling: every 'case' literal must be a stepRegistry name.
src = fileread(which('methodsClause'));
% Scan only the main dispatch switch (above the "per-step helpers" divider);
% the local helpers below it have their own inner switches (filter type, ICA
% algorithm, ...) whose case labels are not step names.
cut = strfind(src, 'per-step helpers');
if ~isempty(cut); src = src(1:cut(1)-1); end
lines = regexp(src, 'case[^\n]*', 'match');     % every "case ..." line
names = {};
for i = 1:numel(lines)
    toks = regexp(lines{i}, '''([^'']+)''', 'tokens');   % all quoted literals on the line
    for j = 1:numel(toks); names{end+1} = toks{j}{1}; end %#ok<AGROW>
end
testCase.assertNotEmpty(names, 'Expected to find case literals in methodsClause.m');
regNames = {stepRegistry().name};
for i = 1:numel(names)
    testCase.verifyTrue(ismember(names{i}, regNames), ...
        sprintf('methodsClause case "%s" is not a stepRegistry step name (renamed step?)', names{i}));
end
end
