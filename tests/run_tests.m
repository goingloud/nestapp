%% run_tests  Run the nestapp test suite (or one part of it).
%
%   USAGE
%     run_tests              % 'pure' - no EEGLAB, no display. The default.
%     run_tests('eeglab')    % needs EEGLAB on the path
%     run_tests('gui')       % needs a display
%     run_tests('all')       % everything
%
%   A SUITE IS A FOLDER, AND THE FOLDER DECLARES WHAT THE TEST NEEDS:
%
%     tests/pure/         no EEGLAB, no display (writing to a temp dir is fine)
%     tests/eeglab/       needs EEGLAB
%     tests/gui/          needs a display
%     tests/eeglab_gui/   needs both
%
%   Two axes, both binary, so the cross-product is four folders and selection
%   needs no per-test machinery. The requirement is visible in the path, which
%   means a test cannot be misfiled without it being obvious.
%
%   THREE RULES THIS RUNNER ENFORCES, each fixing a way the previous suite went
%   quietly wrong:
%
%   1. A SKIP IS A FAILURE. The old runner gated only on Failed and merely
%      printed the Incomplete count, so a run in which every test skipped
%      exited green - which is how 125 of 916 cases came to be executed by
%      nothing at all, unnoticed, for months. Here a skip is a fault: the
%      folder already said what the test needs, so a test has no business
%      deciding at runtime that it cannot run. There are no assumeFail sites in
%      the new suite, and this rule is what keeps it that way.
%
%   2. AN EMPTY SUITE IS A FAILURE. The old runner warned and passed when a
%      suite folder was missing, so a typo'd or renamed directory was green.
%
%   3. THE PATH IS RESTORED. The old runner added to the path and never
%      removed, which is why every local test runner had to snapshot and
%      restore it by hand.
%
%   Preconditions are checked ONCE per suite, up front, with a clear message -
%   not per test. Running the eeglab suite without EEGLAB is a user error and
%   should say so immediately, not skip 96 tests one at a time.
%
%   OUTPUT
%     results  (optional) matlab.unittest.TestResult array. Called with no
%              output, run_tests errors on any failure or skip so it cannot be
%              missed. When the caller captures results it inspects them
%              itself - but note that checking only [results.Failed] reproduces
%              the exact blindness rule 1 exists to remove; check .Incomplete
%              too.
%
%   DURING THE REWRITE this runner also serves the OLD suite under its old
%   names (unit, regression, integration, ui, characterization, and 'fast'
%   meaning unit+regression). Those are marked LEGACY below and are deleted at
%   cutover, at which point 'fast' becomes an alias for 'pure'. They are kept
%   because the new suite must be green BEFORE the old one is removed, and
%   renaming the old suite out of existence first would leave a window with no
%   tests at all. Legacy suites do not get rule 1 - the old tests skip by
%   design, 38 of them - so enforcing it there would just report the disease.
%
%   See also: NestappTestCase, addNestappPath, scratchDir

% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.

function results = run_tests(suite)
if nargin < 1
    suite = 'pure';
end

testRoot = fileparts(mfilename('fullpath'));
oldPath  = path;
restore  = onCleanup(@() path(oldPath));   % rule 3: always put the path back
addpath(fullfile(testRoot, 'helpers'));
addNestappPath();

spec = resolveSuite(lower(suite), testRoot);
checkPreconditions(spec.needs, suite);

logFile = fullfile(tempdir, 'nestapp_test_progress.log');
if exist(logFile, 'file'); delete(logFile); end
fprintf('Per-test progress log: %s\n\n', logFile);

runner = matlab.unittest.TestRunner.withTextOutput;
runner.addPlugin(TestProgressLogger(logFile));

results = matlab.unittest.TestResult.empty;
for i = 1:numel(spec.folders)
    f = spec.folders{i};
    if ~isfolder(f)
        error('nestapp:missingSuite', ...
              'Suite folder does not exist: %s', f);   % rule 2
    end
    s = matlab.unittest.TestSuite.fromFolder(f);
    if isempty(s)
        error('nestapp:emptySuite', ...
              'Suite folder holds no tests: %s', f);    % rule 2
    end
    results = [results, runner.run(s)]; %#ok<AGROW>
end

report(results, suite, spec.strictSkips);

nBad = sum([results.Failed]);
if spec.strictSkips
    nBad = nBad + sum([results.Incomplete]);
end
if nBad > 0 && nargout == 0
    error('nestapp:testsFailed', ...
          'run_tests: %d failed, %d skipped.', ...
          sum([results.Failed]), sum([results.Incomplete]));
end
end

% ── suites ───────────────────────────────────────────────────────────────────

function spec = resolveSuite(suite, testRoot)
% .folders  where the tests are
% .needs    {} | {'eeglab'} | {'display'} | {'eeglab','display'}
% .strictSkips  true when a skip is a failure (rule 1). False only for the
%               legacy suites, whose tests skip by design.
at = @(varargin) fullfile(testRoot, varargin);
spec = struct('folders', {{}}, 'needs', {{}}, 'strictSkips', true);

switch suite
    case 'pure'
        spec.folders = at('pure');
    case 'eeglab'
        spec.folders = at('eeglab');       spec.needs = {'eeglab'};
    case 'gui'
        spec.folders = at('gui');          spec.needs = {'display'};
    case 'eeglab_gui'
        spec.folders = at('eeglab_gui');   spec.needs = {'eeglab', 'display'};
    case 'all'
        spec.folders = at('pure', 'eeglab', 'gui', 'eeglab_gui');
        spec.needs   = {'eeglab', 'display'};

    % ---- LEGACY: delete this block at cutover -------------------------------
    % The old suite, under its old names, so it stays runnable while the new
    % one is being written. strictSkips is false here because these tests skip
    % by design (38 assumeFail sites) - holding them to rule 1 would report the
    % disease rather than protect anything. At cutover this block goes and
    % 'fast' becomes an alias for 'pure', which is what
    % .github/workflows/tests.yml:43 calls.
    case 'fast'
        spec.folders = at('unit', 'regression');  spec.strictSkips = false;
    case 'unit'
        spec.folders = at('unit');                spec.strictSkips = false;
    case 'regression'
        spec.folders = at('regression');          spec.strictSkips = false;
    case 'integration'
        spec.folders = at('integration');         spec.strictSkips = false;
    case 'ui'
        spec.folders = at('ui');                  spec.strictSkips = false;
    case 'characterization'
        spec.folders = at('characterization');    spec.strictSkips = false;
    case 'legacy-all'
        spec.folders = at('unit', 'regression', 'integration', 'ui', ...
                          'characterization');
        spec.strictSkips = false;
    % ---- end LEGACY ---------------------------------------------------------

    otherwise
        error('nestapp:unknownSuite', ...
              ['run_tests: unknown suite "%s". Valid: pure (default), ' ...
               'eeglab, gui, eeglab_gui, all.\n(Legacy, until the rewrite ' ...
               'lands: fast, unit, regression, integration, ui, ' ...
               'characterization, legacy-all.)'], suite);
end
end

function checkPreconditions(needs, suite)
% Once, up front, naming what is missing and how to fix it. A test never makes
% this decision for itself - see rule 1.
for k = 1:numel(needs)
    switch needs{k}
        case 'eeglab'
            if isempty(which('eeglab'))
                error('nestapp:eeglabRequired', ...
                    ['The "%s" suite needs EEGLAB on the MATLAB path, and it ' ...
                     'is not there.\nAdd it (addpath to the EEGLAB root, then ' ...
                     'eeglab(''nogui'')) and run again, or use run_tests(''pure'').'], ...
                     suite);
            end
        case 'display'
            if ~usejava('desktop')
                error('nestapp:displayRequired', ...
                    ['The "%s" suite needs a display and this session has ' ...
                     'none.\nRun it from a desktop MATLAB, or use ' ...
                     'run_tests(''pure'').'], suite);
            end
    end
end
end

% ── reporting ────────────────────────────────────────────────────────────────

function report(results, suite, strictSkips)
nPass = sum([results.Passed]);
nFail = sum([results.Failed]);
nSkip = sum([results.Incomplete]);

fprintf('\n');
fprintf('==============================================\n');
fprintf('  nestapp test suite - %s\n', suite);
fprintf('==============================================\n');
fprintf('  Total:   %4d\n', numel(results));
fprintf('  Passed:  %4d\n', nPass);
fprintf('  Failed:  %4d%s\n', nFail, marker(nFail));
fprintf('  Skipped: %4d%s\n', nSkip, marker(nSkip));
fprintf('==============================================\n\n');

% Names, not just counts. A count tells you something is wrong; a name tells
% you what. The old runner printed failure names but only a skip COUNT, which
% is how skips stayed invisible.
printNames(results, [results.Failed], 'Failed');
if strictSkips
    printNames(results, [results.Incomplete], ...
        'Skipped (a skip is a FAULT - the folder already declares what a test needs)');
else
    printNames(results, [results.Incomplete], 'Skipped (legacy suite - skips tolerated)');
end
end

function s = marker(n)
if n > 0; s = '  <-- fix before committing'; else; s = ''; end
end

function printNames(results, mask, heading)
if ~any(mask); return; end
fprintf('%s:\n', heading);
hit = results(mask);
for i = 1:numel(hit)
    fprintf('  - %s\n', hit(i).Name);
end
fprintf('\n');
end
