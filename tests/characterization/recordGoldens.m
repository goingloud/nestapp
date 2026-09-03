
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function recordGoldens(varargin)
% RECORDGOLDENS  Record the characterization goldens for pipeline steps.
%   recordGoldens()          record every step listed in the case table
%   recordGoldens('Step A')  record only the named step(s)
%
%   Writes tests/characterization/golden/<step>.json, one per step, holding
%   the eegDigest of that step's output on its fixture.
%
%   Recording is a DECISION, not a chore. A golden changing means a step's
%   behaviour changed; re-record only once you have read the diff and decided
%   the new behaviour is what you want. Re-recording to make a red test go
%   green throws away the only thing protecting the step layer.
%
%   Prints a per-step report, including steps that could not be run at all -
%   those need a different fixture or extra parameters, and are listed in the
%   suite's NOT-CHARACTERIZED notes rather than silently skipped.
%
%   See also: test_stepCharacterization, eegDigest, charFixture

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
addpath(root);
addpath(genpath(fullfile(root, 'src')));
addpath(fullfile(root, 'tests', 'helpers'));

goldenDir = fullfile(here, 'golden');
if ~exist(goldenDir, 'dir'); mkdir(goldenDir); end

global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>
evalc('[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab(''nogui'');');

cases = characterizationCases();
if nargin > 0
    keep = ismember(cases(:,1), varargin);
    cases = cases(keep, :);
end

reg    = stepRegistry();
tmpDir = tempname; mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

nOK = 0; failed = {};
fprintf('\n=== recording characterization goldens ===\n');
for i = 1:size(cases, 1)
    name = cases{i,1}; kind = cases{i,2}; ov = cases{i,3}; pre = cases{i,4};
    if ~any(strcmp({reg.name}, name))
        failed{end+1} = sprintf('%-36s NOT IN REGISTRY', name); %#ok<AGROW>
        continue
    end
    try
        d = runOne(name, kind, ov, reg, tmpDir, pre);
        txt = jsonencode(d, 'PrettyPrint', true);
        fid = fopen(fullfile(goldenDir, [safeName(name) '.json']), 'w');
        fwrite(fid, txt); fclose(fid);
        fprintf('  OK    %-36s ch=%d pnts=%d trials=%d std=%.6g\n', ...
            name, d.nbchan, d.pnts, d.trials, d.dataStd);
        nOK = nOK + 1;
    catch err
        failed{end+1} = sprintf('%-36s %s', name, err.message); %#ok<AGROW>
    end
end

fprintf('\nrecorded %d golden(s) into %s\n', nOK, goldenDir);
if ~isempty(failed)
    fprintf('\ncould NOT run (%d):\n', numel(failed));
    fprintf('  %s\n', failed{:});
end
end


function d = runOne(name, kind, overrides, reg, tmpDir, prereqs)
global EEG %#ok<GVMIS>
fx      = charFixture(kind);
fname   = [safeName(name) '.set'];
setPath = fullfile(tmpDir, fname);
evalc('pop_saveset(fx, ''filename'', fname, ''filepath'', tmpDir);');

spec = makePipelineStep('Load Data', reg);
for j = 1:numel(prereqs)
    spec(end+1) = makePipelineStep(prereqs{j}, reg); %#ok<AGROW>
end
step = makePipelineStep(name, reg);
k = fieldnames(overrides);
for j = 1:numel(k); step.params.(k{j}) = overrides.(k{j}); end
spec(end+1) = step;

rng(42, 'twister');
evalc('processOneFile(spec, setPath, struct(''pipelineName'',''characterization'',''fileIndex'',1));');
d = eegDigest(EEG);
end

function s = safeName(name)
% Delegates to the shared definition, so the recorder and StepGoldenTest
% cannot disagree about where a golden lives. Kept as a local name because
% two call sites above read better with it.
s = goldenFileStem(name);
end
