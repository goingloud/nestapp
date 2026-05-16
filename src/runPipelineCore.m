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
useParallel = false;
if opts.parallel
    if nFiles <= 1
        fprintf('[nestapp] Parallel mode skipped: only %d file selected (need >1).\n', nFiles);
    elseif ~license('test', 'Distrib_Computing_Toolbox')
        fprintf('[nestapp] Parallel mode skipped: Parallel Computing Toolbox not licensed.\n');
    elseif isInteractivePipeline(spec, opts)
        interactiveSteps = findInteractiveSteps(spec, opts);
        fprintf('[nestapp] Parallel mode skipped: interactive step(s) detected: %s\n', ...
            strjoin(interactiveSteps, ', '));
    else
        useParallel = true;
    end
end

if useParallel
    fprintf('[nestapp] Starting parallel run (%d files).\n', nFiles);
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

% Propagate paths to workers only (spmd, unlike pctRunOnAll, skips the client
% — avoids shadowing MATLAB built-ins with EEGLAB subdirectories on the client).
nestappSrc    = fileparts(which('runPipelineCore'));
eeglabGenpath = genpath(fileparts(which('eeglab')));
spmd
    if ~isempty(nestappSrc),    addpath(nestappSrc);    end
    if ~isempty(eeglabGenpath), addpath(eeglabGenpath); end
end

nBars = min(nFiles, nWorkers);
dlg   = createParallelDlg(opts.uiFigure, nBars, nFiles);
% Give the uihtml web view time to load before the first DataQueue message.
pause(1.5); drawnow;

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

% Submit one future per file (forward order — MATLAB grows the array by 1 each
% iteration, which avoids the no-default-constructor issue for FevalFuture).
for fi = 1:nFiles
    workerOpts.fileIndex = fi;
    futures(fi) = parfeval(@processOneFile, 2, spec, filePaths{fi}, workerOpts); %#ok<AGROW>
end

% Poll until all futures finish or user cancels.
cancelled = false;
while true
    pause(0.25); drawnow;
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
failedFiles  = {};
for fi = 1:nFiles
    [~, fname] = fileparts(filePaths{fi});
    if strcmp(futures(fi).State, 'finished') && isempty(futures(fi).Error)
        [fileReport, ~] = fetchOutputs(futures(fi));
        [pathDir, ~, ~] = fileparts(filePaths{fi});
        [summaryText, ~] = exportReport(fileReport, [pathDir, filesep]);
        allReports{end+1}   = fileReport;   %#ok<AGROW>
        allSummaries{end+1} = summaryText;  %#ok<AGROW>
    elseif ~isempty(futures(fi).Error)
        failedFiles{end+1} = fname; %#ok<AGROW>
        fprintf('[nestapp] Worker failed on %s: %s\n', fname, futures(fi).Error.message);
    end
end

if ~isempty(failedFiles)
    fprintf('[nestapp] %d/%d files failed in parallel mode.\n', numel(failedFiles), nFiles);
    if numel(failedFiles) == nFiles
        % All files failed — surface the first error so the user knows what went wrong.
        firstErr = futures(find(arrayfun(@(f) ~isempty(f.Error), futures), 1)).Error;
        error('nestapp:parallelFailed', ...
            'All %d files failed in parallel mode.\n\nFirst error: %s\n\nCheck that EEGLAB is on the MATLAB path and all pipeline steps are compatible with parallel execution.', ...
            nFiles, firstErr.message);
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
slot  = mod(msg.fi - 1, nBars) + 1;
nDone = dlg.fig.UserData.nDone;
if msg.si == msg.nSteps
    ud       = dlg.fig.UserData;
    ud.nDone = ud.nDone + 1;
    dlg.fig.UserData = ud;
    nDone = ud.nDone;
end
dlg.html.Data = struct( ...
    'slot',     slot, ...
    'fi',       msg.fi, ...
    'si',       msg.si, ...
    'nSteps',   msg.nSteps, ...
    'stepName', msg.stepName, ...
    'nDone',    nDone, ...
    'nFiles',   nFiles, ...
    'nBars',    nBars);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parallel progress dialog

function dlg = createParallelDlg(parentFig, nBars, nFiles)
figW = 460;
btnH = 32;

% Height: 20px header + 52px per slot + 80px overall section + 20px padding
figH = 20 + nBars * 52 + 80 + 20 + btnH + 12;

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
    'Color', [0.97 0.97 0.98], ...
    'Resize', 'off');
dlg.fig.UserData = struct('cancelRequested', false, 'nDone', 0);

uibutton(dlg.fig, 'push', 'Text', 'Cancel', ...
    'Position', [(figW-100)/2, 8, 100, btnH], ...
    'ButtonPushedFcn', @(~,~) setCancelFlag(dlg.fig));

htmlH = figH - btnH - 16;
dlg.html = uihtml(dlg.fig, ...
    'Position', [0, btnH + 16, figW, htmlH], ...
    'HTMLSource', buildProgressHTML(nBars, nFiles));

drawnow;
end

function src = buildProgressHTML(nBars, nFiles)
% Slot rows built at JS init time from nBars injected as a literal.
src = sprintf([ ...
'<!DOCTYPE html><html><head><meta charset="utf-8">' ...
'<style>' ...
'*{box-sizing:border-box;margin:0;padding:0}' ...
'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;' ...
'     background:#f7f8fa;padding:14px 14px 6px;color:#1e293b}' ...
'.section-title{font-size:11px;font-weight:600;text-transform:uppercase;' ...
'               letter-spacing:.06em;color:#64748b;margin-bottom:6px}' ...
'.overall-count{font-size:14px;font-weight:700;color:#0f172a;margin-bottom:6px}' ...
'.track{height:20px;background:#e2e8f0;border-radius:10px;overflow:hidden;' ...
'       margin-bottom:16px;box-shadow:inset 0 1px 3px rgba(0,0,0,.12)}' ...
'.slot-track{height:14px;border-radius:7px}' ...
'@keyframes stripe{from{background-position:28px 0}to{background-position:0 0}}' ...
'.bar{height:100%;border-radius:inherit;width:0%%;transition:width .35s ease}' ...
'.bar-active{background:repeating-linear-gradient(45deg,' ...
'  #3b82f6 0,#3b82f6 10px,#60a5fa 10px,#60a5fa 20px);' ...
'  animation:stripe .65s linear infinite}' ...
'.bar-overall{background:repeating-linear-gradient(45deg,' ...
'  #10b981 0,#10b981 10px,#34d399 10px,#34d399 20px);' ...
'  animation:stripe .65s linear infinite}' ...
'.bar-idle{background:#cbd5e1;transition:none}' ...
'.bar-done{background:#10b981;animation:none;transition:width .15s ease}' ...
'.slot{margin-bottom:10px}' ...
'.slot-label{font-size:12px;color:#475569;margin-bottom:3px;' ...
'            white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' ...
'</style></head><body>' ...
'<div class="section-title">Overall progress</div>' ...
'<div class="overall-count" id="overallCount">0 / %d files complete</div>' ...
'<div class="track"><div class="bar bar-overall" id="overallBar"></div></div>' ...
'<div class="section-title" style="margin-bottom:8px">Workers</div>' ...
'<div id="slots"></div>' ...
'<script>' ...
'var nBars=%d,nFiles=%d;' ...
'(function init(){' ...
'  var h="";' ...
'  for(var i=1;i<=nBars;i++){' ...
'    h+=''<div class="slot">''' ...
'       +''<div class="slot-label" id="lbl''+i+''">Worker ''+i+'': Idle</div>''' ...
'       +''<div class="track slot-track">''' ...
'       +''  <div class="bar bar-idle" id="bar''+i+''"></div>''' ...
'       +''</div></div>'';' ...
'  }' ...
'  document.getElementById("slots").innerHTML=h;' ...
'})();' ...
'window.addEventListener("DataChanged",function(e){' ...
'  var d=e.Data;if(!d)return;' ...
'  var slot=d.slot;' ...
'  var bar=document.getElementById("bar"+slot);' ...
'  var lbl=document.getElementById("lbl"+slot);' ...
'  var pct=(d.si/d.nSteps*100).toFixed(1)+"%%";' ...
'  if(bar){bar.className="bar bar-active";bar.style.width=pct;}' ...
'  if(lbl){lbl.textContent=' ...
'    "File "+d.fi+" — "+d.stepName+"  ("+d.si+"/"+d.nSteps+")";}' ...
'  var op=(d.nDone/d.nFiles*100).toFixed(1)+"%%";' ...
'  var ob=document.getElementById("overallBar");' ...
'  if(ob)ob.style.width=op;' ...
'  document.getElementById("overallCount").textContent=' ...
'    d.nDone+" / "+d.nFiles+" files complete";' ...
'  if(d.si===d.nSteps){' ...
'    if(bar){bar.className="bar bar-done";bar.style.width="100%%";}' ...
'    setTimeout(function(){' ...
'      if(bar){bar.className="bar bar-idle";bar.style.width="0%%";}' ...
'      if(lbl){lbl.textContent="Worker "+slot+": Idle";}' ...
'    },800);' ...
'  }' ...
'});' ...
'</script></body></html>' ...
], nFiles, nBars, nFiles);
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
result = ~isempty(findInteractiveSteps(spec, opts));
end

function steps = findInteractiveSteps(spec, opts)
% Returns cell array of step names that require GUI dialogs.
ALWAYS_INTERACTIVE = {'Visualize EEG Data', 'Remove Bad Trials', 'Choose Data Set'};
steps = {};
for si = 1:numel(spec)
    name = spec(si).name;
    if any(strcmp(name, ALWAYS_INTERACTIVE))
        steps{end+1} = name; %#ok<AGROW>
    elseif strcmp(name, 'Remove ICA Components (TESA)')
        % Interactive when compCheck is 'on' (opens component selection GUI).
        p = spec(si).params;
        if ~isfield(p, 'compCheck') || strcmp(p.compCheck, 'on')
            steps{end+1} = name; %#ok<AGROW>
        end
    elseif strcmp(name, 'Load Channel Location')
        p            = spec(si).params;
        eachFileDiff = isfield(p, 'eachFilediffPath') && strcmp(p.eachFilediffPath, 'yes');
        needChan     = isfield(p, 'needchanloc') && strcmp(p.needchanloc, 'yes');
        if eachFileDiff || (needChan && isempty(opts.chanLocFile))
            steps{end+1} = name; %#ok<AGROW>
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
