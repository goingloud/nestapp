
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_vendoredDependencies < matlab.unittest.TestCase
% TEST_VENDOREDDEPENDENCIES  Pre-flight must see code that ships in the box.
%
%   Regression: the vendored AARATEP tree is added to the path lazily, and
%   which steps trigger that was a hand-kept list sitting beside the registry.
%   The list named three steps while five needed the path, so the pre-flight's
%   which() probes ran before the path existed and reported BUNDLED helpers as
%   a missing plugin - blocking "Modified Bandpass Filter (AARATEP)" and both
%   "Detect Bad Channels" steps outright.
%
%   The trigger is now derived from the registry, so these check the two
%   halves that must agree: every step that calls a vendored helper declares
%   it, and every step that declares one passes pre-flight.

    properties
        registry
        dispatchSrc
    end

    methods (TestClassSetup)
        function load(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            tc.registry    = stepRegistry();
            tc.dispatchSrc = fileread(fullfile(root, 'src', 'processOneFile.m'));
        end
    end

    methods (Test)
        function steps_calling_vendored_helpers_declare_them(tc)
            % A step that reaches into third_party/aaratep must say so, or the
            % pre-flight cannot know to add the path - and cannot warn when
            % the tree is genuinely absent.
            offenders = {};
            cases = splitCases(tc.dispatchSrc);
            for i = 1:numel(cases)
                tok = regexp(cases(i).body, '(?<![\w.])(c_[A-Za-z]\w+)\s*\(', 'tokens');
                if isempty(tok); continue; end
                called = unique(cellfun(@(t) t{1}, tok, 'UniformOutput', false));
                for n = 1:numel(cases(i).names)
                    k = find(strcmp({tc.registry.name}, cases(i).names{n}), 1);
                    if isempty(k); continue; end
                    declared = declaredFns(tc.registry(k));
                    if isempty(intersect(called, declared))
                        offenders{end+1} = sprintf('%s (calls %s)', ...
                            cases(i).names{n}, strjoin(called, ', ')); %#ok<AGROW>
                    end
                end
            end
            tc.verifyEmpty(offenders, sprintf( ...
                ['Steps calling a vendored c_* helper without declaring it in\n' ...
                 's.requires - pre-flight will not add the path for them:\n  %s'], ...
                strjoin(offenders, sprintf('\n  '))));
        end

        function vendored_steps_pass_preflight_from_a_clean_path(tc)
            % The real failure: which() probing before the path is added.
            % Strip the vendored tree, reset the lazy-add guard, and confirm
            % the pre-flight still resolves every step that needs it.
            entries = strsplit(path, pathsep);
            aar = entries(contains(entries, fullfile('third_party', 'aaratep')));
            if ~isempty(aar)
                rmpath(strjoin(aar, pathsep));
                tc.addTeardown(@() addpath(strjoin(aar, pathsep)));
            end
            ensureAaratepOnPath('reset');

            needsVendored = {};
            for i = 1:numel(tc.registry)
                if any(startsWith(declaredFns(tc.registry(i)), 'c_'))
                    needsVendored{end+1} = tc.registry(i).name; %#ok<AGROW>
                end
            end
            tc.assertNotEmpty(needsVendored, 'Expected some steps to need the vendored tree');

            blocked = {};
            for i = 1:numel(needsVendored)
                if ~checkStepDependencies({'Load Data', needsVendored{i}}, {'x.set'})
                    blocked{end+1} = needsVendored{i}; %#ok<AGROW>
                end
            end
            tc.verifyEmpty(blocked, sprintf( ...
                ['Pre-flight reports these as missing a plugin, but the code\n' ...
                 'ships with nestapp under third_party/aaratep:\n  %s'], ...
                strjoin(blocked, sprintf('\n  '))));
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function fns = declaredFns(step)
fns = {};
rq = step.requires;
for j = 1:numel(rq)
    if isfield(rq(j), 'fn') && ~isempty(rq(j).fn)
        fns{end+1} = rq(j).fn; %#ok<AGROW>
    end
end
end

function cases = splitCases(src)
starts = regexp(src, '\n            case [^\n]*', 'start');
labels = regexp(src, '\n            case ([^\n]*)', 'tokens');
cases = struct('names', {}, 'body', {});
for i = 1:numel(starts)
    if i < numel(starts); stop = starts(i+1); else; stop = numel(src); end
    q = regexp(labels{i}{1}, '''([^'']+)''', 'tokens');
    cases(i).names = cellfun(@(t) t{1}, q, 'UniformOutput', false);
    cases(i).body  = src(starts(i):stop);
end
end
