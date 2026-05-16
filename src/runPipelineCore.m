function [allReports, allSummaries] = runPipelineCore(spec, filePaths, opts)
% RUNPIPELINECORE Execute a typed pipeline spec against a list of files.
%   [allReports, allSummaries] = RUNPIPELINECORE(spec, filePaths, opts)
%
%   spec      — struct array of PipelineStep (name + params struct)
%   filePaths — cell array of full absolute file paths
%   opts      — struct with optional fields:
%     .uiFigure     UIFigure handle (required for interactive steps/dialogs)
%     .pipelineName pipeline name string for EEG.history provenance
%     .statusBar    text component for status line messages
%     .parallel     logical — request parallel execution (default false)
%     .chanLocFile  pre-selected channel location file path (default '')
%
%   See also: processOneFile, initPipelineReport, exportReport

if nargin < 3, opts = struct(); end
if ~isfield(opts, 'pipelineName'), opts.pipelineName = ''; end
if ~isfield(opts, 'statusBar'),    opts.statusBar    = []; end
if ~isfield(opts, 'parallel'),     opts.parallel     = false; end
if ~isfield(opts, 'chanLocFile'),  opts.chanLocFile  = ''; end

nFiles = numel(filePaths);
nSteps = numel(spec);

allSummaries = {};
allReports   = {};

if nFiles == 0 || nSteps == 0; return; end

% Dependency check before touching any file.
stepNames = {spec.name};
[depsOk, depsMsg] = checkStepDependencies(stepNames, filePaths);
if ~depsOk
    uialert(opts.uiFigure, depsMsg, 'Missing Dependencies', 'Icon', 'error');
    return
end

% Pre-flight overwrite check.
if getpref('nestapp', 'suppressEEGLABDialogs', true)
    warnIfOverwriteFiles(spec, filePaths, opts);
end

% Parallel requires PCT license, no interactive steps, and > 1 file.
useParallel = opts.parallel && nFiles > 1 && ...
              license('test', 'Distrib_Computing_Toolbox') && ...
              ~isInteractivePipeline(spec, opts);

if useParallel
    [allReports, allSummaries] = runParallel(spec, filePaths, opts);
else
    [allReports, allSummaries] = runSerial(spec, filePaths, opts);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Serial execution

function [allReports, allSummaries] = runSerial(spec, filePaths, opts)
nFiles = numel(filePaths);
nSteps = numel(spec);

allReports   = {};
allSummaries = {};

dlg = uiprogressdlg(opts.uiFigure, ...
    'Title',          'Running Pipeline', ...
    'Message',        'Initialising...', ...
    'Cancelable',     'on', ...
    'ShowPercentage', 'on');

cancelled = false;

for nfile = 1:nFiles
    fullPath = filePaths{nfile};
    [pathDir, ~, ~] = fileparts(fullPath);
    pathName = [pathDir, filesep];

    if dlg.CancelRequested
        cancelled = true;
        break
    end

    % Closures capture dlg, nfile, nFiles, nSteps, opts.statusBar by reference.
    fileOpts = opts;
    fileOpts.progressFcn   = @(si, sn) serialProgress(dlg, nfile, si, nFiles, nSteps, sn, opts.statusBar);
    fileOpts.onStepError   = @(si, sn, err) uiconfirm(opts.uiFigure, ...
        sprintf('Error at step %d (%s):\n%s\n\nContinue to next step?', si, sn, err.message), ...
        'Step Failed', 'Options', {'Continue','Abort'}, ...
        'DefaultOption', 'Continue', 'CancelOption', 'Abort');
    fileOpts.onPickChanFile = @() pickChanFile(opts.uiFigure);
    fileOpts.progressQueue  = [];
    fileOpts.fileIndex      = nfile;

    try
        [fileReport, ~] = processOneFile(spec, fullPath, fileOpts);
    catch err
        if strcmp(err.identifier, 'nestapp:cancelled')
            cancelled = true;
            break
        end
        [~, fname] = fileparts(fullPath);
        uialert(opts.uiFigure, ...
            sprintf('File %d (%s) failed:\n%s', nfile, fname, err.message), ...
            'File Error', 'Icon', 'warning');
        continue
    end

    [summaryText, ~] = exportReport(fileReport, pathName);
    allSummaries{end+1} = summaryText; %#ok<AGROW>
    allReports{end+1}   = fileReport;  %#ok<AGROW>

    if ~getpref('nestapp', 'hideEEGLABWindow', true)
        eeglab redraw
    end
    disp('-----------------Data processed!-----------------')
end

if isvalid(dlg); close(dlg); end
if cancelled
    error('nestapp:cancelled', 'Pipeline cancelled.');
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parallel execution

function [allReports, allSummaries] = runParallel(spec, filePaths, opts)
nFiles     = numel(filePaths);
maxWorkers = getpref('nestapp', 'maxParallelWorkers', 4);
nWorkers   = min(nFiles, maxWorkers);

% Start or reuse pool.
pool = gcp('nocreate');
if isempty(pool)
    parpool(nWorkers);
    pool = gcp('nocreate');
end
nWorkers = min(nWorkers, pool.NumWorkers);

% Put EEGLAB on every worker's path.
eeglabDir = fileparts(which('eeglab'));
if ~isempty(eeglabDir)
    pctRunOnAll(['addpath(genpath(''' strrep(eeglabDir,'\','\\') '''));']);
end

nBars = min(nFiles, nWorkers);
dlg   = createParallelDlg(opts.uiFigure, nBars, nFiles);

% DataQueue for worker -> main progress messages.
q = parallel.pool.DataQueue;
afterEach(q, @(msg) updateParallelProgress(dlg, msg, nBars, nFiles));

% Build plain-data worker opts (no UI handles).
workerOpts.pipelineName   = opts.pipelineName;
workerOpts.chanLocFile    = opts.chanLocFile;
workerOpts.progressFcn    = [];
workerOpts.progressQueue  = q;
workerOpts.onStepError    = [];
workerOpts.onPickChanFile = [];
workerOpts.uiFigure       = [];

% Submit all futures.
futures(nFiles) = parallel.FevalFuture;
for fi = 1:nFiles
    workerOpts.fileIndex = fi;
    futures(fi) = parfeval(@processOneFile, 2, spec, filePaths{fi}, workerOpts);
end

% Poll until all futures finish or user cancels.
cancelled = false;
while true
    pause(0.1);
    if ~isvalid(dlg.fig) || dlg.fig.UserData.cancelRequested
        cancel(futures);
        cancelled = true;
        break
    end
    states = {futures.State};
    if all(strcmp(states, 'finished') | strcmp(states, 'failed')); break; end
end

if isvalid(dlg.fig); close(dlg.fig); end

% Collect results from finished futures.
allReports   = {};
allSummaries = {};
for fi = 1:nFiles
    if strcmp(futures(fi).State, 'finished') && isempty(futures(fi).Error)
        [fileReport, ~] = fetchOutputs(futures(fi));
        [pathDir, ~, ~] = fileparts(filePaths{fi});
        [summaryText, ~] = exportReport(fileReport, [pathDir, filesep]);
        allReports{end+1}   = fileReport;   %#ok<AGROW>
        allSummaries{end+1} = summaryText;  %#ok<AGROW>
    elseif ~isempty(futures(fi).Error)
        [~, fname] = fileparts(filePaths{fi});
        warning('nestapp:parallelFileFailed', 'File %s failed: %s', ...
            fname, futures(fi).Error.message);
    end
end

if cancelled && isempty(allReports)
    error('nestapp:cancelled', 'Parallel pipeline cancelled.');
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parallel progress update (local function — no nested function restriction)

function updateParallelProgress(dlg, msg, nBars, nFiles)
if ~isvalid(dlg.fig); return; end
slot = mod(msg.fi - 1, nBars) + 1;
dlg.bars(slot).Value  = msg.si / msg.nSteps;
dlg.labels(slot).Text = sprintf('File %d \x2014 %s', msg.fi, msg.stepName);
if msg.si == msg.nSteps
    ud       = dlg.fig.UserData;
    ud.nDone = ud.nDone + 1;
    dlg.fig.UserData      = ud;
    dlg.overallBar.Value  = ud.nDone / nFiles;
    dlg.overallLabel.Text = sprintf('%d / %d files complete', ud.nDone, nFiles);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parallel progress dialog

function dlg = createParallelDlg(parentFig, nBars, nFiles)
PAD  = 12;
figW = 450;
barW = figW - 2*PAD;

btnH        = 28;
overallBarH = 22;
overallLblH = 18;
headerH     = 20;
slotBarH    = 22;
slotLblH    = 18;
slotH       = slotBarH + 4 + slotLblH + 10;

yBtn        = PAD;
yOverallBar = yBtn + btnH + PAD;
yOverallLbl = yOverallBar + overallBarH + 4;
yHeader     = yOverallLbl + overallLblH + PAD;
ySlot1      = yHeader + headerH + 6;

figH = ySlot1 + nBars * slotH + PAD;

if ~isempty(parentFig) && isvalid(parentFig)
    pPos = parentFig.Position;
    figX = pPos(1) + (pPos(3) - figW) / 2;
    figY = pPos(2) + (pPos(4) - figH) / 2;
else
    sc   = get(0, 'ScreenSize');
    figX = (sc(3) - figW) / 2;
    figY = (sc(4) - figH) / 2;
end

dlg.fig = uifigure('Name', 'Running Pipeline (Parallel)', ...
    'Position', [figX figY figW figH], ...
    'Resize', 'off');
dlg.fig.UserData = struct('cancelRequested', false, 'nDone', 0);

uibutton(dlg.fig, 'push', 'Text', 'Cancel', ...
    'Position', [(figW-100)/2, yBtn, 100, btnH], ...
    'ButtonPushedFcn', @(~,~) setCancelFlag(dlg.fig));

dlg.overallBar = uiprogressbar(dlg.fig, ...
    'Position', [PAD, yOverallBar, barW, overallBarH], ...
    'Value', 0);
dlg.overallLabel = uilabel(dlg.fig, ...
    'Text', sprintf('0 / %d files complete', nFiles), ...
    'Position', [PAD, yOverallLbl, barW, overallLblH]);

uilabel(dlg.fig, 'Text', 'Worker threads:', ...
    'FontWeight', 'bold', ...
    'Position', [PAD, yHeader, barW, headerH]);

dlg.bars   = gobjects(1, nBars);
dlg.labels = gobjects(1, nBars);
for i = 1:nBars
    yBar = ySlot1 + (i-1)*slotH;
    yLbl = yBar + slotBarH + 4;
    dlg.bars(i) = uiprogressbar(dlg.fig, ...
        'Position', [PAD, yBar, barW, slotBarH], ...
        'Value', 0);
    dlg.labels(i) = uilabel(dlg.fig, ...
        'Text', sprintf('Worker %d: Idle', i), ...
        'Position', [PAD, yLbl, barW, slotLblH]);
end

drawnow;
end

function setCancelFlag(fig)
ud = fig.UserData;
ud.cancelRequested = true;
fig.UserData = ud;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Shared serial helpers

function serialProgress(dlg, nfile, si, nFiles, nSteps, stepName, statusBar)
if dlg.CancelRequested
    error('nestapp:cancelled', 'Pipeline cancelled by user.');
end
dlg.Value   = ((nfile-1)*nSteps + si - 1) / (nFiles * nSteps);
dlg.Message = sprintf('File %d / %d  \x2014  %s', nfile, nFiles, stepName);
if ~isempty(statusBar) && isvalid(statusBar)
    statusBar.Text = sprintf('  File %d / %d \x2014 %s', nfile, nFiles, stepName);
end
end

function chFile = pickChanFile(uiFig)
[chName, chPath] = uigetfile('*.*', 'Select a channel location file', ...
    'Parent', uiFig);
if isequal(chName, 0)
    error('nestapp:cancelled', 'Channel location file selection cancelled.');
end
chFile = fullfile(chPath, chName);
end

function result = isInteractivePipeline(spec, opts)
% Returns true if any step requires a GUI dialog during execution.
ALWAYS_INTERACTIVE = {'Visualize EEG Data', 'Remove Bad Trials', ...
                      'Choose Data Set', 'Remove ICA Components (TESA)'};
result = false;
for si = 1:numel(spec)
    name = spec(si).name;
    if any(strcmp(name, ALWAYS_INTERACTIVE))
        result = true;
        return
    end
    if strcmp(name, 'Load Channel Location')
        p            = spec(si).params;
        eachFileDiff = isfield(p, 'eachFilediffPath') && strcmp(p.eachFilediffPath, 'yes');
        needChan     = isfield(p, 'needchanloc') && strcmp(p.needchanloc, 'yes');
        if eachFileDiff || (needChan && isempty(opts.chanLocFile))
            result = true;
            return
        end
    end
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Pre-flight helpers

function warnIfOverwriteFiles(spec, filePaths, opts)
% Check whether Save New Set would overwrite existing .set files.
% Throws 'nestapp:cancelled' if the user cancels.
saveIdx = find(strcmp({spec.name}, 'Save New Set'), 1);
if isempty(saveIdx); return; end

p = spec(saveIdx).params;
savenew = '';
ifn     = 'yes';
if isfield(p, 'savenew') && ischar(p.savenew) && ~strcmp(p.savenew, '[]') && ~isempty(p.savenew)
    savenew = p.savenew;
end
if isfield(p, 'includeFileName')
    ifn = p.includeFileName;
end
if isempty(savenew); return; end

nFiles   = numel(filePaths);
existing = {};
for fi = 1:nFiles
    [fdir, fbase] = fileparts(filePaths{fi});
    if strcmpi(ifn, 'yes')
        stem    = replace(replace(fullfile(fdir, fbase), ' ', '_'), '-', '_');
        outName = [stem, '_', savenew, '.set'];
    else
        outName = fullfile(fdir, [savenew, '.set']);
    end
    if exist(outName, 'file')
        [~, dispName] = fileparts(outName);
        existing{end+1} = [dispName, '.set']; %#ok<AGROW>
    end
end
if isempty(existing); return; end

msg = sprintf(['%d output file(s) already exist and will be overwritten:\n\n' ...
    '%s\n\nContinue?'], numel(existing), strjoin(existing, '\n'));
answer = uiconfirm(opts.uiFigure, msg, 'Output Files Exist', ...
    'Options', {'Continue', 'Cancel'}, ...
    'DefaultOption', 2, 'CancelOption', 2, ...
    'Icon', 'warning');
if strcmp(answer, 'Cancel')
    error('nestapp:cancelled', 'Run cancelled by user.');
end
end
