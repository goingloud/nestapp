
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_stepTaxonomy
% TEST_STEPTAXONOMY  The picker taxonomy stays in lockstep with the registry.
%
%   The step-picker tree is built from stepTaxonomy(); a registry step that
%   isn't placed there would silently vanish from the picker. These tests fail
%   the moment the two drift, so a new step must be categorized before it ships.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '..', '..', 'src')));
testCase.TestData.reg = stepRegistry();
testCase.TestData.tax = stepTaxonomy();
testCase.TestData.steps = flattenSteps(stepTaxonomy());
end

function s = flattenSteps(tax)
s = {};
for c = 1:numel(tax)
    for o = 1:numel(tax(c).ops)
        s = [s, {tax(c).ops(o).variants.step}]; %#ok<AGROW>
    end
end
end

function test_covers_exactly_the_listed_steps(testCase)
% Every free-standing (listed) step is placed, and nothing else is.
listed = {testCase.TestData.reg([testCase.TestData.reg.listed]).name};
placed = testCase.TestData.steps;
missing = setdiff(listed, placed);
extra   = setdiff(placed, listed);
testCase.verifyEmpty(missing, sprintf('listed steps not placed in the taxonomy: %s', ...
    strjoin(missing, ', ')));
testCase.verifyEmpty(extra, sprintf('taxonomy names steps that are not listed registry steps: %s', ...
    strjoin(extra, ', ')));
end

function test_no_duplicate_placements(testCase)
placed = testCase.TestData.steps;
testCase.verifyEqual(numel(placed), numel(unique(placed)), ...
    'a step appears under more than one operation/category');
end

function test_hidden_orchestrator_is_absent(testCase)
% AARATEP Pipeline (whole) is listed=false (template-only) - never in the tree.
testCase.verifyFalse(ismember('AARATEP Pipeline (whole)', testCase.TestData.steps), ...
    'the template-only orchestrator must not appear in the picker taxonomy');
end

function test_every_variant_provider_is_known(testCase)
known = {'EEGLAB','TESA','clean_rawdata','ICLabel','firfilt','CleanLine', ...
         'PICARD','FastICA','AARATEP','nestapp'};
tax = testCase.TestData.tax;
for c = 1:numel(tax)
    for o = 1:numel(tax(c).ops)
        for v = 1:numel(tax(c).ops(o).variants)
            prov = tax(c).ops(o).variants(v).provider;
            testCase.verifyTrue(ismember(prov, known), ...
                sprintf('unknown provider "%s" on step "%s"', prov, ...
                        tax(c).ops(o).variants(v).step));
        end
    end
end
end

function test_structure_is_well_formed(testCase)
tax = testCase.TestData.tax;
testCase.verifyGreaterThan(numel(tax), 1, 'expected several categories');
for c = 1:numel(tax)
    testCase.verifyNotEmpty(tax(c).name);
    testCase.verifyNotEmpty(tax(c).ops, sprintf('category "%s" has no operations', tax(c).name));
    for o = 1:numel(tax(c).ops)
        testCase.verifyNotEmpty(tax(c).ops(o).name);
        testCase.verifyNotEmpty(tax(c).ops(o).variants);
    end
end
end
