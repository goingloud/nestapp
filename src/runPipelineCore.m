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

if nargin < 3, opts = struct(); end
if ~isfield(opts, 'pipelineName'), opts.pipelineName = ''; end
if ~isfield(opts, 'statusBar'),    opts.statusBar    = []; end

global EEG ALLEEG CURRENTSET ALLCOM %#ok<GVMIS>

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

dlg = uiprogressdlg(opts.uiFigure, ...
    'Title',          'Running Pipeline', ...
    'Message',        'Initialising...', ...
    'Cancelable',     'on', ...
    'ShowPercentage', 'on');

% chName persists across files so the user picks the channel location file
% only once per run (not once per file).
chName = [];

for nfile = 1:nFiles
    fullPath = filePaths{nfile};
    [pathDir, fileBase, fileExt] = fileparts(fullPath);
    pathName = [pathDir, filesep];
    fileName = [fileBase, fileExt];

    ALLEEG = []; EEG = []; CURRENTSET = 0; ALLCOM = {};

    % Per-file state reset — prevents ICA state from bleeding between files.
    ICA_Rejected_Comp = {};
    interpElecs       = {};
    pendingICAStats   = struct();
    histLenBefore     = 0;

    disp(['!--------FILE ', fileName, ' IS BEING PROCESSED--------!'])

    stepLog = struct('step',{},'duration_s',{},'chanBefore',{},'chanAfter',{}, ...
                     'epochBefore',{},'epochAfter',{},'error',{});
    fileReport = initPipelineReport(fullPath);

    for si = 1:nSteps
        step     = spec(si);
        stepName = step.name;
        varin    = paramsToVarin(step.params);

        dlg.Value   = ((nfile-1)*nSteps + si - 1) / (nFiles * nSteps);
        dlg.Message = sprintf('File %d / %d  \x2014  %s', nfile, nFiles, stepName);
        if dlg.CancelRequested
            writeSessionLog(pathName, fileName, stepLog);
            close(dlg);
            return
        end

        if ~isempty(opts.statusBar)
            opts.statusBar.Text = sprintf('  File %d / %d \x2014 %s', nfile, nFiles, stepName);
        end
        disp(strcat('step ', num2str(si), ': "', stepName, '" is running!'));

        if isstruct(EEG) && ~isempty(EEG)
            nChanBefore  = EEG.nbchan;
            nEpochBefore = size(EEG.data, 3);
        else
            nChanBefore  = 0;
            nEpochBefore = 0;
        end
        t0 = tic;

        try
            switch stepName
                case 'Load Channel Location'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmpi(vars,'eachFilediffPath'));
                    eachFilediffPath = vars{ind1+1};
                    ind2 = find(strcmpi(vars,'needchanloc'));
                    needchanloc = vars{ind2+1};

                    if strcmp(eachFilediffPath,'yes')
                        needchanloc='yes';
                        chName = [];
                    end
                    if strcmp(needchanloc,'yes')
                        if isempty(chName)
                            pathEEGLAB = which('eeglab');
                            if isunix
                                pathEEGLAB = replace(pathEEGLAB,'\','/');
                                pathEEGLAB = replace(pathEEGLAB,'eeglab.m','');
                                D = dir([pathEEGLAB,'plugins/dipfit*']);
                                lookforchnlocs = [D.folder,'/',D.name,'/standard_BEM/elec/standard_1005.elc'];
                            elseif ispc
                                pathEEGLAB = replace(pathEEGLAB,'/','\');
                                pathEEGLAB = replace(pathEEGLAB,'eeglab.m','');
                                D = dir([pathEEGLAB,'plugins\dipfit*']);
                                lookforchnlocs = [D.folder,'\',D.name,'\standard_BEM\elec\standard_1005.elc'];
                            end
                            [chName,chPath] = uigetfile('*.*','Select a file');
                        end
                        EEG = pop_chanedit(EEG, 'lookup', lookforchnlocs, ...
                            'load', {[chPath,chName],'filetype','autodetect'});
                        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
                    end

                case 'Load Data'
                    mode = varin{1,2};
                    if   strcmpi(fileName(end-2:end),'set')
                        EEG = pop_loadset( [pathName fileName]);
                    elseif strcmpi(fileName(end-2:end),'cnt')
                        EEG = pop_loadcnt([pathName fileName] , 'dataformat', 'int32' );
                    elseif strcmpi(fileName(end-2:end),'cdt')
                        EEG = loadcurry([pathName fileName], 'CurryLocations', 'False');
                    elseif strcmpi(fileName(end-3:end),'vhdr')
                        EEG = pop_loadbv(pathName , fileName );
                    end
                    EEG.filename = fileName;
                    if strcmpi(mode,'on')
                        % eeglab redraw
                    end
                    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
                    if isfield(EEG, 'history')
                        histLenBefore = numel(EEG.history);
                    end

                case 'Save New Set'
                    EEG = eeg_checkset( EEG );
                    vars = convertContainedStringsToChars(varin);
                    inds = find(strcmpi(vars,'includeFileName'));
                    IFN = vars{inds + 1};
                    vars([inds, inds+1]) = [];
                    fname = '';
                    if strcmp(IFN,'yes')
                        [fdir, fbase, ~] = fileparts(fullfile(pathName, fileName));
                        fbase = replace(fbase, ' ', '_');
                        fbase = replace(fbase, '-', '_');
                        fname = fullfile(fdir, [fbase, '_']);
                    end
                    ind1 = find(strcmp(vars,'savenew'));
                    sv1 = vars{ind1+1};
                    if ischar(sv1) && ~isempty(sv1) && ~strcmp(sv1,'[]')
                        vars{ind1+1} = [fname, sv1];
                    end
                    ind2 = find(strcmp(vars,'saveold'));
                    sv2 = vars{ind2+1};
                    if ischar(sv2) && ~isempty(sv2) && ~strcmp(sv2,'[]')
                        vars{ind2+1} = [fname, sv2];
                    end
                    vars = stripEmptyVarin(vars);
                    % 'retrieve' (NaN when unused) is already stripped above
                    EEG = eeg_checkset(EEG);
                    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,vars{:});

                case 'Manual Command'
                    cmd = step.params.command;
                    if ischar(cmd) && ~isrow(cmd)
                        cmd = strjoin(cellstr(cmd), newline);
                    elseif iscell(cmd)
                        cmd = strjoin(cmd(:)', newline);
                    end
                    eval(cmd);

                case 'Choose Data Set'
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmp(vars,'dataSetInd'));
                    setIndex = vars{ind+1};
                    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'retrieve',setIndex);

                case 'Visualize EEG Data'
                    if sum(isnan(varin{1,2}))
                        pop_eegplot(EEG);
                    else
                        pop_eegplot(EEG, varin{1,2}(1),varin{1,2}(2),varin{1,2}(3));
                    end
                    uiconfirm(opts.uiFigure,'Press OK when done viewing the EEG plot.','Visualize EEG','Options',{'OK'},'DefaultOption',1);

                case 'Remove un-needed Channels'
                    vars = convertContainedStringsToChars(varin);
                    vars = stripEmptyVarin(vars);
                    EEG = pop_select( EEG,vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Remove Bad Channels'
                    vars = convertContainedStringsToChars(varin);
                    EEGelecNames = {EEG.chanlocs(1:end).labels};
                    ind1 = find(strcmpi(vars,'impelec'));
                    AuximportantElects = vars{ind1+1};
                    importantElects = matches(EEGelecNames, AuximportantElects,"IgnoreCase",true);
                    vars([ind1, ind1+1]) = [];

                    ind2 = find(strcmpi(vars,'elec'));
                    if strcmp(vars{1,ind2+1},'[]')
                        vars{1,ind2+1} = 1:EEG.nbchan;
                    elseif iscell(vars{1,ind2+1})
                        vars{1,ind2+1} = find(ismember(EEGelecNames, vars{1,ind2+1}));
                    else
                        vars{1,ind2+1} = 1:EEG.nbchan;
                    end

                    ind3 = find(strcmpi(vars,'freqrange'));
                    if sum(isnan(vars{ind3+1})) || strcmpi(vars{ind3},'[]')
                        vars([ind3, ind3+1]) = [];
                    end

                    if sum(importantElects)
                        vars{1,ind2+1} = find(~importantElects);
                        EEG = pop_rejchan(EEG, vars{:});
                    else
                        EEG = pop_rejchan(EEG, vars{:});
                    end

                case 'Automatic Continuous Rejection'
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmpi(vars,'elecrange'));
                    if max(vars{ind+1})>EEG.nbchan
                        elecrange = 1:EEG.nbchan;
                    else
                        elecrange = vars{ind+1}(1):vars{ind+1}(end);
                    end
                    vars([ind,ind+1]) = [];
                    EEG = pop_rejcont(EEG,'elecrange',elecrange,vars{:});

                case 'Clean Artifacts'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmpi(vars,'Channels'));
                    ind2 = find(strcmpi(vars,'Channels_ignore'));
                    if sum(strcmpi(vars{ind1+1},'[]')) && sum(strcmpi(vars{ind2+1},'[]'))
                        chans = {EEG.chanlocs.labels};
                        vars{ind1+1} = chans;
                        vars{ind2+1} = [];
                    elseif sum(strcmpi(vars{ind1+1},'[]')) && sum(~strcmpi(vars{ind2+1},'[]'))
                        if size(vars{ind2+1},1)>size(vars{ind2},2)
                            vars{ind2+1} = vars{ind2+1}';
                        end
                        vars([ind1 ind1+1]) = [];
                    elseif sum(~strcmpi(vars{ind1+1},'[]')) && sum(strcmpi(vars{ind2+1},'[]'))
                        if size(vars{ind1+1},1)>size(vars{ind1},2)
                            vars{ind1+1} = vars{ind1+1}';
                        end
                        vars([ind2 ind2+1]) = [];
                    end
                    EEG = clean_artifacts(EEG,vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Automatic Cleaning Data'
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmp(vars,'Highpass'));
                    if ~strcmpi(vars{ind+1},'off')
                        highpass = vars{ind+1};
                        if ischar(highpass) || isstring(highpass)
                            highpass = str2double(highpass);
                        end
                        if size(highpass,2)<size(highpass,1)
                            highpass = highpass';
                        end
                        vars{ind+1} = highpass;
                    end
                    vars = stripEmptyVarin(vars);
                    EEG = pop_clean_rawdata(EEG, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Remove Baseline'
                    vars = convertContainedStringsToChars(varin);
                    timerange = vars{2};
                    if ischar(timerange) && strcmp(timerange, '[]')
                        timerange = [];
                    elseif ischar(timerange) || isstring(timerange)
                        timerange = str2num(char(timerange)); %#ok<ST2NM>
                    end
                    if isnumeric(timerange) && numel(timerange) == 2
                        timerange(1) = max(timerange(1), EEG.times(1));
                        timerange(2) = min(timerange(2), EEG.times(end));
                    end
                    EEG = pop_rmbase(EEG, timerange);
                    EEG = eeg_checkset(EEG);

                case 'De-Trend Epoch'
                    vars = convertContainedStringsToChars(varin);
                    [nCh, nT, nEp] = size(EEG.data);
                    d2 = reshape(permute(EEG.data, [2 1 3]), nT, nCh*nEp);
                    d2 = detrend(d2, vars{1,2});
                    EEG.data = permute(reshape(d2, nT, nCh, nEp), [2 1 3]);
                    EEG = eeg_checkset( EEG );

                case 'TESA De-Trend'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmpi(vars,'detrend'));
                    Tdetrend = vars{ind1+1};
                    ind2 = find(strcmpi(vars,'timeWin'));
                    TtimeWin = vars{ind2+1};
                    pop_tesa_detrend(EEG, Tdetrend, TtimeWin)

                case 'Re-Sample'
                    vars = convertContainedStringsToChars(varin);
                    EEG = pop_resample(EEG,vars{2:2:end});
                    EEG = eeg_checkset( EEG );

                case 'Re-Reference'
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmp(vars,'ref'));
                    ref = vars{ind+1};
                    if ~ismember(ref,{EEG.chanlocs.labels}) && ~strcmp(ref,'[]')
                        answer = inputdlg('The reference channel is not in the data. Enter a new reference channel label:','Re-Reference',[1 50],{''});
                        if isempty(answer) || isempty(answer{1})
                            error('Re-Reference cancelled: no reference channel provided.');
                        end
                        ref = answer{1};
                    end
                    if strcmp(ref,'[]')
                        ref = eval(ref);
                    end
                    vars([ind,ind+1]) = [];
                    vars = stripEmptyVarin(vars);
                    EEG = pop_reref(EEG,ref, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Frequency Filter (CleanLine)'
                    if ~exist('hlp_varargin2struct', 'file')
                        cleanlineRoot = fileparts(which('pop_cleanline'));
                        if ~isempty(cleanlineRoot)
                            addpath(genpath(cleanlineRoot));
                        end
                    end
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmp(vars,'chanlist'));
                    if vars{ind+1}(2) > EEG.nbchan
                        vars{ind+1} = 1:EEG.nbchan-1;
                    else
                        vars{ind+1} = 1:vars{1,ind+1};
                    end
                    EEG = pop_cleanline(EEG, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Frequency Filter (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmp(vars,'high'));
                    high = vars{ind1+1};
                    ind2 = find(strcmp(vars,'low'));
                    low = vars{ind2+1};
                    ind3 = find(strcmp(vars,'ord'));
                    ord = vars{ind3+1};
                    ind4 = find(strcmp(vars,'type'));
                    type = vars{ind4+1};
                    vars([ind1,ind1+1,ind2,ind2+2,ind3,ind3+1]) = []; %#ok<NASGU>
                    EEG = pop_tesa_filtbutter( EEG, high, low, ord, type );
                    EEG = eeg_checkset( EEG );

                case 'Frequency Filter'
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmp(vars,'filtorder'));
                    if mod(vars{ind+1},2)~=0 || isstring(vars{ind})
                        error('The Filtorder should be an even number!')
                    elseif vars{ind+1}==0
                        vars([ind, ind+1]) = [];
                    end
                    EEG = pop_eegfiltnew(EEG, vars{:});

                case 'Remove Bad Epoch'
                    vars = convertContainedStringsToChars(varin);
                    vars = stripEmptyVarin(vars);
                    [EEG, rejepochs] = pop_autorej(EEG, vars{:});
                    EEG.rejEpochs = rejepochs;
                    EEG = eeg_checkset( EEG );

                case 'Run ICA'
                    EEG.data = double(EEG.data);
                    vars = convertContainedStringsToChars(varin);
                    EEG = pop_runica(EEG,vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Label ICA Components'
                    vars = convertContainedStringsToChars(varin);
                    iclabelVersion = vars{2};
                    EEG = pop_iclabel(EEG, iclabelVersion);
                    EEG = eeg_checkset( EEG );

                case 'Flag ICA Components for Rejection'
                    vars = convertContainedStringsToChars(varin);
                    threshold = zeros(7,2);
                    for nflag = 2:2:14
                        threshold(nflag/2,:) = vars{nflag};
                    end
                    EEG = pop_icflag(EEG, threshold);
                    EEG = eeg_checkset( EEG );

                case 'Remove Flagged ICA Components'
                    var_comp = step.params.components;   % [] = use flagged only
                    plotag   = step.params.plotag;
                    keepcomp = step.params.keepcomp;

                    Rej = EEG.reject.gcompreject;
                    Rej = reshape(Rej, 1, numel(Rej));
                    ICA_Rejected_Comp{end+1} = Rej; %#ok<AGROW>

                    gcr = EEG.reject.gcompreject;
                    if isnumeric(gcr) || islogical(gcr)
                        rejMask = logical(reshape(gcr, 1, []));
                    else
                        rejMask = false(1, max(size(EEG.icaweights, 1), 0));
                    end
                    pendingICAStats = struct('rejMask', rejMask);
                    if ~isempty(EEG.icaweights) && size(EEG.icaweights,1) == numel(rejMask)
                        act2D = computeICAActivation(EEG);
                        data2D = reshape(EEG.data(EEG.icachansind,:,:), numel(EEG.icachansind), []);
                        totalVar = sum(var(data2D, 0, 2));
                        if totalVar > 0
                            pendingICAStats.compVarPct = double((var(act2D, 0, 2) / totalVar * 100)');
                        end
                    end
                    if isfield(EEG,'etc') && isfield(EEG.etc,'ic_classification') && ...
                            isfield(EEG.etc.ic_classification,'ICLabel') && ...
                            isfield(EEG.etc.ic_classification.ICLabel,'classifications')
                        pendingICAStats.iclabelProbs = ...
                            EEG.etc.ic_classification.ICLabel.classifications;
                    end

                    if ~(isnumeric(EEG.reject.gcompreject) || islogical(EEG.reject.gcompreject))
                        EEG.reject.gcompreject = zeros(1, size(EEG.icaweights, 1));
                    end
                    EEG = pop_subcomp( EEG, var_comp, plotag, keepcomp);
                    EEG.ICA_Rejected_Comp = ICA_Rejected_Comp;
                    EEG = eeg_checkset( EEG );

                case 'Interpolate Channels'
                    method = step.params.method;
                    trange = step.params.trange;   % [] or [tstart tend]; typed param, no sentinel needed
                    EEG = pop_interp(EEG, EEG.chaninfo.removedchans(1:size(EEG.chaninfo.removedchans,2)), method, trange);
                    interpElecs = [interpElecs; num2cell(EEG.chaninfo.removedchans)]; %#ok<AGROW>
                    EEG.interpElecs = interpElecs;
                    EEG.setname = [EEG.setname '_interp'];
                    EEG.filename = [EEG.setname '.set'];
                    EEG.datfile  = [EEG.setname '.fdt'];
                    EEG = eeg_checkset( EEG );

                case 'Find TMS Pulses (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    ind = find(strcmp(vars,'elec'));
                    elec = vars{ind+1};
                    vars([ind,ind+1]) = [];
                    if iscell(elec)
                        elec = elec{:};
                    end
                    EEG = pop_tesa_findpulse( EEG, elec, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Fix TMS Pulse (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmp(vars,'elec'));
                    elec = vars{1,ind1+1};
                    ind2 = find(strcmp(vars,'epoch_len'));
                    epoch_len = vars{1,ind2+1};
                    ind3 = find(strcmp(vars,'type'));
                    type = vars{1,ind3+1};
                    vars([ind1,ind1+1,ind2,ind2+1,ind3,ind3+1]) = [];
                    EEG = tesa_fixevent( EEG, elec, epoch_len, type, vars{:} );
                    EEG = eeg_checkset( EEG );

                case 'Remove TMS Artifacts (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    cutTimesTMS = vars{1,find(strcmp(vars,'cutTimesTMS'))+1};
                    replaceTimes = vars{1,find(strcmp(vars,'replaceTimes'))+1};
                    cutEvent = vars{1,find(strcmp(vars,'cutEvent'))+1};
                    if ~iscell(cutEvent)
                        cutEvent = {cutEvent};
                    end
                    if strcmp(replaceTimes,'[]')
                        replaceTimes = eval(replaceTimes);
                    end
                    if size(cutTimesTMS,1)>size(cutTimesTMS,2)
                        cutTimesTMS = cutTimesTMS';
                    end
                    EEG = pop_tesa_removedata(EEG, cutTimesTMS, replaceTimes, cutEvent);
                    EEG = eeg_checkset( EEG );

                case 'Epoching'
                    vars = convertContainedStringsToChars(varin);
                    vars = stripEmptyVarin(vars);
                    ind1 = find(strcmp(vars,'types'));
                    type = vars{ind1+1};
                    ind2 = find(strcmp(vars,'timelim'));
                    timelim = vars{ind2+1};
                    vars([ind1, ind1+1, ind2, ind2+1]) = [];
                    EEG = pop_epoch( EEG, type, timelim, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Interpolate Missing Data (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    interpolation = vars{1,find(strcmp(vars,'interpolation'))+1};
                    interpWin = vars{1,find(strcmp(vars,'interpWin'))+1};
                    if size(interpWin,1) > size(interpWin,2)
                        interpWin = interpWin';
                    end
                    EEG = pop_tesa_interpdata( EEG, interpolation, interpWin);

                case 'Run TESA ICA'
                    vars = convertContainedStringsToChars(varin);
                    EEG = pop_tesa_fastica( EEG, vars{:} );
                    EEG = eeg_checkset( EEG );

                case 'Remove ICA Components (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    compsIdx = find(strcmpi(vars, 'comps'), 1);
                    if ~isempty(compsIdx)
                        vars([compsIdx, compsIdx+1]) = [];
                    end
                    ind1 = find(strcmpi(vars,'plotTimeX'));
                    TP = vars{ind1+1};
                    if TP(1) ~= EEG.times(1) && TP(2) ~= EEG.times(end)
                        vars{ind1+1} = [EEG.times(1) EEG.times(end)];
                    end
                    for nInd=2:2:numel(vars)
                        if size(vars{nInd},1)>size(vars{nInd},2)
                            vars{nInd} = vars{nInd}';
                        end
                    end
                    EEG = pop_tesa_compselect( EEG,vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Find Artifacts EDM (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmpi(vars,'chanl'));
                    chanlocations = vars{ind1+1};
                    vars([ind1, ind1+1]) = [];
                    ind2 = find(strcmpi(vars,'nc'));
                    nc = vars{ind2+1};
                    vars([ind2, ind2+1]) = [];
                    ind3 = find(strcmpi(vars,'sf'));
                    sf = vars{ind3+1};
                    vars([ind3, ind3+1]) = [];
                    if sf ~= EEG.srate
                        sf = EEG.srate;
                    end
                    EEG = pop_tesa_edm( EEG, chanlocations, nc, sf, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'SSP SIR'
                    vars = convertContainedStringsToChars(varin);
                    EEG = pop_tesa_sspsir(EEG, vars{:});
                    EEG = eeg_checkset( EEG );

                case 'Remove Recording Noise (SOUND)'
                    vars = convertContainedStringsToChars(varin);
                    EEG = pop_tesa_sound(EEG, vars{:} );
                    EEG = eeg_checkset( EEG );

                case 'Median Filter 1D'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmp(vars,'timeWin'));
                    timeWin = vars{1,ind1+1};
                    ind2 = find(strcmp(vars,'mdorder'));
                    mdorder = vars{1,ind2+1};
                    ind3 = find(strcmp(vars,'event_type'));
                    event_type = vars{1,ind3+1};
                    EEG = tesa_filtmedian( EEG, timeWin, mdorder, event_type );
                    EEG = eeg_checkset( EEG );

                case 'Remove Bad Trials'
                    localThresh  = step.params.localThresh;
                    globalThresh = step.params.globalThresh;
                    EEG = pop_jointprob(EEG, 1, 1:size(EEG.data,1), localThresh, globalThresh, 0, 0);
                    pop_rejmenu(EEG, 1);
                    uiconfirm(opts.uiFigure,'Highlight bad trials in the rejection menu, then press OK to continue.','Remove Bad Trials','Options',{'OK'},'DefaultOption',1);
                    EEG.BadTr = unique([find(EEG.reject.rejjp==1) find(EEG.reject.rejmanual==1)]);
                    EEG = pop_rejepoch( EEG, EEG.BadTr ,0);
                    EEG = eeg_checkset( EEG );

                case 'Extract TEP (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmp(vars,'type'));
                    type = vars{1,ind1+1};
                    vars([ind1, ind1+1]) = [];
                    ind2 = find(strcmpi(vars,'pairCorrect'));
                    if ~strcmp(vars{ind2+1},'on')
                        ind3 = find(strcmpi(vars,'ISI'));
                        vars([ind3, ind3+1]) = [];
                    end
                    vars = stripEmptyVarin(vars);
                    EEG = pop_tesa_tepextract( EEG, type, vars );

                case 'Find TEP Peaks (TESA)'
                    vars = convertContainedStringsToChars(varin);
                    ind1 = find(strcmpi(vars,'input'));
                    input = vars{ind1+1};
                    vars([ind1, ind1+1]) = [];
                    ind2 = find(strcmpi(vars,'direction'));
                    direction = vars{ind2+1};
                    vars([ind2, ind2+1]) = [];
                    ind3 = find(strcmpi(vars,'peak'));
                    peak = vars{ind3+1};
                    vars([ind3, ind3+1]) = [];
                    ind4 = find(strcmpi(vars,'peakWin'));
                    peakWin = vars{ind4+1};
                    vars([ind4, ind4+1]) = [];
                    vars = stripEmptyVarin(vars);
                    EEG = pop_tesa_peakanalysis( EEG, input, direction, peak, peakWin, vars(:) );

                case 'TEP Peak Output'
                    vars = convertContainedStringsToChars(varin);
                    vars = stripEmptyVarin(vars);
                    pop_tesa_peakoutput( EEG, vars{:} );

            end % switch

            %% Post-step metrics and report update
            if isstruct(EEG) && ~isempty(EEG)
                nChanAfter  = EEG.nbchan;
                nEpochAfter = size(EEG.data, 3);
                if strcmp(stepName, 'Load Data')
                    fileReport.channels.original = EEG.nbchan;
                end
                fileReport.channels.final = EEG.nbchan;
                if nChanAfter < nChanBefore
                    if any(strcmp(stepName, {'Remove Bad Channels','Remove un-needed Channels', ...
                            'Automatic Cleaning Data','Clean Artifacts', ...
                            'Automatic Continuous Rejection'}))
                        fileReport.channels.nRejected = fileReport.channels.nRejected + ...
                            (nChanBefore - nChanAfter);
                    end
                end
                if any(strcmp(stepName, {'Interpolate Channels','Interpolate Missing Data (TESA)'})) ...
                        && nChanAfter > nChanBefore
                    fileReport.channels.nInterpolated = fileReport.channels.nInterpolated + ...
                        (nChanAfter - nChanBefore);
                end
                if strcmp(stepName, 'Epoching') && fileReport.trials.original == 0
                    fileReport.trials.original = size(EEG.data, 3);
                end
                if size(EEG.data, 3) > 1
                    fileReport.trials.final = nEpochAfter;
                    if nEpochBefore > 1 && nEpochAfter < nEpochBefore
                        fileReport.trials.rejected = fileReport.trials.rejected + ...
                            (nEpochBefore - nEpochAfter);
                    end
                end
                if any(strcmp(stepName, {'Run ICA','Run TESA ICA'})) && ~isempty(EEG.icaweights)
                    fileReport.ica.nComponents = size(EEG.icaweights, 1);
                end
                if strcmp(stepName, 'Remove Flagged ICA Components') && ...
                        isfield(pendingICAStats, 'rejMask')
                    rMask = pendingICAStats.rejMask;
                    nRej  = sum(rMask);
                    fileReport.ica.nRejected = fileReport.ica.nRejected + nRej;
                    fileReport.ica.nKept     = fileReport.ica.nComponents - fileReport.ica.nRejected;
                    if isfield(pendingICAStats, 'compVarPct') && ...
                            numel(pendingICAStats.compVarPct) == numel(rMask)
                        rejPct = pendingICAStats.compVarPct(rMask);
                        if isnan(fileReport.ica.varRemoved)
                            fileReport.ica.varRemoved = sum(rejPct);
                        else
                            fileReport.ica.varRemoved = fileReport.ica.varRemoved + sum(rejPct);
                        end
                        fileReport.ica.varMin = min([fileReport.ica.varMin, rejPct]);
                        fileReport.ica.varMax = max([fileReport.ica.varMax, rejPct]);
                    end
                    if isfield(pendingICAStats, 'iclabelProbs')
                        probs = pendingICAStats.iclabelProbs;
                        [~, bestCat] = max(probs, [], 2);
                        for ci = 1:7
                            inCat = (bestCat == ci) & rMask(:);
                            fileReport.ica.categories.nRemoved(ci) = ...
                                fileReport.ica.categories.nRemoved(ci) + sum(inCat);
                            if isfield(pendingICAStats, 'compVarPct')
                                fileReport.ica.categories.varShare(ci) = ...
                                    fileReport.ica.categories.varShare(ci) + ...
                                    sum(pendingICAStats.compVarPct(inCat));
                            end
                        end
                    end
                    pendingICAStats = struct();
                end
                if strcmp(stepName, 'Remove ICA Components (TESA)') && ...
                        isfield(EEG, 'icaCompClass') && isstruct(EEG.icaCompClass) && ...
                        ~isempty(fieldnames(EEG.icaCompClass))
                    tesaKeys = fieldnames(EEG.icaCompClass);
                    cl = EEG.icaCompClass.(tesaKeys{end});
                    TESA_CATS  = {'TMS Muscle','Blink','Eye Move','Muscle','Elec Noise','Sensory','Reject'};
                    TESA_CODES = [3, 4, 5, 6, 7, 8, 2];
                    rejIdx   = cl.compClass > 1;
                    nRejTESA = sum(rejIdx);
                    rnd.roundNum    = numel(tesaKeys);
                    rnd.nComponents = numel(cl.compClass);
                    rnd.nRejected   = nRejTESA;
                    rnd.varRemoved  = NaN;
                    rnd.varMin      = NaN;
                    rnd.varMax      = NaN;
                    rnd.categories.names    = TESA_CATS;
                    rnd.categories.nRemoved = zeros(1, numel(TESA_CATS));
                    rnd.categories.varShare = zeros(1, numel(TESA_CATS));
                    hasVars = isfield(cl, 'compVars') && numel(cl.compVars) >= numel(cl.compClass);
                    if hasVars && nRejTESA > 0
                        rejPct         = double(cl.compVars(rejIdx));
                        rnd.varRemoved = sum(rejPct);
                        rnd.varMin     = min(rejPct);
                        rnd.varMax     = max(rejPct);
                    end
                    for ci = 1:numel(TESA_CODES)
                        inCat = (cl.compClass == TESA_CODES(ci));
                        rnd.categories.nRemoved(ci) = sum(inCat);
                        if hasVars
                            rnd.categories.varShare(ci) = sum(cl.compVars(inCat));
                        end
                    end
                    fileReport.ica.rounds{end+1} = rnd;
                    fileReport.ica.nRejected = fileReport.ica.nRejected + nRejTESA;
                    fileReport.ica.nKept     = fileReport.ica.nComponents - fileReport.ica.nRejected;
                    if ~strcmp(fileReport.ica.categories.names{1}, 'TMS Muscle')
                        fileReport.ica.categories.names    = TESA_CATS;
                        fileReport.ica.categories.nRemoved = zeros(1, numel(TESA_CATS));
                        fileReport.ica.categories.varShare = zeros(1, numel(TESA_CATS));
                    end
                    fileReport.ica.categories.nRemoved = ...
                        fileReport.ica.categories.nRemoved + rnd.categories.nRemoved;
                    if isscalar(fileReport.ica.rounds)
                        fileReport.ica.varRemoved = rnd.varRemoved;
                        fileReport.ica.varMin     = rnd.varMin;
                        fileReport.ica.varMax     = rnd.varMax;
                        fileReport.ica.categories.varShare = rnd.categories.varShare;
                    end
                end
            else
                nChanAfter  = nChanBefore;
                nEpochAfter = nEpochBefore;
            end % if isstruct(EEG)

            stepRec.name         = stepName;
            stepRec.chansBefore  = nChanBefore;
            stepRec.chansAfter   = nChanAfter;
            stepRec.trialsBefore = nEpochBefore;
            stepRec.trialsAfter  = nEpochAfter;
            elapsed              = toc(t0);
            stepRec.duration     = elapsed;
            stepRec.timestamp    = datetime('now');
            fileReport.steps{end+1} = stepRec;

            stepLog(end+1) = struct( ...
                'step',        stepName, ...
                'duration_s',  elapsed, ...
                'chanBefore',  nChanBefore, ...
                'chanAfter',   nChanAfter, ...
                'epochBefore', nEpochBefore, ...
                'epochAfter',  nEpochAfter, ...
                'error',       ''); %#ok<AGROW>

        catch err
            stepLog(end+1) = struct( ...
                'step',        stepName, ...
                'duration_s',  toc(t0), ...
                'chanBefore',  nChanBefore, ...
                'chanAfter',   nChanBefore, ...
                'epochBefore', nEpochBefore, ...
                'epochAfter',  nEpochBefore, ...
                'error',       err.message); %#ok<AGROW>

            disp(err.message)
            warning('An error occurred at file %s at step %d: %s', ...
                fileName, si, stepName);
            toContinue = uiconfirm(opts.uiFigure, ...
                sprintf('Error at step %d (%s):\n%s\n\nContinue to next step?', ...
                    si, stepName, err.message), ...
                'Step Failed','Options',{'Continue','Abort'}, ...
                'DefaultOption','Continue','CancelOption','Abort');
            if strcmp(toContinue,'Abort')
                writeSessionLog(pathName, fileName, stepLog);
                if isvalid(dlg); close(dlg); end
                return
            end
        end
    end % step loop

    % Write pipeline provenance to EEG.history.
    if isstruct(EEG) && isfield(EEG, 'history')
        EEG.history = [EEG.history, newline, ...
            buildHistoryEntry(spec, opts.pipelineName)];
        assignin('base', 'EEG', EEG);
        newHist  = EEG.history(histLenBefore + 1 : end);
        newLines = strtrim(strsplit(newHist, newline));
        newLines = newLines(~cellfun('isempty', newLines));
        if ~iscell(ALLCOM); ALLCOM = {}; end
        ALLCOM = [newLines(:)', ALLCOM];
    end

    writeSessionLog(pathName, fileName, stepLog);
    [summaryText, ~] = exportReport(fileReport, pathName);
    allSummaries{end+1} = summaryText; %#ok<AGROW>
    allReports{end+1}   = fileReport;  %#ok<AGROW>

    if ~getpref('nestapp', 'hideEEGLABWindow', true)
        eeglab redraw
    end
    disp('-----------------Data processed!-----------------')
end % file loop

if isvalid(dlg); close(dlg); end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Local helpers

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

function entry = buildHistoryEntry(spec, pipelineName)
% Build a human-readable provenance string for EEG.history.
timestamp = string(datetime('now'), 'yyyy-MM-dd HH:mm:ss');
if isempty(pipelineName)
    pipelineName = '(unsaved)';
end
lines = { ...
    sprintf('%% --- nestapp pipeline  [%s] ---', timestamp), ...
    sprintf('%% Pipeline: %s', pipelineName), ...
    '%  Steps:' ...
};
for si = 1:numel(spec)
    keys   = fieldnames(spec(si).params);
    pairs  = cell(1, numel(keys));
    for ki = 1:numel(keys)
        val = spec(si).params.(keys{ki});
        if isnumeric(val)
            valStr = mat2str(val);
        else
            valStr = char(val);
        end
        pairs{ki} = sprintf('%s=%s', keys{ki}, valStr);
    end
    if isempty(pairs)
        paramStr = '';
    else
        paramStr = ['  [', strjoin(pairs, ', '), ']'];
    end
    lines{end+1} = sprintf('%%  %2d. %s%s', si, spec(si).name, paramStr); %#ok<AGROW>
end
entry = strjoin(lines, newline);
end

function writeSessionLog(pathName, fileName, stepLog)
% Write a plain-text processing log alongside the data file.
[~, baseName] = fileparts(fileName);
logPath = fullfile(pathName, [baseName, '_nestapp_log.txt']);
fid = fopen(logPath, 'w');
if fid == -1; return; end
fprintf(fid, '=== nestapp session log ===\n');
fprintf(fid, 'File:      %s\n', fileName);
fprintf(fid, 'Processed: %s\n', datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
fprintf(fid, 'MATLAB:    %s\n', version);
fprintf(fid, '\n%-4s  %-35s  %7s  %9s  %9s  %s\n', ...
    '#', 'Step', 'Time(s)', 'Ch before', 'Ch after', 'Note');
fprintf(fid, '%s\n', repmat('-', 1, 80));
for k = 1:numel(stepLog)
    s = stepLog(k);
    note = s.error;
    if s.epochBefore ~= s.epochAfter && isempty(s.error)
        note = sprintf('epochs %d \x2192 %d', s.epochBefore, s.epochAfter);
    end
    fprintf(fid, '%-4d  %-35s  %7.2f  %9d  %9d  %s\n', ...
        k, s.step, s.duration_s, s.chanBefore, s.chanAfter, note);
end
fprintf(fid, '\nTotal steps: %d\n', numel(stepLog));
errSteps = sum(~cellfun(@isempty, {stepLog.error}));
if errSteps > 0
    fprintf(fid, 'Steps with errors: %d\n', errSteps);
end
fclose(fid);
end

function vars = stripEmptyVarin(vars)
% Remove key-value pairs where value is the old '[]' sentinel string,
% numeric [], or cell {} — all representations of "not set" for optional
% EEGLAB params. Handles the mismatch between the old string-sentinel format
% and the new typed-model format (which stores actual empty MATLAB values).
isEmptyVal = cellfun(@(v) (ischar(v) && strcmp(v,'[]')) || ...
                          (isnumeric(v) && isempty(v)) || ...
                          (isnumeric(v) && isscalar(v) && isnan(v)) || ...
                          (iscell(v) && isempty(v)) || ...
                          (iscell(v) && numel(v)==1 && ischar(v{1}) && strcmp(v{1},'[]')), ...
                          vars(2:2:end));
toRemove  = find(isEmptyVal);
removeIdx = sort([2*toRemove-1, 2*toRemove]);
vars(removeIdx) = [];
end

function act2D = computeICAActivation(EEG)
% Return 2-D ICA activations (nComp x nSamples).
if ~isempty(EEG.icaact)
    act2D = reshape(EEG.icaact, size(EEG.icaact,1), []);
else
    data2D = reshape(EEG.data(EEG.icachansind,:,:), numel(EEG.icachansind), []);
    act2D  = (EEG.icaweights * EEG.icasphere) * data2D;
end
end
