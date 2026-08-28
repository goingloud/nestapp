% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_plotRegistry
% TEST_PLOTREGISTRY  The plot catalogue and its availability gating.
%
%   Mirrors the step-picker's own tests, because the mechanism is deliberately
%   the same: every entry must resolve to a real drawing function, the taxonomy
%   must not lose one, and an entry that cannot render must say why rather than
%   disappear or error when clicked.
%
%   Run: runtests('tests/unit/test_plotRegistry')
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

function ctx = fullCtx(varargin)
ctx = struct('nGroups', 2, 'hasWindows', true, 'hasChanlocs', true);
for k = 1:2:numel(varargin); ctx.(varargin{k}) = varargin{k+1}; end
end

% ── registry integrity ────────────────────────────────────────────────────

function test_everyEntryResolvesToARealDrawFunction(testCase)
% A registry entry whose implementation is missing would error on click.
reg = plotRegistry();
testCase.assertNotEmpty(reg);
for i = 1:numel(reg)
    testCase.verifyEqual(exist(reg(i).draw, 'file'), 2, ...
        sprintf('%s names a draw function that does not exist: %s', ...
                reg(i).name, reg(i).draw));
end
end

function test_namesAreUnique(testCase)
% The name is the key a saved session stores, so duplicates would make a
% reloaded session ambiguous.
reg = plotRegistry();
testCase.verifyEqual(numel(unique({reg.name})), numel(reg));
end

function test_everyEntryIsPlacedByTheTaxonomy(testCase)
% An unplaced entry still appears under "Other", but that is a safety net, not
% the intent - the ordering is a deliberate judgement and should be complete.
reg = plotRegistry();
tax = plotTaxonomy();
placed = [tax.plots];
testCase.verifyEmpty(setdiff({reg.name}, placed), ...
    'these registry entries are missing from plotTaxonomy');
end

function test_taxonomyNamesNothingThatDoesNotExist(testCase)
reg = plotRegistry();
tax = plotTaxonomy();
testCase.verifyEmpty(setdiff([tax.plots], {reg.name}), ...
    'plotTaxonomy names plots that are not in plotRegistry');
end

function test_registryIsCachedButNotShared(testCase)
% Cached like stepRegistry; a caller mutating its copy must not poison the next.
a = plotRegistry();
a(1).name = 'mutated';
b = plotRegistry();
testCase.verifyNotEqual(b(1).name, 'mutated');
end

% ── availability gating ───────────────────────────────────────────────────

function test_differenceWaveNeedsExactlyTwoGroups(testCase)
reg  = plotRegistry();
diff = reg(strcmp({reg.name}, 'Difference wave'));
testCase.assertNotEmpty(diff);

testCase.verifyTrue(plotAvailability(diff, fullCtx('nGroups', 2)));
[ok1, why1] = plotAvailability(diff, fullCtx('nGroups', 1));
[ok3, why3] = plotAvailability(diff, fullCtx('nGroups', 3));
testCase.verifyFalse(ok1);
testCase.verifyFalse(ok3, 'three groups is as undefined as one');
testCase.verifyTrue(contains(why1, 'exactly 2'));
testCase.verifyTrue(contains(why3, 'there are 3'), ...
    'the reason must state the current state, not just the requirement');
end

function test_overlayAcceptsAnyNumberOfGroups(testCase)
reg = plotRegistry();
tep = reg(strcmp({reg.name}, 'TEP (ROI mean)'));
for n = [1 2 3 7]
    testCase.verifyTrue(plotAvailability(tep, fullCtx('nGroups', n)), ...
        sprintf('the overlay must scale to %d groups', n));
end
[ok, why] = plotAvailability(tep, fullCtx('nGroups', 0));
testCase.verifyFalse(ok);
testCase.verifyTrue(contains(why, 'at least 1'));
end

function test_topographyNeedsChannelLocations(testCase)
reg  = plotRegistry();
topo = reg(strcmp({reg.name}, 'Scalp map'));
[ok, why] = plotAvailability(topo, fullCtx('hasChanlocs', false));
testCase.verifyFalse(ok);
testCase.verifyTrue(contains(lower(why), 'electrode positions'));
end

function test_missingDrawFunctionReportsNotImplemented(testCase)
entry = struct('name', 'Future plot', 'category', 'Waveform', 'info', '', ...
               'draw', 'drawSomethingNotWrittenYet', 'mode', 'TEP', ...
               'requires', struct('groups', 'any', 'windows', false, 'chanlocs', false));
[ok, why] = plotAvailability(entry, fullCtx());
testCase.verifyFalse(ok);
testCase.verifyTrue(contains(why, 'Not implemented'));
end

% ── availablePlots ────────────────────────────────────────────────────────

function test_unavailablePlotsAreAnnotatedNotRemoved(testCase)
% Unlike a step, an unrenderable plot is still shown: the user is one group
% away from it and must be able to see that it exists.
entries = availablePlots(fullCtx('nGroups', 1));
testCase.verifyEqual(numel(entries), numel(plotRegistry()));
diff = entries(strcmp({entries.name}, 'Difference wave'));
testCase.verifyFalse(diff.available);
testCase.verifyNotEmpty(diff.reason);
end

function test_categoriesFollowTaxonomyOrder(testCase)
[~, cats] = availablePlots(fullCtx());
testCase.verifyEqual({cats.name}, {'Waveform', 'Topography'});
testCase.verifyEqual(cats(1).entries(1).name, 'TEP (ROI mean)', ...
    'the default view must be offered first');
end

function test_anOrphanEntryLandsUnderOther(testCase)
reg = plotRegistry();
reg(end+1) = reg(1);
reg(end).name = 'Unlisted plot';
[~, cats] = availablePlots(fullCtx(), reg);
testCase.verifyEqual(cats(end).name, 'Other');
testCase.verifyEqual(cats(end).entries.name, 'Unlisted plot');
end

function test_badGroupRuleIsARegistryBugNotASilentPass(testCase)
entry = struct('name', 'x', 'category', 'y', 'info', '', 'draw', 'drawTEPOverlay', ...
               'mode', 'TEP', ...
               'requires', struct('groups', 'lots', 'windows', false, 'chanlocs', false));
testCase.verifyError(@() plotAvailability(entry, fullCtx()), 'nestapp:badGroupRule');
end
