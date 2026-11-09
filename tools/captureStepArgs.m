% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function out = captureStepArgs(varargin)
% CAPTURESTEPARGS  Record (and diff) the exact arguments steps pass upstream.
%   log = CAPTURESTEPARGS(cases)            run each case, record upstream calls
%   log = CAPTURESTEPARGS(cases, outFile)   ...and save the log to outFile
%   CAPTURESTEPARGS('diff', before, after)  report every case whose calls differ
%   cases = CAPTURESTEPARGS('cases', stepNames)   build cases for those steps
%
%   A development tool for converting step settings to typed values: record
%   before changing a step, convert it, record again, diff. Any difference is
%   either a bug or a deliberate correction to be noted in the changelog. It is
%   run while implementing and is not part of the test suite.
%
%   A case is a struct with fields
%     label     unique name used to match cases between runs
%     step      registry step name
%     kind      charFixture kind the run starts from ('epochedPulses', ...)
%     params    struct of parameter values set on the step (others default)
%     prereqs   cellstr of steps run (for real) before the step
%
%   HOW IT RECORDS. Every EEGLAB / plugin / AARATEP function that nestapp's
%   source calls is shadowed by a stand-in that logs its arguments and then
%   calls the real function through a handle taken before the shadow went on
%   the path (a handle stays bound to the function it was made from). Only the
%   calls made while the step under test runs are kept: processOneFile's
%   progressFcn says which step is starting. So prerequisites run normally and
%   the data the step sees is real.
%
%   Arguments are logged with datasets reduced to a short tag, so the log
%   compares what the step was told to do, not the data it was given.
%
%   See also: characterizationCases, processOneFile

if nargin >= 1 && ischar(varargin{1}) && strcmp(varargin{1}, 'diff')
    out = diffLogs(varargin{2}, varargin{3});
    return
end
if nargin >= 1 && ischar(varargin{1}) && strcmp(varargin{1}, 'cases')
    out = buildCases(varargin{2});
    return
end

cases   = varargin{1};
outFile = '';
if nargin >= 2, outFile = varargin{2}; end

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'tests', 'helpers'));
addNestappPath();
ensureEeglabReady();

work = tempname; mkdir(work);
cleanup = onCleanup(@() cleanUp(work));

global NESTAPP_ARGCAP %#ok<GVMIS>
% Only calls made directly from nestapp's own code are kept; what EEGLAB does
% inside those calls is upstream's business, not the step's settings.
NESTAPP_ARGCAP = struct('on', false, 'calls', {{}}, 'real', struct(), ...
    'srcRoot', fullfile(root, 'src'));
shadowDir = fullfile(work, 'shadow');
mkdir(shadowDir);
names = upstreamFunctions(root);
for k = 1:numel(names)
    NESTAPP_ARGCAP.real.(names{k}) = str2func(names{k});   % bound to the real one
    writeStandIn(shadowDir, names{k});
end
addpath(shadowDir);
rehash;

reg = stepRegistry();
log = struct('label', {}, 'step', {}, 'calls', {}, 'error', {});
for c = 1:numel(cases)
    cs      = cases(c);
    setPath = saveFixtureSet(work, cs.kind); %#ok<NASGU> used inside evalc
    spec    = makePipelineStep('Load Data', reg);
    for j = 1:numel(cs.prereqs)
        spec(end+1) = makePipelineStep(cs.prereqs{j}, reg); %#ok<AGROW>
    end
    step = makePipelineStep(cs.step, reg);
    for f = fieldnames(cs.params)'
        step.params.(f{1}) = cs.params.(f{1});
    end
    spec(end+1) = step; %#ok<AGROW>
    target = numel(spec);

    NESTAPP_ARGCAP.on    = false;
    NESTAPP_ARGCAP.calls = {};
    opts = struct('pipelineName', 'argcap', 'fileIndex', 1, ...
        'progressFcn', @(si, ~) setCapture(si == target)); %#ok<NASGU> used inside evalc
    err = '';
    rng(42, 'twister');
    try
        evalc('processOneFile(spec, setPath, opts);');
    catch e
        err = e.message;
    end
    NESTAPP_ARGCAP.on = false;
    log(end+1) = struct('label', cs.label, 'step', cs.step, ...
        'calls', {NESTAPP_ARGCAP.calls}, 'error', err); %#ok<AGROW>
    fprintf('%-60s %3d calls%s\n', cs.label, numel(NESTAPP_ARGCAP.calls), ...
        ternary(isempty(err), '', ['  [error: ' firstLine(err) ']']));
end

if ~isempty(outFile)
    save(outFile, 'log');
end
out = log;
end

% ---------------------------------------------------------------------------

function setCapture(tf)
global NESTAPP_ARGCAP %#ok<GVMIS>
NESTAPP_ARGCAP.on = tf;
end

function names = upstreamFunctions(root)
% Every function nestapp's source calls that lives in EEGLAB, a plugin, or the
% AARATEP helpers. Functions that evaluate in their caller's workspace are left
% alone, because a stand-in in between would change what they see. (Functions
% using inputname are kept: through the stand-in it returns '', which only
% changes the history text they write.)
eeglabRoot  = fileparts(which('eeglab'));
aaratepRoot = '';
try
    ensureAaratepOnPath();
    aaratepRoot = fileparts(fileparts(which('c_TMSEEG_fitAndRemoveDecayArtifact')));
catch
end
files  = dir(fullfile(root, 'src', '**', '*.m'));
tokens = {};
for k = 1:numel(files)
    txt = fileread(fullfile(files(k).folder, files(k).name));
    tokens = [tokens, regexp(txt, '(?<![\w.''])([a-zA-Z]\w*)\s*\(', 'tokens')]; %#ok<AGROW>
end
tokens = unique(cellfun(@(t) t{1}, tokens, 'UniformOutput', false));
names  = {};
for k = 1:numel(tokens)
    p = which(tokens{k});
    if isempty(p) || ~endsWith(p, '.m'), continue; end
    inside = startsWith(p, eeglabRoot) || (~isempty(aaratepRoot) && startsWith(p, aaratepRoot));
    if ~inside, continue; end
    src = fileread(p);
    if contains(src, 'evalin(''caller''')
        continue
    end
    names{end+1} = tokens{k}; %#ok<AGROW>
end
end

function writeStandIn(folder, name)
src = sprintf([ ...
    'function varargout = %1$s(varargin)\n' ...
    '%% Stand-in written by captureStepArgs: log the call, then run the real one.\n' ...
    'global NESTAPP_ARGCAP\n' ...
    'if NESTAPP_ARGCAP.on\n' ...
    '    st = dbstack(''-completenames'', 1);\n' ...
    '    if ~isempty(st) && startsWith(st(1).file, NESTAPP_ARGCAP.srcRoot)\n' ...
    '        NESTAPP_ARGCAP.calls{end+1} = {''%1$s'', captureStepArgsTag(varargin)};\n' ...
    '    end\n' ...
    'end\n' ...
    'real = NESTAPP_ARGCAP.real.%1$s;\n' ...
    'if nargout == 0\n' ...
    '    real(varargin{:});\n' ...
    'else\n' ...
    '    [varargout{1:nargout}] = real(varargin{:});\n' ...
    'end\n' ...
    'end\n'], name);
fid = fopen(fullfile(folder, [name '.m']), 'w');
fprintf(fid, '%s', src);
fclose(fid);
% The tag helper sits beside the stand-ins so they can call it.
if ~isfile(fullfile(folder, 'captureStepArgsTag.m'))
    fid = fopen(fullfile(folder, 'captureStepArgsTag.m'), 'w');
    fprintf(fid, '%s', tagHelperSource());
    fclose(fid);
end
end

function s = tagHelperSource()
s = sprintf([ ...
    'function v = captureStepArgsTag(v)\n' ...
    '%% Reduce datasets and handles to short tags so a log compares settings.\n' ...
    'if iscell(v)\n' ...
    '    for k = 1:numel(v), v{k} = captureStepArgsTag(v{k}); end\n' ...
    'elseif isstruct(v) && isfield(v, ''data'') && isfield(v, ''nbchan'')\n' ...
    '    v = sprintf(''<EEG %%dch>'', v(1).nbchan);\n' ...
    'elseif isstruct(v) && isfield(v, ''labels'') && numel(v) > 3\n' ...
    '    v = sprintf(''<chanlocs %%d>'', numel(v));\n' ...
    'elseif isa(v, ''function_handle'')\n' ...
    '    v = [''@'' func2str(v)];\n' ...
    'elseif isobject(v) || (isnumeric(v) && numel(v) > 200)\n' ...
    '    v = sprintf(''<%%s %%s>'', class(v), mat2str(size(v)));\n' ...
    'end\n' ...
    'end\n']);
end

function cases = buildCases(stepNames)
% For each step: its characterization case(s) if it has any, its uses in the
% built-in templates, then one case per setting with a closed list of choices
% set to a non-default choice. Numeric variations are added by hand where a
% stage needs them.
if ischar(stepNames), stepNames = {stepNames}; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'tests', 'helpers'));
addNestappPath();
reg   = stepRegistry();
chars = characterizationCases();
tdir  = fullfile(root, 'src', 'templates');
tf    = dir(fullfile(tdir, '*.mat'));
cases = struct('label', {}, 'step', {}, 'kind', {}, 'params', {}, 'prereqs', {});
for s = 1:numel(stepNames)
    name = stepNames{s};
    kind = 'epochedPulses'; prereqs = {}; base = struct();
    row  = find(strcmp(chars(:, 1), name), 1);
    if ~isempty(row)
        kind = chars{row, 2}; base = chars{row, 3}; prereqs = chars{row, 4};
    end
    cases(end+1) = mk(sprintf('%s | default', name), name, kind, base, prereqs); %#ok<AGROW>

    for t = 1:numel(tf)
        T = load(fullfile(tdir, tf(t).name), 'spec');
        idx = find(strcmp({T.spec.name}, name));
        for n = 1:numel(idx)
            p = mergeStruct(T.spec(idx(n)).params, base);
            cases(end+1) = mk(sprintf('%s | template %s #%d', name, ...
                erase(tf(t).name, '.mat'), n), name, kind, p, prereqs); %#ok<AGROW>
        end
    end

    entry = reg(strcmp({reg.name}, name));
    for p = entry.params
        dflt = '';
        if isfield(entry.defaults, p.key), dflt = entry.defaults.(p.key); end
        if isfield(p, 'choices') && ~isempty(p.choices)
            choices = {p.choices.key};
        elseif strcmp(p.type, 'logical') && islogical(dflt)
            v = base; v.(p.key) = ~dflt;
            cases(end+1) = mk(sprintf('%s | %s=%d', name, p.key, ~dflt), ...
                name, kind, v, prereqs); %#ok<AGROW>
            continue
        else
            choices = validRangeChoices(p);   % text-era steps
        end
        for c = 1:numel(choices)
            if isequal(choices{c}, dflt), continue; end
            v = base; v.(p.key) = choices{c};
            cases(end+1) = mk(sprintf('%s | %s=%s', name, p.key, choices{c}), ...
                name, kind, v, prereqs); %#ok<AGROW>
        end
    end
end
end

function c = mk(label, step, kind, params, prereqs)
c = struct('label', label, 'step', step, 'kind', kind, 'params', params, ...
    'prereqs', {prereqs});
end

function a = mergeStruct(a, b)
for f = fieldnames(b)'
    a.(f{1}) = b.(f{1});
end
end

function report = diffLogs(before, after)
% Cases are matched by label. Reports added/removed cases and every case whose
% recorded calls or error changed.
if ischar(before), before = load(before); before = before.log; end
if ischar(after),  after  = load(after);  after  = after.log;  end
report = {};
la = {after.label};
for k = 1:numel(before)
    j = find(strcmp(la, before(k).label), 1);
    if isempty(j)
        report{end+1} = sprintf('REMOVED  %s', before(k).label); %#ok<AGROW>
        continue
    end
    if ~isequaln(before(k).calls, after(j).calls)
        report{end+1} = sprintf('CHANGED  %s\n%s', before(k).label, ...
            describeDiff(before(k).calls, after(j).calls)); %#ok<AGROW>
    elseif ~strcmp(before(k).error, after(j).error)
        report{end+1} = sprintf('ERROR    %s\n    before: %s\n    after:  %s', ...
            before(k).label, firstLine(before(k).error), firstLine(after(j).error)); %#ok<AGROW>
    end
end
lb = {before.label};
for j = 1:numel(after)
    if ~any(strcmp(lb, after(j).label))
        report{end+1} = sprintf('ADDED    %s', after(j).label); %#ok<AGROW>
    end
end
if isempty(report)
    fprintf('No differences in %d cases.\n', numel(before));
else
    fprintf('%s\n', report{:});
end
end

function s = describeDiff(a, b)
lines = {};
n = max(numel(a), numel(b));
for k = 1:n
    ca = '(none)'; cb = '(none)';
    if k <= numel(a), ca = callText(a{k}); end
    if k <= numel(b), cb = callText(b{k}); end
    if ~strcmp(ca, cb)
        lines{end+1} = sprintf('    call %d before: %s\n    call %d after:  %s', k, ca, k, cb); %#ok<AGROW>
    end
end
s = strjoin(lines, newline);
end

function s = callText(c)
args = cellfun(@valueText, c{2}, 'UniformOutput', false);
s = sprintf('%s(%s)', c{1}, strjoin(args, ', '));
end

function s = valueText(v)
if ischar(v)
    s = ['''' v ''''];
elseif isnumeric(v) || islogical(v)
    s = mat2str(v);
elseif iscell(v)
    s = ['{' strjoin(cellfun(@valueText, v, 'UniformOutput', false), ', ') '}'];
elseif isstruct(v)
    s = sprintf('<struct %s>', strjoin(fieldnames(v)', ','));
else
    s = sprintf('<%s>', class(v));
end
end

function s = firstLine(s)
s = strtok(s, newline);
end

function cleanUp(work)
global NESTAPP_ARGCAP %#ok<GVMIS>
NESTAPP_ARGCAP = [];
w = warning('off', 'MATLAB:rmpath:DirNotFound');
rmpath(fullfile(work, 'shadow'));
warning(w);
rehash;
if isfolder(work), rmdir(work, 's'); end
end
