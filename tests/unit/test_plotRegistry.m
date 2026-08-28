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
% Against the taxonomy itself, not a frozen list: the contract is "the picker
% presents categories in taxonomy order", and a literal copy here just has to
% be edited every time a category is added, which tests nothing.
[~, cats] = availablePlots(fullCtx());
testCase.verifyEqual({cats.name}, {plotTaxonomy().name});
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

% -- plot parameters ------------------------------------------------------

function test_everyParamKeyIsARealOptionOfItsDrawFunction(testCase)
% The design claim: a registry param key IS the draw function's option name, so
% the edited values are handed over with no translation table. If a key drifts
% from what the function reads, the setting silently does nothing - the edit
% lands in a field nobody looks at, and the plot is simply unchanged, which is
% the failure a user is least likely to report as a bug.
%
% The search covers the draw function AND the drawers it hands opts on to: a
% composite like TEP-topo passes its whole opts struct down to the curve
% drawer, so 'xlim' is honoured one call deeper than the file that declares it.
reg = plotRegistry();
for k = 1:numel(reg)
    if isempty(reg(k).params); continue; end
    src = drawSourceGraph(reg(k).draw);
    for p = 1:numel(reg(k).params)
        key = reg(k).params(p).key;
        testCase.verifyTrue(contains(src, ['opts.' key]), sprintf( ...
            '%s declares "%s" but nothing under %s reads opts.%s', ...
            reg(k).name, key, reg(k).draw, key));
    end
end
end

function src = drawSourceGraph(fn)
% The named drawer plus every draw*/shade* helper it calls, one level down -
% which is as deep as a plot's opts struct is ever forwarded.
src = fileread(which(fn));
callees = unique(regexp(src, '\<(?:draw|shade)\w+', 'match'));
for c = 1:numel(callees)
    w = which(callees{c});
    if ~isempty(w) && ~strcmp(callees{c}, fn)
        src = [src newline fileread(w)]; %#ok<AGROW>
    end
end
end

function test_everyParamHasThePlaceholderThatNamesItsDefault(testCase)
% Defaults live in the draw function; the placeholder is how the table tells the
% user what leaving a cell alone will do. Without one the cell reads "(not set)",
% which says nothing about what will actually be drawn.
reg = plotRegistry();
for k = 1:numel(reg)
    for p = 1:numel(reg(k).params)
        testCase.verifyNotEmpty(reg(k).params(p).placeholder, ...
            sprintf('%s / %s has no placeholder', reg(k).name, reg(k).params(p).key));
    end
end
end

function test_anOffSwitchActuallyReachesTheDrawFunctionAsFalse(testCase)
% Logical params are STORED as 'on'/'off' text, because plots share the step
% parameter editor. In MATLAB `if 'off'` is TRUE - every character is non-zero -
% so passing the text straight through leaves every switch the user turned off
% still on, with nothing in the picture to say the setting was ignored.
entry = plotRegistry();
entry = entry(strcmp({entry.name}, 'TEP (ROI mean)'));
opts  = plotDrawOpts(entry, struct('showBand', 'off', 'showBands', 'on'));
testCase.verifyFalse(opts.showBand);
testCase.verifyTrue(opts.showBands);
end

function test_paramsNeverSetStayAbsentSoTheDrawDefaultApplies(testCase)
entry = plotRegistry();
entry = entry(strcmp({entry.name}, 'TEP (ROI mean)'));
opts  = plotDrawOpts(entry, struct('xlim', [-20 200]));
testCase.verifyEqual(fieldnames(opts), {'xlim'}, ...
    'an untouched setting must not be materialised as a frozen copy of the default');
end
