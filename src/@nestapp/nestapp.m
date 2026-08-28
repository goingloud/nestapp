% WARNING: Do not open nestapp_designer.mlapp and save - App Designer will
% regenerate this file and overwrite startupFcn and other hand-edited methods.
% All edits must be made directly to nestapp.m.

% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef nestapp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        TabGroup                        matlab.ui.container.TabGroup
        CleaningTab                     matlab.ui.container.Tab
        ReStartStepsButton              matlab.ui.control.Button
        NESTAPPLabel                    matlab.ui.control.Label
        Image                           matlab.ui.control.Image
        RunAnalysisButton               matlab.ui.control.Button
        SelectDatatoPerformAnalysisPanel  matlab.ui.container.Panel
        SelectDataButton                matlab.ui.control.Button
        SelectedFilesListBox            matlab.ui.control.ListBox
        SelectedListBoxLabel_2          matlab.ui.control.Label
        TextArea                        matlab.ui.control.TextArea
        DefaultValueButton              matlab.ui.control.Button
        UITable                         matlab.ui.control.Table
        SelectedListBoxLabel            matlab.ui.control.Label
        RemoveButton                    matlab.ui.control.Button
        AddButton                       matlab.ui.control.Button
        MoveDownButton                  matlab.ui.control.Button
        MoveUpButton                    matlab.ui.control.Button
        SelectedListBox                 matlab.ui.control.ListBox
        StepsListBoxLabel               matlab.ui.control.Label
        InfoTextArea                    matlab.ui.control.TextArea
        CommandDescriptionLabel         matlab.ui.control.Label
        StepsTree                       matlab.ui.container.Tree
        StepsTipPanel                   matlab.ui.container.Panel
        StepsTipLabel                   matlab.ui.control.Label
        VisualizingTab                  matlab.ui.container.Tab
        TEPvarNameEditField             matlab.ui.control.EditField
        TEPvarNameEditFieldLabel        matlab.ui.control.Label
        ExportTEPDataButton             matlab.ui.control.Button
        PlotEEGdataButton               matlab.ui.control.Button
        EEGDatasetDropDown              matlab.ui.control.DropDown
        EEGDatasetDropDownLabel         matlab.ui.control.Label
        TopoplottimeSpinner             matlab.ui.control.Spinner
        TopoplottimeSpinnerLabel        matlab.ui.control.Label
        TEPWindowSlider                 matlab.ui.control.RangeSlider
        TEPWindowSliderLabel            matlab.ui.control.Label
        ReLoadAvailableElectrodesButton  matlab.ui.control.Button
        PO6Button                       matlab.ui.control.StateButton
        PO1Button                       matlab.ui.control.StateButton
        DontfindcommonelectrodesCheckBox  matlab.ui.control.CheckBox
        SelectAllCheckBox               matlab.ui.control.CheckBox
        AF8Button                       matlab.ui.control.StateButton
        AF7Button                       matlab.ui.control.StateButton
        AFZButton                       matlab.ui.control.StateButton
        TP9Button                       matlab.ui.control.StateButton
        TP10Button                      matlab.ui.control.StateButton
        CB2Button                       matlab.ui.control.StateButton
        O2Button                        matlab.ui.control.StateButton
        OZButton                        matlab.ui.control.StateButton
        CB1Button                       matlab.ui.control.StateButton
        PO8Button                       matlab.ui.control.StateButton
        PO2Button                       matlab.ui.control.StateButton
        PO5Button                       matlab.ui.control.StateButton
        PO7Button                       matlab.ui.control.StateButton
        PO4Button                       matlab.ui.control.StateButton
        POZButton                       matlab.ui.control.StateButton
        PO3Button                       matlab.ui.control.StateButton
        O1Button                        matlab.ui.control.StateButton
        P6Button                        matlab.ui.control.StateButton
        P4Button                        matlab.ui.control.StateButton
        PZButton                        matlab.ui.control.StateButton
        P5Button                        matlab.ui.control.StateButton
        P7Button                        matlab.ui.control.StateButton
        P2Button                        matlab.ui.control.StateButton
        P1Button                        matlab.ui.control.StateButton
        P3Button                        matlab.ui.control.StateButton
        P8Button                        matlab.ui.control.StateButton
        TP8Button                       matlab.ui.control.StateButton
        CP6Button                       matlab.ui.control.StateButton
        CP4Button                       matlab.ui.control.StateButton
        CPZButton                       matlab.ui.control.StateButton
        CP5Button                       matlab.ui.control.StateButton
        TP7Button                       matlab.ui.control.StateButton
        T7Button                        matlab.ui.control.StateButton
        C3Button                        matlab.ui.control.StateButton
        C5Button                        matlab.ui.control.StateButton
        FC5Button                       matlab.ui.control.StateButton
        FT7Button                       matlab.ui.control.StateButton
        T8Button                        matlab.ui.control.StateButton
        CP2Button                       matlab.ui.control.StateButton
        CP1Button                       matlab.ui.control.StateButton
        CP3Button                       matlab.ui.control.StateButton
        C2Button                        matlab.ui.control.StateButton
        CZButton                        matlab.ui.control.StateButton
        C1Button                        matlab.ui.control.StateButton
        FC3Button                       matlab.ui.control.StateButton
        FCZButton                       matlab.ui.control.StateButton
        FC1Button                       matlab.ui.control.StateButton
        F7Button                        matlab.ui.control.StateButton
        FT8Button                       matlab.ui.control.StateButton
        C6Button                        matlab.ui.control.StateButton
        C4Button                        matlab.ui.control.StateButton
        F1Button                        matlab.ui.control.StateButton
        FC6Button                       matlab.ui.control.StateButton
        FC4Button                       matlab.ui.control.StateButton
        FC2Button                       matlab.ui.control.StateButton
        FZButton                        matlab.ui.control.StateButton
        F3Button                        matlab.ui.control.StateButton
        F5Button                        matlab.ui.control.StateButton
        F2Button                        matlab.ui.control.StateButton
        F4Button                        matlab.ui.control.StateButton
        F6Button                        matlab.ui.control.StateButton
        F8Button                        matlab.ui.control.StateButton
        AF4Button                       matlab.ui.control.StateButton
        FP2Button                       matlab.ui.control.StateButton
        FPZButton                       matlab.ui.control.StateButton
        FP1Button                       matlab.ui.control.StateButton
        AF3Button                       matlab.ui.control.StateButton
        PlottingModeButtonGroup         matlab.ui.container.ButtonGroup
        AddtocurrentFigureButton        matlab.ui.control.RadioButton
        NewFigureButton                 matlab.ui.control.RadioButton
        PlotTypeButtonGroup             matlab.ui.container.ButtonGroup
        PlotTypeTEPButton               matlab.ui.control.RadioButton
        PlotTypeGMFPButton              matlab.ui.control.RadioButton
        PlotTypeLMFPButton              matlab.ui.control.RadioButton
        ExportTEPFigureButton           matlab.ui.control.Button
        OpenTEPFigureButton             matlab.ui.control.Button
        OpenTopoFigureButton            matlab.ui.control.Button
        TOPOPLOTButton                  matlab.ui.control.Button
        WindowsizefortimeaveragedTopoplotEditField  matlab.ui.control.NumericEditField
        WindowsizeforTopoplotLabel      matlab.ui.control.Label
        Image2                          matlab.ui.control.Image
        FilesListBox                    matlab.ui.control.ListBox
        FilesListBoxLabel               matlab.ui.control.Label
        UseCurrentlyCleanedDataCheckBox  matlab.ui.control.CheckBox
        SelectDatatoVisulaizeTEPsPanel  matlab.ui.container.Panel
        SelectDataButton_2              matlab.ui.control.Button
        FolderEditField_2               matlab.ui.control.EditField
        FolderEditField_2Label          matlab.ui.control.Label
        PLOTTEPButton                   matlab.ui.control.Button
        ShowComponentsButton            matlab.ui.control.StateButton
        AddWindowButton                 matlab.ui.control.Button
        RemoveWindowButton              matlab.ui.control.Button
        ResetWindowsButton              matlab.ui.control.Button
        TEPComponentTable               matlab.ui.control.Table
        UIAxes2                         matlab.ui.control.UIAxes
        UIAxes                          matlab.ui.control.UIAxes
        ReportsTab                      matlab.ui.container.Tab
        ReportsListBox                  matlab.ui.control.ListBox
        ReportsListBoxLabel             matlab.ui.control.Label
        LoadReportsButton               matlab.ui.control.Button
        ClearReportsButton              matlab.ui.control.Button
        ReportsFolderLabel              matlab.ui.control.Label
        ReportsStatusLabel              matlab.ui.control.Label
        ReportsTextArea                 matlab.ui.control.TextArea
        ReportsDashboardPanel           matlab.ui.container.Panel
        ExportReportsCSVButton          matlab.ui.control.Button
        ExportPDFButton                 matlab.ui.control.Button
        CopyMethodsButton               matlab.ui.control.Button
        % Analysis tab - static elements not auto-resized by MATLAB
        AnalysisSelPanel                matlab.ui.container.Panel
        AnalysisCompWindowsLabel        matlab.ui.control.Label
        AnalysisWorkspaceLabel          matlab.ui.control.Label
        AnalysisBatchLabel              matlab.ui.control.Label
        AnalysisBatchDescLabel          matlab.ui.control.Label
    end

    properties (Access = private)
        ItemNum % Index for selected Item
        elecList = {'FPz','FP1','FP2','AF7','AF3','AFz','AF4','AF8','F7','F5','F3',...
                'F1','F2','F4','F6','F8','Fz','FT7','FT8','FC5','FC3',...
                'FC1','FCz','FC2','FC4','FC6','T7','T8','C5','C3','C1','Cz',...
                'C2','C4','C6','TP7','TP8','CP5','CP3','CP1','CPz',...
                'CP2','CP4','CP6','P7','P5','P3','P1','Pz',...
                'P2','P4','P6','P8','PO7','PO5','PO3','PO1','POz','PO2','PO4','PO6','PO8',...
                'CB1','O1','Oz','O2','CB2','TP9','TP10'}; % All Listed Electrodes
        path         % File Path (single-folder selection; '' when files span folders)
        file         % File Name(s) shown in the listbox (basenames, or folder/name when multi-folder)
        filePaths    % Full path of every queued data file - source of truth for Run Analysis
        spec         % PipelineStep struct array (name + typed params)
        NSelecFiles  % Number of selected files for EEG preprocessing
        cleanedName  % Name used to rename the saved cleaned EEG data
    end
    properties (Access = public)
        % Tab Cleaning
        selectedItem % Selected Table Item Values
        info % containers.Map: step name -> info/description text (shown in InfoTextArea)
        hoverTimer    % singleShot timer: fires once the pointer has rested on the Steps tree
        treeRect      % cached figure-relative rect of StepsTree (getpixelposition is slow)
        treeRectStamp % UIFigure.Position the cached rect was computed for
        stepBlocks    % containers.Map: step name -> true if it ALWAYS waits for a human
        stepProviders % containers.Map: step name -> provider (TESA, EEGLAB, ...)
        % Canonical pipeline state - single source of truth for steps and params.
        % appendStep/removeStep/moveStep/clearSteps/loadPipelineData all write here.
        currentParamKey  = ''  % param key selected in UITable (transient)
        currentParamType = ''  % type of selected param (transient)
        originalSize     % [w h] of UIFigure at creation - used by UIFigureSizeChanged
        isResizing = false % guards UIFigureSizeChanged against its own clamp write
        baseLayout = []  % per-component base geometry captured at startup - drives rescaleComponents
        clickedItem = [];
        doubleClicked = 0;

        % Tab Explore - the grouped-comparison workspace
        ExploreTab                      matlab.ui.container.Tab
        ExploreGroupsLabel              matlab.ui.control.Label
        ExploreGroupsListBox            matlab.ui.control.ListBox
        ExploreAddGroupButton           matlab.ui.control.Button
        ExploreRemoveGroupButton        matlab.ui.control.Button
        ExploreRoiLabel                 matlab.ui.control.Label
        ExploreRoiDropDown              matlab.ui.control.DropDown
        ExploreRoiEditButton            matlab.ui.control.Button
        ExploreRoiSummaryLabel          matlab.ui.control.Label
        ExploreWindowsLabel             matlab.ui.control.Label
        ExploreWindowsTable             matlab.ui.control.Table
        ExploreWindowsResetButton       matlab.ui.control.Button
        ExplorePlotLabel                matlab.ui.control.Label
        ExplorePlotDropDown             matlab.ui.control.DropDown
        ExplorePlotInfoLabel            matlab.ui.control.Label
        ExploreCanvas                   matlab.ui.container.Panel
        ExploreEmptyLabel               matlab.ui.control.Label
        ExploreFigureButton             matlab.ui.control.Button
        ExploreCsvButton                matlab.ui.control.Button
        ExploreResultsButton            matlab.ui.control.Button
        ExploreStatusLabel              matlab.ui.control.Label

        % Tab Visualizing
        PathofSelectedFilesforTEP
        SelectedFilesforTEP % Selected files to plot the TEP
        Common_Labels % Commong electrod name among files
        ROIelecsLabels % Selected electrodes as Region of Interest
        TEPCreated = false; % true once the TEP plot has been rendered at least once
        EEG_SelectedTEPFiles_Loaded = false;
        EEGofAllSelectedFiles = [];
        DefaulTEPxLim = [-50 300]; % Default xLim for time in TEP
        SMOOTH_WIN_PTS = 5;        % moving-average window for the displayed/exported curve (~5 ms at 1 kHz)
        EEGtime
        TEP2Export
        TEPDisplayCurve = [] % smoothed grand-mean curve currently shown on UIAxes (TEP/GMFP/LMFP) - measured by the Analysis-tab windows of interest
        MenuRecentFiles     % Handle to 'Recent Files' submenu - rebuilt on open
        MenuRecentPipelines % Handle to 'Recent Pipelines' submenu - rebuilt on open
        StatusBar           % uilabel pinned to bottom of UIFigure - visible on both tabs
        pipelineDirty   = false    % true when pipeline has unsaved changes
        pipelineName    = ''       % filename of last saved/loaded pipeline
        tepPeaks        = struct([]) % struct array from tepPeakFinder; cached after each PLOT TEP
        tepComponentDefs = struct([]) % component window definitions used by tepPeakFinder
        allPipelineReports = {}    % cell array of report entry structs from current session
        loadedReports      = {}    % cell array of report entry structs loaded from disk
        lastFailed         = struct([]) % failure records from the most recent run (for the dashboard + summary)
        preSelectedChanFile = ''   % channel location file selected once before a run
        ParallelCheckBox           % uicheckbox - enable parallel participant processing

        % Explore state. entries and cache are the dataset; everything else is
        % derived on demand by groupCurves, which is cheap enough to re-run on
        % every change (measured ~30 ms for 35 files), so nothing here caches a
        % result that could go stale against the controls.
        exploreEntries = struct('path', {}, 'subject', {}, 'group', {}, ...
                                'subjectConfident', {})
        exploreCache   = struct('path', {}, 'trialAvg', {}, 'labels', {}, ...
                                'chanlocs', {}, 'time', {}, 'nTrials', {}, 'ok', {})
        exploreRoi     = {}      % ROI electrode labels (canonical spelling)
        exploreWindows = struct([])
        exploreRes     = struct([])   % last groupCurves result, for the exits
        exploreAvailablePlots = struct([])  % registry entries + availability

        % Tab Analysis
        AnalysisTab
        ExtractPeaksCSVButton
        AnalysisStatusLabel
        AnalysisSelectionLabel
    end

    methods (Access = private)
        % -- Pipeline state mutation methods ---------------------------------
        % app.spec, SelectedListBox.Items, and SelectedListBox.ItemsData must
        % stay in sync. These methods are the ONLY permitted way to add,
        % remove, move, or clear steps -- callbacks delegate here.

        function name = selectedStepName(app)
        % SELECTEDSTEPNAME  Registry step name of the selected tree node, or ''
        % when a category/operation header (empty NodeData) is selected.
            name = '';
            n = app.StepsTree.SelectedNodes;
            if isempty(n); return; end
            d = n(1).NodeData;
            if ischar(d) || isstring(d); name = char(d); end
        end

        function UIFigureMouseMoved(app, ~)
        % Any pointer movement hides the tip and restarts its clock, so it
        % only ever appears once the pointer has been still on the tree for
        % HOVER_DELAY seconds - and gets out of the way the instant you move.
        % Fires on every mouse move over the window, so it stays cheap: no
        % graphics write unless the tip is actually up.
            if isempty(app.hoverTimer) || ~isvalid(app.hoverTimer); return; end
            stop(app.hoverTimer);
            hideStepsTip(app);
            if ~pointerOverStepsTree(app); return; end
            start(app.hoverTimer);
        end

        function tf = pointerOverStepsTree(app)
        % True when the pointer is inside the Steps tree, which only exists
        % while the Cleaning tab is showing.
            tf = false;
            if app.TabGroup.SelectedTab ~= app.CleaningTab; return; end
            r = stepsTreeRect(app);
            p = app.UIFigure.CurrentPoint;
            tf = p(1) >= r(1) && p(1) <= r(1) + r(3) ...
              && p(2) >= r(2) && p(2) <= r(2) + r(4);
        end

        function r = stepsTreeRect(app)
        % Figure-relative rect of the tree. getpixelposition costs ~150 us, far
        % too much for a callback that fires on every mouse move, so cache it
        % and recompute only when the window has changed size or moved.
            pos = app.UIFigure.Position;
            if isempty(app.treeRect) || ~isequal(app.treeRectStamp, pos)
                app.treeRect      = getpixelposition(app.StepsTree, true);
                app.treeRectStamp = pos;
            end
            r = app.treeRect;
        end

        function showStepsTip(app)
        % Fired by the dwell timer. Places the tip near the pointer, nudged so
        % it never sits under the cursor and never leaves the window.
            if ~isvalid(app.UIFigure) || ~pointerOverStepsTree(app); return; end
            GAP = 14;
            tip = app.StepsTipPanel.Position(3:4);
            fig = app.UIFigure.Position(3:4);
            p   = app.UIFigure.CurrentPoint;
            x   = min(max(1, p(1) + GAP), fig(1) - tip(1) - 1);
            y   = min(max(1, p(2) - tip(2) - GAP), fig(2) - tip(2) - 1);
            app.StepsTipPanel.Position = [x, y, tip];
            app.StepsTipPanel.Visible = 'on';
        end

        function hideStepsTip(app)
        % Guarded on the current state: this runs on every mouse move, and
        % re-asserting 'off' on an already-hidden panel is a graphics write
        % for nothing.
            if ~isempty(app.StepsTipPanel) && isvalid(app.StepsTipPanel) ...
                    && app.StepsTipPanel.Visible
                app.StepsTipPanel.Visible = 'off';
            end
        end

        function txt = stepsTreeLegend(app)
        % The text of the tree's hover tip, and the one place the design is
        % explained.
        %
        % uitreenode has no Tooltip property, so a per-node hover tip is not
        % possible - this tree-level key carries the dot's meaning instead, and
        % the Info panel below names the provider and the exact wait behaviour
        % for whichever step is selected.
        %
        % It is shown by a dwell timer rather than the native Tooltip: the
        % native one fires on MATLAB's own schedule and cannot be delayed, and
        % assigning Tooltip mid-hover does not reliably re-trigger it.
            n = 0;
            if ~isempty(app.stepBlocks); n = app.stepBlocks.Count; end
            txt = sprintf([ ...
                'Amber dot: the step waits for you - it opens a window you ' ...
                'must close, and cannot run with Parallel Processing on ' ...
                '(%d steps).\n\nSelect a step for details.'], n);
        end

        function lines = stepInfoLines(app, name)
        % What the Info panel shows for one step: its description, then the
        % facts the tree can only hint at - who supplies it (every step has a
        % provider, so that is text rather than a dot) and, for the few that
        % carry the amber dot, what the dot means for this step.
            lines = string.empty(0, 1);
            % The dot's meaning goes first: the Info panel is small, and a
            % note under a long description is a note nobody scrolls to.
            if ~isempty(app.stepBlocks) && isKey(app.stepBlocks, name)
                if app.stepBlocks(name)
                    lines(end+1) = "* Waits for you - opens a window you must " + ...
                        "close before the run continues.";
                else
                    lines(end+1) = "* Waits for you in some modes - opens a " + ...
                        "window you must close when its review option is on.";
                end
                lines(end+1) = "  Cannot run with Parallel Processing on.";
                lines(end+1) = "";
            end
            lines(end+1) = string(app.info(name));
            if ~isempty(app.stepProviders) && isKey(app.stepProviders, name)
                lines(end+1) = "";
                lines(end+1) = "Provided by: " + string(app.stepProviders(name));
            end
        end

        function populateStepsTree(app)
        % POPULATESTEPSTREE  (Re)build the stage-grouped picker tree and the
        % name->info map from the steps this machine can run (availableSteps).
        % Leaf NodeData is the exact registry step name. Any available step the
        % taxonomy forgot is collected under "Other" so nothing silently
        % vanishes from the picker.
            delete(app.StepsTree.Children);
            reg             = stepRegistry();
            [steps, hidden] = availableSteps(reg);
            availNames      = {steps.name};
            % A withheld step leaves no trace in the tree, so "where did my
            % steps go" has to be answerable somewhere. Nearly always a missing
            % or too-old plugin - or EEGLAB not initialised, which used to hide
            % most of the registry here (see startupFcn).
            if ~isempty(hidden)
                nestLog('CFG', 'Step picker: %d of %d steps not offered: %s', ...
                    numel(hidden), numel(reg), strjoin({hidden.name}, ', '));
            end
            app.info        = containers.Map(availNames, {steps.info});

            % uitree node styling (uistyle/addStyle on a tree) is R2023b+; the
            % app's floor is R2023a, so probe once - the picker still builds on
            % older releases, just without bold headers / muted operation rows.
            canStyle = treeStylingSupported(app, app.StepsTree);

            TAX = stepTaxonomy();
            % Steps that can stop and wait for a human get the amber dot. The
            % set is derived from the registry via canStepBlock, so adding an
            % interactive step marks itself in the picker.
            % TODO: runPipelineCore's local findInteractiveSteps is still a
            % hardcoded name list and does not agree with the registry - it is
            % what actually gates the parallel-processing warning.
            app.stepBlocks    = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            app.stepProviders = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for r = 1:numel(reg)
                if ~ismember(reg(r).name, availNames); continue; end
                [tf, always] = canStepBlock(reg(r));
                if tf; app.stepBlocks(reg(r).name) = always; end
            end
            flag = stepInteractiveIcon();
            sCat = uistyle('FontWeight', 'bold');
            sOp  = uistyle('FontColor', [0.42 0.47 0.53]);

            placed = {};
            for c = 1:numel(TAX)
                cat = TAX(c);
                % keep only the operations/variants available on this machine
                ops = struct('name', {}, 'variants', {});
                cnt = 0;
                for o = 1:numel(cat.ops)
                    v = cat.ops(o).variants;
                    v = v(ismember({v.step}, availNames));
                    if isempty(v); continue; end
                    cnt = cnt + 1;
                    ops(cnt).name     = cat.ops(o).name;
                    ops(cnt).variants = v;
                end
                if cnt == 0; continue; end
                nShown = sum(arrayfun(@(o) numel(o.variants), ops));
                cNode = uitreenode(app.StepsTree, ...
                    'Text', sprintf('%s   (%d)', upper(cat.name), nShown), 'NodeData', '');
                if canStyle; addStyle(app.StepsTree, sCat, 'node', cNode); end
                for o = 1:numel(ops)
                    if numel(ops(o).variants) == 1
                        addStepLeaf(app, cNode, ops(o).variants(1), flag);
                    else
                        oNode = uitreenode(cNode, 'Text', ops(o).name, 'NodeData', '');
                        if canStyle; addStyle(app.StepsTree, sOp, 'node', oNode); end
                        for k = 1:numel(ops(o).variants)
                            addStepLeaf(app, oNode, ops(o).variants(k), flag);
                        end
                    end
                    placed = [placed, {ops(o).variants.step}]; %#ok<AGROW>
                end
            end

            % Safety net: surface any available step the taxonomy did not place.
            orphan = setdiff(availNames, placed);
            if ~isempty(orphan)
                oNode = uitreenode(app.StepsTree, ...
                    'Text', sprintf('OTHER   (%d)', numel(orphan)), 'NodeData', '');
                if canStyle; addStyle(app.StepsTree, sCat, 'node', oNode); end
                for i = 1:numel(orphan)
                    uitreenode(oNode, 'Text', orphan{i}, 'NodeData', orphan{i});
                end
            end

            expand(app.StepsTree);
            app.StepsTipLabel.Text = stepsTreeLegend(app);
        end

        function addStepLeaf(app, parent, v, flagIcon)
        % ADDSTEPLEAF  One leaf whose NodeData is the registry step name; an
        % amber dot marks a step that can stop and wait for a human.
            node = uitreenode(parent, 'Text', v.step, 'NodeData', v.step);
            app.stepProviders(v.step) = v.provider;
            if isKey(app.stepBlocks, v.step)
                % Set the flag after creation and tolerate its absence: the leaf
                % must always appear even on a release without node icons.
                try, node.Icon = flagIcon; catch, end %#ok<CTCH>
            end
        end

        function tf = treeStylingSupported(~, tree)
        % TREESTYLINGSUPPORTED  True when uistyle/addStyle work on a uitree node
        % (R2023b+). Probed at runtime rather than gated on a version string, so
        % the picker degrades gracefully without depending on release numbers.
            probe = uitreenode(tree, 'Text', '', 'NodeData', '');
            try
                addStyle(tree, uistyle('FontWeight', 'bold'), 'node', probe);
                tf = true;
            catch
                tf = false;
            end
            delete(probe);
        end

        function appendStep(app, stepName)
        % APPENDSTEP  Append stepName to the pipeline using its default params.
            reg    = stepRegistry();
            regIdx = find(strcmp({reg.name}, stepName), 1);
            if isempty(regIdx); return; end
            n = numel(app.SelectedListBox.Items);
            % Treat a single empty-string sentinel as an empty list
            if n == 1 && isempty(app.SelectedListBox.Items{1})
                n = 0;
                app.SelectedListBox.Items(:)     = [];
                app.SelectedListBox.ItemsData(:) = [];
                app.spec = repmat(struct('name','','params',struct()), 0, 1);
            end
            pos = n + 1;
            app.SelectedListBox.Items{pos}     = stepName;
            app.SelectedListBox.ItemsData{pos} = ['Item' num2str(pos)];
            app.spec(pos)                      = makePipelineStep(stepName, reg);
            app.pipelineDirty = true;
            updateStatusBar(app);
        end

        function removeStep(app, idx)
        % REMOVESTEP  Remove the step at index idx and renumber ItemsData.
            app.SelectedListBox.Items(idx)     = [];
            app.SelectedListBox.ItemsData(idx) = [];
            app.spec(idx)                      = [];
            for i = idx : numel(app.SelectedListBox.ItemsData)
                app.SelectedListBox.ItemsData{i} = ['Item' num2str(i)];
            end
            app.pipelineDirty = true;
            updateStatusBar(app);
        end

        function moveStep(app, idx, direction)
        % MOVESTEP  Swap step at idx with its neighbour in the given direction
        %   (+1 = move down, -1 = move up). No-op at boundaries.
            n    = numel(app.SelectedListBox.Items);
            idx2 = idx + direction;
            if idx2 < 1 || idx2 > n; return; end
            % Swap step names and spec entries
            [app.SelectedListBox.Items{idx}, app.SelectedListBox.Items{idx2}] = ...
                deal(app.SelectedListBox.Items{idx2}, app.SelectedListBox.Items{idx});
            [app.spec(idx), app.spec(idx2)] = deal(app.spec(idx2), app.spec(idx));
            % ItemsData stays in positional order - just renumber both slots
            app.SelectedListBox.ItemsData{idx}  = ['Item' num2str(idx)];
            app.SelectedListBox.ItemsData{idx2} = ['Item' num2str(idx2)];
            app.SelectedListBox.Value = app.SelectedListBox.ItemsData{idx2};
            app.pipelineDirty = true;
            updateStatusBar(app);
        end

        function clearSteps(app)
        % CLEARSTEPS  Remove all pipeline steps and reset state.
            app.spec = repmat(struct('name','','params',struct()), 0, 1);
            app.SelectedListBox.Items(:)     = [];
            app.SelectedListBox.ItemsData(:) = [];
            app.UITable.Data    = [];
            app.ItemNum          = 0;
            app.currentParamKey  = '';
            app.currentParamType = '';
            app.pipelineDirty   = true;
            updateStatusBar(app);
        end

        function idx = selectedStepIndex(app)
        % SELECTEDSTEPINDEX  Decode the current SelectedListBox selection to a 1-based index.
            idx = str2double(strrep(app.SelectedListBox.Value, 'Item', ''));
        end

        function refreshParamTable(app, stepIdx)
        % REFRESHPARAMTABLE  Update UITable from app.spec(stepIdx).
            reg    = stepRegistry();
            step   = app.spec(stepIdx);
            regIdx = find(strcmp({reg.name}, step.name), 1);
            if isempty(regIdx)
                app.UITable.Data = [];
                return
            end
            data = buildParamTableData(step, reg(regIdx));
            % Show params that are disabled for this step - overridden by a
            % mutually-exclusive sibling, or gated off by another param's value
            % - greyed out. The '(' prefix makes styleParamTable grey the cell.
            disabled = disabledParamKeys(reg(regIdx), step.params);
            if ~isempty(disabled)
                keys = {reg(regIdx).params.key};
                for k = 1:numel(disabled)
                    r = find(strcmp(keys, disabled{k}), 1);
                    if ~isempty(r)
                        data{r,2} = '(disabled)';
                    end
                end
            end
            app.UITable.Data = data;
            styleParamTable(app);
        end

        % -----------------------------------------------------------------

        function updateStatusBar(app)
        % UPDATESTATUSBAR  Refresh the status bar text from current app state.
        %   Called after any change to the pipeline list, data selection,
        %   or save/load operations.
            % Pipeline segment
            items = app.SelectedListBox.Items;
            nSteps = numel(items);
            if nSteps == 0 || (nSteps == 1 && isempty(items{1}))
                pipelineStr = 'Pipeline: (empty)';
            else
                name = app.pipelineName;
                if isempty(name); name = 'unsaved'; end
                if app.pipelineDirty
                    pipelineStr = sprintf('Pipeline: %s*  (%d steps)', name, nSteps);
                else
                    pipelineStr = sprintf('Pipeline: %s  (%d steps)', name, nSteps);
                end
            end
            % Data segment
            n = app.NSelecFiles;
            if isempty(n); n = 0; end
            fileWord = 'files'; if n == 1; fileWord = 'file'; end
            if n == 0
                dataStr = 'Data: (none)';
            elseif (ischar(app.path) || isstring(app.path)) && ~isempty(app.path)
                % Single-folder selection - show the folder name.
                parts = strsplit(strtrim(char(app.path)), {'\','/'});
                parts(cellfun(@isempty, parts)) = [];
                folder = parts{end};
                dataStr = sprintf('Data: %s/  (%d %s)', folder, n, fileWord);
            else
                % Multi-folder selection - count the distinct parent folders.
                parents  = cellfun(@fileparts, app.filePaths, 'UniformOutput', false);
                nFolders = numel(unique(parents));
                folderWord = 'folders'; if nFolders == 1; folderWord = 'folder'; end
                dataStr = sprintf('Data: %d %s in %d %s', n, fileWord, nFolders, folderWord);
            end
            app.StatusBar.Text = sprintf('  %s          %s', pipelineStr, dataStr);
        end

        % MenuOpening function: MenuRecentFiles
        function buildRecentFilesMenu(app)
            delete(app.MenuRecentFiles.Children);
            list = getpref('nestapp', 'recentFiles', {});
            if isempty(list)
                uimenu(app.MenuRecentFiles, 'Text', '(none)', 'Enable', 'off');
                return
            end
            for i = 1:numel(list)
                folder = list{i};
                uimenu(app.MenuRecentFiles, 'Text', folder, ...
                    'MenuSelectedFcn', @(~,~) openRecentData(app, folder));
            end
        end

        function buildRecentPipelinesMenu(app)
            delete(app.MenuRecentPipelines.Children);
            list = getpref('nestapp', 'recentPipelines', {});
            if isempty(list)
                uimenu(app.MenuRecentPipelines, 'Text', '(none)', 'Enable', 'off');
                return
            end
            for i = 1:numel(list)
                pPath = list{i};
                [~,nm,ex] = fileparts(pPath);
                uimenu(app.MenuRecentPipelines, 'Text', [nm ex], ...
                    'MenuSelectedFcn', @(~,~) openRecentPipeline(app, pPath));
            end
        end

        function openRecentData(app, folder)
        % Open the data browser straight into a recently used folder.
            if ~isfolder(folder)
                uialert(app.UIFigure, 'Folder no longer exists.', 'Not Found');
                return
            end
            paths = selectDataTree(folder, app.dataFileExts());
            if isempty(paths); return; end
            setFileQueue(app, paths);
            if isvalid(app.UIFigure); figure(app.UIFigure); end
        end

        function openRecentPipeline(app, pPath)
        % Load a pipeline from a recently used full file path.
            if ~isfile(pPath)
                uialert(app.UIFigure, 'Pipeline file no longer exists.', 'Not Found');
                return
            end
            [pFolder, ~, ~] = fileparts(pPath);
            try
                loadPipelineData(app, pPath);
                setpref('nestapp', 'lastPipelineFolder', pFolder);
                pushRecent(app, 'recentPipelines', pPath);
                buildRecentPipelinesMenu(app);
            catch err
                uialert(app.UIFigure, err.message, 'Load Error', 'Icon', 'error');
            end
        end

        function loadPipelineData(app, fullPath)
        % LOADPIPELINEDATA  Load pipeline state from a .mat into app.spec.
        %   Unknown steps produce a warning dialog.
            data = load(fullPath, '-mat');
            reg  = stepRegistry();
            [app.spec, warns] = specFromSaved(data, reg);

            if ~isempty(warns)
                uialert(app.UIFigure, strjoin(warns, newline), ...
                    'Pipeline Warning', 'Icon', 'warning');
            end

            n = numel(app.spec);
            items     = cell(1, n);
            itemsData = cell(1, n);
            for k = 1:n
                items{k}     = app.spec(k).name;
                itemsData{k} = ['Item' num2str(k)];
            end
            app.SelectedListBox.Items     = items;
            app.SelectedListBox.ItemsData = itemsData;

            app.currentParamKey  = '';
            app.currentParamType = '';
            app.UITable.Data     = [];

            if n > 0
                app.SelectedListBox.Value = itemsData{1};
                refreshParamTable(app, 1);
            end
        end

        % MenuSelected callback wrappers (thin shims so uimenu can call private methods)
        function openPreferencesMenu(app, ~)
            openPreferences(app);
        end

        function showAboutMenu(app, ~)
            showAbout(app);
        end

        function copyDiagnosticsMenu(app, ~)
        % COPYDIAGNOSTICSMENU  Help-menu action: copy environment diagnostics.
        %   Runs nestappDoctor, copies the Markdown report to the clipboard,
        %   and shows the problems summary so the user can paste it into a
        %   bug report (see .github/ISSUE_TEMPLATE/bug_report.yml).
            try
                [~, diagInfo] = nestappDoctor('Copy', true, 'Quiet', true);
            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Could not collect diagnostics:\n%s', ME.message), ...
                    'Diagnostics Failed', 'Icon', 'error');
                return
            end
            if isempty(diagInfo.problems)
                msg  = 'Diagnostics copied to the clipboard. No problems detected.';
                icon = 'success';
            else
                msg  = sprintf(['Diagnostics copied to the clipboard.\n\n' ...
                    '%d problem(s) detected:\n  - %s'], ...
                    numel(diagInfo.problems), strjoin(diagInfo.problems, sprintf('\n  - ')));
                icon = 'warning';
            end
            uialert(app.UIFigure, msg, 'nestapp Diagnostics', 'Icon', icon);
        end

        function copyPipelineDescriptionMenu(app, ~)
        % COPYPIPELINEDESCRIPTIONMENU  File-menu action: copy a readable
        %   description of the current pipeline (steps + customised params)
        %   to the clipboard, for methods sections and bug reports.
            if isempty(app.spec)
                uialert(app.UIFigure, 'The pipeline is empty - add steps first.', ...
                    'No Pipeline', 'Icon', 'warning');
                return
            end
            try
                describePipeline(app.spec, 'Copy', true, 'Quiet', true);
            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Could not describe the pipeline:\n%s', ME.message), ...
                    'Export Failed', 'Icon', 'error');
                return
            end
            uialert(app.UIFigure, sprintf( ...
                'Pipeline description (%d steps) copied to the clipboard.', ...
                numel(app.spec)), 'Pipeline Copied', 'Icon', 'success');
        end

        function revealFolder(~, folder)
        % REVEALFOLDER  Open a folder in the OS file browser (best-effort).
            try
                if ispc
                    winopen(folder);
                elseif ismac
                    system(sprintf('open "%s" &', folder));
                else
                    system(sprintf('xdg-open "%s" &', folder));
                end
            catch
                % Non-fatal: the path is shown in the dialog regardless.
            end
        end

        function collectSupportBundleMenu(app, ~)
        % COLLECTSUPPORTBUNDLEMENU  Help action: write a metadata-only support
        %   bundle (environment + current pipeline) and reveal the folder.
            outRoot = getpref('nestapp', 'outputRoot', '');
            if isempty(outRoot) || ~isfolder(outRoot)
                outRoot = tempdir;
            end
            try
                bundleDir = collectSupportBundle(outRoot, app.spec);
            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Could not collect support bundle:\n%s', ME.message), ...
                    'Support Bundle Failed', 'Icon', 'error');
                return
            end
            revealFolder(app, bundleDir);
            uialert(app.UIFigure, sprintf(['Support bundle written to:\n%s\n\n' ...
                'It contains environment + pipeline details only (no recordings). ' ...
                'Attach the folder to your bug report.'], bundleDir), ...
                'Support Bundle', 'Icon', 'success');
        end

        function selfTestMenu(app, ~)
        % SELFTESTMENU  Help action: run the fast test suite to verify the
        %   install, reporting pass/fail. Best-effort: needs tests/ present.
            repo = fileparts(fileparts(which('nestappVersion')));
            runner = fullfile(repo, 'tests', 'run_tests.m');
            if ~isfile(runner)
                uialert(app.UIFigure, ['The test suite (tests/) is not present ' ...
                    'in this installation, so the self-test cannot run.'], ...
                    'Self-test Unavailable', 'Icon', 'warning');
                return
            end
            dlg = uiprogressdlg(app.UIFigure, 'Title', 'Checking install', ...
                'Message', 'Running the fast test suite...', 'Indeterminate', 'on');
            closeDlg = onCleanup(@() close(dlg));
            try
                addpath(fullfile(repo, 'tests'));
                addpath(fullfile(repo, 'tests', 'helpers'));
                results = [];
                evalc('results = run_tests(''fast'')');   % capture verbose output
            catch ME
                clear closeDlg;
                uialert(app.UIFigure, sprintf('Self-test could not run:\n%s', ...
                    ME.message), 'Self-test Error', 'Icon', 'error');
                return
            end
            clear closeDlg;
            nPass = sum([results.Passed]);
            nFail = sum([results.Failed]);
            nInc  = sum([results.Incomplete]);
            if nFail == 0
                uialert(app.UIFigure, sprintf(['Install looks healthy.\n' ...
                    '%d passed, %d skipped (optional plugins).'], nPass, nInc), ...
                    'Self-test Passed', 'Icon', 'success');
            else
                uialert(app.UIFigure, sprintf(['%d test(s) FAILED (%d passed).\n' ...
                    'Run Help > Copy Diagnostics and check your setup.'], nFail, nPass), ...
                    'Self-test Failed', 'Icon', 'error');
            end
        end

        function loadPrefs(~)
        % LOADPREFS  Read persistent preferences and apply to app state.
        %   Called from startupFcn. Uses MATLAB getpref with 'nestapp' group.
        %   The app handle is accepted but not used - prefs apply globally
        %   (addpath) rather than writing to removed UI components.
            eeglabPath = getpref('nestapp', 'eeglabPath', '');
            if ~isempty(eeglabPath) && isfolder(eeglabPath)
                addpath(eeglabPath);
            end

            % One-shot migration: legacy 'reportFolder' pref folds into
            % the new unified 'outputRoot' pref.
            if ispref('nestapp', 'reportFolder')
                rf = getpref('nestapp', 'reportFolder', '');
                if ~ispref('nestapp', 'outputRoot') && ~isempty(rf) && isfolder(rf)
                    setpref('nestapp', 'outputRoot', rf);
                    nestLog('CFG', 'Migrated reportFolder pref -> outputRoot: %s', rf);
                end
                rmpref('nestapp', 'reportFolder');
            end
        end

        function pushRecent(app, prefKey, newEntry) %#ok<INUSL>
        % PUSHRECENT  Prepend newEntry to a 5-item MRU list stored in prefs.
            list = getpref('nestapp', prefKey, {});
            list = [{newEntry}, list(~strcmp(list, newEntry))];
            list = list(1:min(end, 5));
            setpref('nestapp', prefKey, list);
        end

        function openPreferences(~)
        % OPENPREFERENCES  Show a modal Preferences dialog.
        %   Lets users set the EEGLAB path, default data/pipeline folders,
        %   and behavioural options. Changes are written to getpref/setpref
        %   under the 'nestapp' group and applied immediately on Save.
            dlg = uifigure('Name', 'nestapp Preferences', ...
                'Position', [200 200 420 664], ...
                'WindowStyle', 'modal', 'Resize', 'off');

            % --- Quality Screening section (new, at top) ---
            uilabel(dlg, 'Text', 'Quality Screening', 'FontWeight', 'bold', ...
                'Position', [15 629 200 20]);
            cbAutoQC = uicheckbox(dlg, 'Text', 'Auto-generate QC images at each Quality Gate', ...
                'Position', [15 604 380 22], ...
                'Value', getpref('nestapp', 'autoQualityReport', false));
            cbTmsAuto = uicheckbox(dlg, 'Text', 'Auto-detect TMS pulse window from EEG events', ...
                'Position', [15 582 380 22], ...
                'Value', getpref('nestapp', 'qualityTmsAutoDetect', true));
            cbSkipFail = uicheckbox(dlg, 'Text', 'Skip remaining pipeline steps when Quality Gate fails', ...
                'Position', [15 560 380 22], ...
                'Value', getpref('nestapp', 'skipOnQualityFail', false));
            cbAutoPDF = uicheckbox(dlg, 'Text', 'Auto-save PDF report per file (text + checkpoint images)', ...
                'Position', [15 538 380 22], ...
                'Value', getpref('nestapp', 'autoExportPDF', false));
            cbAaratepKeep = uicheckbox(dlg, 'Text', 'Keep AARATEP intermediate datasets (~3x the result on disk)', ...
                'Position', [15 516 380 22], ...
                'Value', getpref('nestapp', 'aaratepKeepIntermediates', true));
            cbAaratepKeep.Tooltip = ['AARATEP writes the dataset before SOUND, before decay ' ...
                'removal and before ICA rejection, as well as the result - four full ' ...
                'datasets per file. Untick to delete the three intermediates once the ' ...
                'step finishes; the result and the QC images are always kept.'];
            uilabel(dlg, 'Text', 'Attribute mode:', ...
                'Position', [15 487 95 22], 'HorizontalAlignment', 'right');
            qcModes = qualityAttributeModes();
            ddAttr = uidropdown(dlg, ...
                'Position', [115 487 150 22], ...
                'Items', qcModes, ...
                'Value', resolveAttributePref());
            uilabel(dlg, 'Text', 'TMS window (ms):', ...
                'Position', [15 460 105 22], 'HorizontalAlignment', 'right');
            qcWin = readTmsWindowPref();
            nfTmsStart = uieditfield(dlg, 'numeric', ...
                'Position', [125 460 55 22], 'Value', qcWin(1));
            uilabel(dlg, 'Text', 'to', ...
                'Position', [185 460 15 22], 'HorizontalAlignment', 'center');
            nfTmsEnd = uieditfield(dlg, 'numeric', ...
                'Position', [205 460 55 22], 'Value', qcWin(2));

            % --- EEGLAB section ---
            uilabel(dlg, 'Text', 'EEGLAB', 'FontWeight', 'bold', ...
                'Position', [15 420 200 20]);
            uilabel(dlg, 'Text', 'Path:', ...
                'Position', [15 395 35 22], 'HorizontalAlignment', 'right');
            fEeglab = uieditfield(dlg, 'text', ...
                'Position', [55 395 275 22], 'Editable', 'on', ...
                'Value', getpref('nestapp','eeglabPath',''));
            uibutton(dlg, 'Text', 'Browse...', 'Position', [335 395 70 22], ...
                'ButtonPushedFcn', @(~,~) browseEeglab());

            % --- Default Locations section ---
            uilabel(dlg, 'Text', 'Default Locations', 'FontWeight', 'bold', ...
                'Position', [15 365 200 20]);
            uilabel(dlg, 'Text', 'Data folder:', ...
                'Position', [15 340 65 22], 'HorizontalAlignment', 'right');
            fData = uieditfield(dlg, 'text', ...
                'Position', [85 340 245 22], 'Editable', 'on', ...
                'Value', getpref('nestapp','lastDataFolder',''));
            uibutton(dlg, 'Text', 'Browse...', 'Position', [335 340 70 22], ...
                'ButtonPushedFcn', @(~,~) browseFolder(fData));
            uilabel(dlg, 'Text', 'Pipeline folder:', ...
                'Position', [15 312 80 22], 'HorizontalAlignment', 'right');
            fPipeline = uieditfield(dlg, 'text', ...
                'Position', [100 312 230 22], 'Editable', 'on', ...
                'Value', getpref('nestapp','lastPipelineFolder',''));
            uibutton(dlg, 'Text', 'Browse...', 'Position', [335 312 70 22], ...
                'ButtonPushedFcn', @(~,~) browseFolder(fPipeline));
            uilabel(dlg, 'Text', 'Output root:', ...
                'Position', [15 284 75 22], 'HorizontalAlignment', 'right');
            fOutputRoot = uieditfield(dlg, 'text', ...
                'Position', [95 284 235 22], 'Editable', 'on', ...
                'Value', getpref('nestapp','outputRoot',''));
            uibutton(dlg, 'Text', 'Browse...', 'Position', [335 284 70 22], ...
                'ButtonPushedFcn', @(~,~) browseFolder(fOutputRoot));
            uilabel(dlg, 'Text', 'Layout:', ...
                'Position', [15 256 75 22], 'HorizontalAlignment', 'right');
            ddLayout = uidropdown(dlg, ...
                'Position', [95 256 175 22], ...
                'Items',     {'By type (data/reports/qc)', 'Per input file'}, ...
                'ItemsData', {'typeBased',                  'perInput'}, ...
                'Value',     getpref('nestapp','outputLayout','typeBased'));
            uilabel(dlg, 'Text', '(blank root = next to inputs)', ...
                'Position', [275 256 140 22], 'FontColor', [0.4 0.4 0.4], 'FontSize', 10);

            % --- Behaviour section ---
            uilabel(dlg, 'Text', 'Behaviour', 'FontWeight', 'bold', ...
                'Position', [15 223 200 20]);
            cbReport = uicheckbox(dlg, 'Text', 'Switch to Reports tab after each run', ...
                'Position', [15 199 300 22], ...
                'Value', getpref('nestapp','showReport',true));
            cbConfirm = uicheckbox(dlg, 'Text', 'Confirm before clearing pipeline', ...
                'Position', [15 175 300 22], ...
                'Value', getpref('nestapp','confirmClear',true));
            cbOverwrite = uicheckbox(dlg, 'Text', 'Overwrite existing report files (no timestamp)', ...
                'Position', [15 151 320 22], ...
                'Value', getpref('nestapp','overwriteReports',false));
            cbSuppressDialogs = uicheckbox(dlg, ...
                'Text', 'Suppress EEGLAB processing dialogs (warn about overwrites before run)', ...
                'Position', [15 127 390 22], ...
                'Value', getpref('nestapp','suppressEEGLABDialogs',true));
            cbHideEEGLAB = uicheckbox(dlg, ...
                'Text', 'Hide EEGLAB window during processing', ...
                'Position', [15 103 300 22], ...
                'Value', getpref('nestapp','hideEEGLABWindow',true));

            % --- Parallel Processing section ---
            uilabel(dlg, 'Text', 'Parallel Processing', 'FontWeight', 'bold', ...
                'Position', [15 72 200 20]);
            spnWorkers = [];
            if license('test', 'Distrib_Computing_Toolbox')
                uilabel(dlg, 'Text', 'Max workers:', ...
                    'Position', [15 48 85 22], 'HorizontalAlignment', 'right');
                spnWorkers = uispinner(dlg, ...
                    'Position', [105 48 60 22], 'Limits', [1 32], 'Step', 1, ...
                    'Value', getpref('nestapp', 'maxParallelWorkers', 4));
                uilabel(dlg, 'Text', 'cap on simultaneous files when Parallel is on', ...
                    'Position', [172 48 240 22], 'FontColor', [0.4 0.4 0.4]);
            else
                uilabel(dlg, 'Text', 'Not available - Parallel Computing Toolbox not licensed.', ...
                    'Position', [15 48 385 22], 'FontColor', [0.5 0.5 0.5]);
            end

            % --- Buttons ---
            uibutton(dlg, 'Text', 'Cancel', 'Position', [220 15 85 28], ...
                'ButtonPushedFcn', @(~,~) close(dlg));
            uibutton(dlg, 'Text', 'Save', 'Position', [315 15 85 28], ...
                'BackgroundColor', [0.20 0.55 0.20], 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) savePrefs());

            uiwait(dlg);

            %% Nested helpers
            function browseEeglab()
                p = uigetdir('', 'Select EEGLAB Folder');
                if ~isequal(p, 0); fEeglab.Value = p; end
            end
            function browseFolder(field)
                p = uigetdir('', 'Select Folder');
                if ~isequal(p, 0); field.Value = p; end
            end
            function savePrefs()
                % EEGLAB path - warn on invalid value but don't abort
                % the rest of the save (otherwise the other preferences
                % the user just toggled would silently be discarded).
                ep = strtrim(fEeglab.Value);
                eeglabPathValid = isempty(ep) || isfolder(ep);
                if ~eeglabPathValid
                    uialert(dlg, ['EEGLAB path does not exist: ' ep ...
                        '. Other preferences were still saved.'], ...
                        'Invalid EEGLAB Path', 'Icon', 'warning');
                elseif ~isempty(ep)
                    addpath(ep);
                end
                setpref('nestapp', 'eeglabPath',          ep);
                setpref('nestapp', 'lastDataFolder',      strtrim(fData.Value));
                setpref('nestapp', 'lastPipelineFolder',  strtrim(fPipeline.Value));
                setpref('nestapp', 'outputRoot',          strtrim(fOutputRoot.Value));
                setpref('nestapp', 'outputLayout',        ddLayout.Value);
                setpref('nestapp', 'showReport',             cbReport.Value);
                setpref('nestapp', 'confirmClear',           cbConfirm.Value);
                setpref('nestapp', 'overwriteReports',       cbOverwrite.Value);
                setpref('nestapp', 'suppressEEGLABDialogs',  cbSuppressDialogs.Value);
                setpref('nestapp', 'hideEEGLABWindow',       cbHideEEGLAB.Value);
                if ~isempty(spnWorkers)
                    setpref('nestapp', 'maxParallelWorkers', round(spnWorkers.Value));
                end

                % Quality Screening prefs - validation mirrors
                % runPipelineCore: invalid mode -> minmax_no_tms,
                % inverted window -> [0 25].
                setpref('nestapp', 'autoQualityReport',    cbAutoQC.Value);
                setpref('nestapp', 'qualityTmsAutoDetect', cbTmsAuto.Value);
                setpref('nestapp', 'skipOnQualityFail',    cbSkipFail.Value);
                setpref('nestapp', 'autoExportPDF',        cbAutoPDF.Value);
                setpref('nestapp', 'aaratepKeepIntermediates', cbAaratepKeep.Value);

                attr = ddAttr.Value;
                if ~any(strcmp(attr, qualityAttributeModes()))
                    attr = 'minmax_no_tms';
                end
                setpref('nestapp', 'qualityAttribute', attr);

                w = [nfTmsStart.Value, nfTmsEnd.Value];
                if ~(isnumeric(w) && numel(w) == 2 && w(2) > w(1))
                    w = [0 25];
                end
                setpref('nestapp', 'qualityTmsWindow', w);

                close(dlg);
            end
            function v = resolveAttributePref()
                v = getpref('nestapp', 'qualityAttribute', 'minmax_no_tms');
                if ~any(strcmp(v, qualityAttributeModes()))
                    v = 'minmax_no_tms';
                end
            end
            function w = readTmsWindowPref()
                w = getpref('nestapp', 'qualityTmsWindow', [0 25]);
                if ~(isnumeric(w) && numel(w) == 2 && w(2) > w(1))
                    w = [0 25];
                end
            end
        end

        function updateReportsTabImpl(app)
        % UPDATEREPORTSTABIMPL  Refresh the Reports tab listbox from session and loaded reports.
        %   Combines app.allPipelineReports (from current run) with app.loadedReports
        %   (loaded from disk). Updates listbox labels and status text. When
        %   any report has Quality Gate data, appends a synthetic "Session
        %   Quality Dashboard" entry that swaps the right-side area to the
        %   dashboard panel on selection.
            allEntries = [app.allPipelineReports, app.loadedReports];
            n = numel(allEntries);
            if n == 0
                app.ReportsListBox.Items = {};
                app.ReportsListBox.ItemsData = {};
                app.ReportsStatusLabel.Text = 'No reports loaded.';
                app.ReportsTextArea.Value = '';
                app.ReportsDashboardPanel.Visible = 'off';
                app.ReportsTextArea.Visible = 'on';
                app.ExportReportsCSVButton.Enable = 'off';
                app.ExportPDFButton.Enable = 'off';
                app.CopyMethodsButton.Enable = 'off';
                return
            end

            % Append the Dashboard synthetic entry when any report has
            % gates - keeps the listbox tidy when nothing was screened.
            if app.dashboardHasContent(allEntries)
                dashEntry = struct('isDashboard', true, ...
                    'text', '', 'report', struct());
                allEntries{end+1} = dashEntry;
                n = numel(allEntries);
            end

            labels = cell(1, n);
            for i = 1:n
                e = allEntries{i};
                if isfield(e, 'isDashboard') && e.isDashboard
                    labels{i} = 'Session Quality Dashboard';
                elseif isfield(e, 'isSummary') && e.isSummary
                    % Extract file count from the summary header line
                    tok = regexp(e.text, 'PIPELINE SUMMARY\s+\((\d+) files\)', 'tokens', 'once');
                    if ~isempty(tok)
                        labels{i} = sprintf('Session Summary (%s files)', tok{1});
                    else
                        labels{i} = 'Session Summary';
                    end
                else
                    [~, baseName] = fileparts(e.report.inputFile);
                    try
                        dateLabel = string(e.report.processedAt, 'yyyy-MM-dd HH:mm');
                    catch
                        dateLabel = '?';
                    end
                    prefix = '';
                    if isfield(e.report, 'quality') ...
                            && isfield(e.report.quality, 'worstVerdict')
                        switch e.report.quality.worstVerdict
                            case 'Fail',     prefix = '[FAIL] ';
                            case 'Marginal', prefix = '[MARG] ';
                            case 'Pass',     prefix = '[PASS] ';
                        end
                    end
                    labels{i} = sprintf('%s%s (%s)', prefix, baseName, dateLabel);
                end
            end

            % Preserve selection index across refresh if still valid
            prevIdx = app.ReportsListBox.Value;
            app.ReportsListBox.Items = labels;
            app.ReportsListBox.ItemsData = num2cell(1:n);

            if isnumeric(prevIdx) && ~isempty(prevIdx) && prevIdx >= 1 && prevIdx <= n
                app.ReportsListBox.Value = prevIdx;
            else
                app.ReportsListBox.Value = n;
            end
            renderReportsRightPane(app, allEntries);

            nSess   = numel(app.allPipelineReports);
            nLoaded = numel(app.loadedReports);
            parts   = {};
            if nSess   > 0; parts{end+1} = sprintf('%d from session', nSess);   end
            if nLoaded > 0; parts{end+1} = sprintf('%d from disk', nLoaded); end
            app.ReportsStatusLabel.Text = strjoin(parts, ', ');
            app.ExportReportsCSVButton.Enable = 'on';
            app.ExportPDFButton.Enable = 'on';
            app.CopyMethodsButton.Enable = 'on';
        end

        function ReportsListBoxValueChanged(app, ~)
        % Callback - swap the right-side pane based on the selected entry.
            allEntries = [app.allPipelineReports, app.loadedReports];
            if app.dashboardHasContent(allEntries)
                allEntries{end+1} = struct('isDashboard', true, ...
                    'text', '', 'report', struct());
            end
            renderReportsRightPane(app, allEntries);
        end

        function renderReportsRightPane(app, allEntries)
        % Show the dashboard panel for the Dashboard entry; otherwise show
        % the report text in the text area. Called by both
        % updateReportsTabImpl (after a refresh) and the listbox callback.
            idx = app.ReportsListBox.Value;
            if isempty(idx) || ~isnumeric(idx) ...
                    || idx < 1 || idx > numel(allEntries)
                return
            end
            e = allEntries{idx};
            if isfield(e, 'isDashboard') && e.isDashboard
                app.ReportsTextArea.Visible       = 'off';
                app.ReportsDashboardPanel.Visible = 'on';
                renderDashboardPanel(app.ReportsDashboardPanel, ...
                    collectReportStructs(allEntries), ...
                    struct( ...
                        'onRefresh',        @() updateReportsTabImpl(app), ...
                        'onExport',         @() exportDashboardPNG(app, allEntries), ...
                        'onFailedRowClick', @(name) jumpToFileEntry(app, allEntries, name), ...
                        'failed',           app.lastFailed));
            else
                app.ReportsDashboardPanel.Visible = 'off';
                app.ReportsTextArea.Visible       = 'on';
                if isfield(e, 'text')
                    app.ReportsTextArea.Value = e.text;
                end
            end
        end

        function reRenderReportsOnResize(app)
        % Repaint the Session Quality Dashboard after a window resize so its
        % absolute-positioned children (heatmap, table, histograms) reflow to
        % the new panel size. No-op unless the dashboard is the visible pane;
        % renderDashboardPanel itself clears and re-lays-out from parent size.
            if isempty(app.ReportsDashboardPanel) || ~isvalid(app.ReportsDashboardPanel)
                return
            end
            if ~strcmp(app.ReportsDashboardPanel.Visible, 'on'); return; end
            allEntries = [app.allPipelineReports, app.loadedReports];
            if app.dashboardHasContent(allEntries)
                allEntries{end+1} = struct('isDashboard', true, ...
                    'text', '', 'report', struct());
            end
            renderReportsRightPane(app, allEntries);
        end

        function exportDashboardPNG(app, allEntries)
        % Render the dashboard into an offscreen uifigure and save as PNG.
            [fname, fpath] = uiputfile('*.png', 'Export Quality Dashboard', ...
                'quality_dashboard.png');
            if isequal(fname, 0); return; end
            outPath = fullfile(fpath, fname);
            fig = uifigure('Visible', 'off', 'Position', [100 100 1200 800]);
            cleanup = onCleanup(@() close(fig, 'force'));
            renderDashboardPanel(fig, collectReportStructs(allEntries), ...
                struct('failed', app.lastFailed));
            try
                exportgraphics(fig, outPath, 'Resolution', 150);
                app.ReportsStatusLabel.Text = sprintf('Dashboard saved: %s', fname);
            catch err
                uialert(app.UIFigure, ...
                    sprintf('Export failed: %s', err.message), ...
                    'Export Dashboard PNG', 'Icon', 'error');
            end
        end

        function jumpToFileEntry(app, allEntries, fileName)
        % Failed-files table row click handler - select the listbox
        % entry for the given file basename so the user sees its text.
            for i = 1:numel(allEntries)
                e = allEntries{i};
                if isfield(e, 'isSummary') || isfield(e, 'isDashboard'), continue, end
                if ~isfield(e, 'report') || ~isfield(e.report, 'inputFile'), continue, end
                [~, name] = fileparts(e.report.inputFile);
                if strcmp(name, fileName)
                    app.ReportsListBox.Value = i;
                    renderReportsRightPane(app, allEntries);
                    return
                end
            end
        end

        function tf = dashboardHasContent(app, allEntries)
        % Whether to append the synthetic "Session Quality Dashboard" entry.
        % Worth showing when any report carries Quality Gate data OR when the
        % last run left files that did not complete - so failures are visible
        % even for a gate-less pipeline. Must be consulted at every site that
        % builds allEntries, or the dashboard row's index desyncs.
            tf = anyReportHasGates(allEntries) || ~isempty(app.lastFailed);
        end

        function LoadReportsButtonPushed(app, ~)
        % Browse for a folder of pipeline report .mat files and load them.
            folder = uigetdir(reportsBrowseStart(app), ...
                'Select Folder with Pipeline Reports');
            if isequal(folder, 0); return; end
            setpref('nestapp', 'lastReportsFolder', folder);

            matFiles = findReportMatFiles(folder);
            if isempty(matFiles)
                uialert(app.UIFigure, ...
                    ['No report .mat files (*_report.mat) found in that ' ...
                     'folder or its subfolders.'], 'No Reports Found');
                return
            end
            loaded = 0;
            for k = 1:numel(matFiles)
                fpath = fullfile(matFiles(k).folder, matFiles(k).name);
                try
                    S = load(fpath, 'pipelineReport');
                    if ~isfield(S, 'pipelineReport'); continue; end
                    % buildReportText, not exportReport: the latter is that
                    % plus a save() of the whole struct, so loading N reports
                    % wrote N throwaway .mat files to tempdir.
                    txt = buildReportText(S.pipelineReport);
                    entry.text   = txt;
                    entry.report = S.pipelineReport;
                    app.loadedReports{end+1} = entry;
                    loaded = loaded + 1;
                catch ME
                    warning('nestapp:loadReport', 'Could not load %s: %s', matFiles(k).name, ME.message);
                end
            end

            folderParts = strsplit(folder, {'\','/'});
            folderParts(cellfun(@isempty, folderParts)) = [];
            app.ReportsFolderLabel.Text = folderParts{end};
            updateReportsTabImpl(app);

            if loaded > 0
                app.TabGroup.SelectedTab = app.ReportsTab;
            end
        end

        function ClearReportsButtonPushed(app, ~)
        % Empty the report list, which otherwise accumulates across every run
        % in a session. Discards only the in-memory list - the reports are all
        % on disk - but there is no in-session undo, hence the confirm.
            allEntries = [app.allPipelineReports, app.loadedReports];
            if isempty(allEntries)
                app.ReportsStatusLabel.Text = 'No reports to clear.';
                return
            end

            answer = uiconfirm(app.UIFigure, sprintf( ...
                ['Remove all %d report(s) from the list?\n\n' ...
                 'This only empties the list - nothing on disk is deleted, and ' ...
                 '"Load from Folder" can bring saved reports back.'], numel(allEntries)), ...
                'Clear Report List', ...
                'Options', {'Clear', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(answer, 'Clear'); return; end

            app.allPipelineReports = {};
            app.loadedReports      = {};
            % Stale failures would otherwise keep the Quality Dashboard entry
            % alive for reports that are no longer listed.
            app.lastFailed         = struct([]);
            app.ReportsFolderLabel.Text = '';
            updateReportsTabImpl(app);
            app.ReportsStatusLabel.Text = 'Report list cleared.';
        end

        function startFolder = reportsBrowseStart(~)
        % Where the folder picker should open. Reports live under the output
        % tree, so prefer the folder reports were last loaded from, then the
        % output root - NOT lastDataFolder, which points at raw input data and
        % is typically a network share. Handing uigetdir a remote or stale
        % path makes the dialog stall while the shell enumerates it, so every
        % candidate is checked with isfolder first.
            candidates = { ...
                getpref('nestapp', 'lastReportsFolder', ''), ...
                getpref('nestapp', 'outputRoot',        ''), ...
                getpref('nestapp', 'lastDataFolder',    '')};
            startFolder = '';
            for k = 1:numel(candidates)
                c = candidates{k};
                if ~isempty(c) && isfolder(c)
                    startFolder = c;
                    return
                end
            end
        end

        function ExportReportsCSVButtonPushed(app, ~)
        % Export a CSV table of key metrics for all visible reports.
            allEntries = [app.allPipelineReports, app.loadedReports];
            if isempty(allEntries)
                uialert(app.UIFigure, 'No reports to export.', 'Export CSV');
                return
            end

            [fname, fpath] = uiputfile('*.csv', 'Export Reports as CSV', 'nestapp_reports.csv');
            if isequal(fname, 0); return; end

            fid = fopen(fullfile(fpath, fname), 'w');
            if fid == -1
                uialert(app.UIFigure, 'Could not open file for writing.', 'Export CSV');
                return
            end

            % Header
            fprintf(fid, ['File,Processed,Channels (orig),Channels (final),' ...
                'Trials (orig),Trials (final),ICA removed,' ...
                'Quality_Verdict,Quality_Reasons\n']);

            for i = 1:numel(allEntries)
                e = allEntries{i};
                if isfield(e, 'isSummary') && e.isSummary; continue; end
                r = e.report;
                [~, baseName] = fileparts(r.inputFile);
                try
                    dStr = string(r.processedAt, 'yyyy-MM-dd HH:mm:ss');
                catch
                    dStr = '?';
                end

                verdict = 'NotChecked';
                reasons = '';
                if isfield(r, 'quality')
                    if isfield(r.quality, 'worstVerdict') ...
                            && ~isempty(r.quality.worstVerdict)
                        verdict = r.quality.worstVerdict;
                    end
                    if isfield(r.quality, 'gates') && ~isempty(r.quality.gates)
                        allReasons = {};
                        for gi = 1:numel(r.quality.gates)
                            g = r.quality.gates{gi};
                            if isfield(g, 'reasons') && ~isempty(g.reasons)
                                allReasons = [allReasons, g.reasons]; %#ok<AGROW>
                            end
                        end
                        reasons = strjoin(allReasons, '; ');
                        reasons = strrep(reasons, ',', ';'); % keep CSV-safe
                    end
                end

                fprintf(fid, '%s,%s,%d,%d,%d,%d,%d,%s,%s\n', ...
                    baseName, dStr, ...
                    r.channels.original, r.channels.final, ...
                    r.trials.original, r.trials.final, ...
                    r.ica.nRejected, verdict, reasons);
            end
            fclose(fid);
            app.ReportsStatusLabel.Text = sprintf('CSV saved: %s', fname);
        end

        function ExportPDFButtonPushed(app, ~)
        % Export report text + checkpoint PNGs as PDF, for the selected file
        % or for every listed report. One file at a time used to be the only
        % option, which made a whole batch tedious whenever Auto-export PDF
        % was off - and it is off by default.
            allEntries  = [app.allPipelineReports, app.loadedReports];
            fileReports = renderableReports(app, allEntries);
            if isempty(fileReports)
                uialert(app.UIFigure, 'No file reports to export.', 'Export PDF');
                return
            end

            selected = selectedFileReport(app, allEntries);
            switch askPdfScope(app, selected, numel(fileReports))
                case 'this'
                    exportOnePDF(app, selected);
                case 'all'
                    exportAllPDFs(app, fileReports);
            end
        end

        function reports = renderableReports(~, allEntries)
        % The report structs that exportFileReportPDF can actually render.
        % collectReportStructs already drops the synthetic Summary/Dashboard
        % rows; inputFile is what names the output file.
            reports = collectReportStructs(allEntries);
            keep    = cellfun(@(r) isstruct(r) && isfield(r, 'inputFile'), reports);
            reports = reports(keep);
        end

        function r = selectedFileReport(app, allEntries)
        % The report struct behind the selected listbox row, or empty when the
        % selection is a synthetic row (Session Summary / Quality Dashboard),
        % which has nothing to render. Those rows sort after the real ones, so
        % the plain bounds check rejects them.
            r   = [];
            idx = app.ReportsListBox.Value;
            if isempty(idx) || ~isnumeric(idx) || idx < 1 || idx > numel(allEntries)
                return
            end
            candidate = allEntries{idx};
            if ~isfield(candidate, 'report') || ~isstruct(candidate.report) ...
                    || ~isfield(candidate.report, 'inputFile')
                return
            end
            r = candidate.report;
        end

        function choice = askPdfScope(app, selected, nAll)
        % Ask what to export. With no single report selected the only real
        % option is "all", so do not offer a "this report" button that would
        % have nothing to act on.
            if isempty(selected)
                msg = sprintf(['No single file report is selected - the Summary and ' ...
                    'Dashboard rows cannot be rendered on their own.\n\n' ...
                    'Export all %d file report(s)?'], nAll);
                options = {'All reports', 'Cancel'};
            else
                [~, baseName] = fileparts(selected.inputFile);
                msg = sprintf(['Export a PDF for "%s" only, or for all %d listed ' ...
                    'file report(s)?'], baseName, nAll);
                options = {'This report', 'All reports', 'Cancel'};
            end
            answer = uiconfirm(app.UIFigure, msg, 'Export PDF', ...
                'Options', options, ...
                'DefaultOption', 1, 'CancelOption', numel(options));
            switch answer
                case 'This report', choice = 'this';
                case 'All reports', choice = 'all';
                otherwise,          choice = 'cancel';
            end
        end

        function exportOnePDF(app, report)
        % One report, to a filename the user picks.
            [~, baseName] = fileparts(report.inputFile);
            [fname, fpath] = uiputfile('*.pdf', 'Export Report as PDF', ...
                [baseName, '_report.pdf']);
            if isequal(fname, 0); return; end
            try
                exportFileReportPDF(report, fullfile(fpath, fname));
                app.ReportsStatusLabel.Text = sprintf('PDF saved: %s', fname);
            catch err
                uialert(app.UIFigure, ...
                    sprintf('PDF export failed: %s', err.message), ...
                    'Export PDF', 'Icon', 'error');
            end
        end

        function exportAllPDFs(app, reports)
        % Every listed report into one folder, each named after its input
        % file. One report failing must not cost the user the rest, so
        % failures are collected and reported together at the end.
            folder = uigetdir('', 'Choose a folder for the PDF reports');
            if isequal(folder, 0); return; end

            nOk         = 0;
            failedNames = {};
            dlg = uiprogressdlg(app.UIFigure, 'Title', 'Export PDF', ...
                'Message', 'Rendering reports...', 'Indeterminate', 'off');
            cleanup = onCleanup(@() delete(dlg));
            for k = 1:numel(reports)
                [~, baseName] = fileparts(reports{k}.inputFile);
                dlg.Value   = k / numel(reports);
                dlg.Message = sprintf('Rendering %d of %d: %s', ...
                    k, numel(reports), baseName);
                try
                    exportFileReportPDF(reports{k}, ...
                        fullfile(folder, [baseName, '_report.pdf']));
                    nOk = nOk + 1;
                catch err
                    failedNames{end+1} = sprintf('%s (%s)', baseName, err.message); %#ok<AGROW>
                end
            end

            app.ReportsStatusLabel.Text = sprintf('%d PDF(s) saved to %s', nOk, folder);
            if ~isempty(failedNames)
                uialert(app.UIFigure, sprintf( ...
                    '%d report(s) could not be rendered:\n\n%s', ...
                    numel(failedNames), strjoin(failedNames, newline)), ...
                    'Export PDF', 'Icon', 'warning');
            end
        end

        function CopyMethodsButtonPushed(app, ~)
        % Copy a methods paragraph to the clipboard. A single file report copies
        % that file's full narrative; the Session Summary / Dashboard copies the
        % cross-file aggregate (mean +/- SD). Shares the same builders the text
        % reports use (methodsNarrative / methodsParagraphAggregate).
            idx = app.ReportsListBox.Value;
            if isempty(idx); return; end
            allEntries = [app.allPipelineReports, app.loadedReports];
            if ~isnumeric(idx) || idx < 1 || idx > numel(allEntries); return; end
            e = allEntries{idx};

            if isfield(e, 'report') && isstruct(e.report) && ~isempty(e.report)
                methodsText = methodsNarrative(e.report);
            else
                % Summary / Dashboard entry: aggregate over every per-file report.
                reportStructs = {};
                for k = 1:numel(allEntries)
                    ek = allEntries{k};
                    if (isfield(ek, 'isSummary')   && ek.isSummary)   ...
                            || (isfield(ek, 'isDashboard') && ek.isDashboard)
                        continue
                    end
                    if isfield(ek, 'report') && isstruct(ek.report) && ~isempty(ek.report)
                        reportStructs{end+1} = ek.report; %#ok<AGROW>
                    end
                end
                if isempty(reportStructs)
                    methodsText = 'TMS-EEG data were preprocessed using nestapp.';
                else
                    methodsText = methodsParagraphAggregate(reportStructs);
                end
            end

            clipboard('copy', methodsText);
            app.ReportsStatusLabel.Text = 'Methods text copied to clipboard.';
        end

        function showAbout(app)
        % SHOWABOUT  Display version and citation information.
            eeglabVer = '';
            if ~isempty(which('eeg_getversion'))
                try
                    eeglabVer = eeg_getversion();
                catch
                end
            end
            msg = sprintf([ ...
                'nestapp - TMS-EEG Processing\n\n' ...
                'nestapp: %s\n' ...
                'EEGLAB:  %s\n' ...
                'MATLAB:  %s\n\n' ...
                'Please cite:\n' ...
                'Rogasch et al. (2017) NeuroImage - TESA toolbox\n' ...
                'Delorme & Makeig (2004) J Neurosci Methods - EEGLAB'], ...
                nestappVersion(), eeglabVer, version);
            uialert(app.UIFigure, msg, 'About nestapp', 'Icon', 'info');
        end

        rescaleComponents(app, sX, sY)

        function styleParamTable(app)
        % Grey out UITable rows whose Value is a placeholder or literal '[]'.
        % Placeholders start with '(' by convention (e.g. '(all channels)').
        % Works with both cell array data (new format) and table (legacy).
            removeStyle(app.UITable);
            T = app.UITable.Data;
            if isempty(T); return; end
            grey = uistyle('FontColor', [0.6 0.6 0.6], 'FontAngle', 'italic');
            if iscell(T)
                nRows = size(T, 1);
                for row = 1:nRows
                    v = T{row, 2};
                    if isscalar(v) && (isstring(v) || ischar(v))
                        sv = string(v);
                        if (strlength(sv) > 0 && startsWith(sv, '(')) || strcmp(sv, '[]')
                            addStyle(app.UITable, grey, 'cell', [row, 2]);
                        end
                    end
                end
            elseif istable(T)
                for row = 1:height(T)
                    v = T.val{row};
                    if isscalar(v) && (isstring(v) || ischar(v))
                        sv = string(v);
                        if (strlength(sv) > 0 && startsWith(sv, '(')) || strcmp(sv, '[]')
                            addStyle(app.UITable, grey, 'cell', [row, 2]);
                        end
                    end
                end
            end
        end

        function s = formatParamForDisplay(~, val, paramMeta)
        % FORMATPARAMFORDISPLAY  Render a typed param value as a display string.
        %   val: typed value from spec.params.(key)
        %   paramMeta: params struct entry from stepRegistry (has .placeholder, .type)
            if isempty(val)
                if ~isempty(paramMeta.placeholder)
                    s = paramMeta.placeholder;
                else
                    s = '(not set)';
                end
            elseif ischar(val) && ~isrow(val)
                s = [deblank(val(1,:)), ' ...'];   % char matrix - show first line
            elseif ischar(val) || isstring(val)
                s = char(val);
            elseif iscell(val)
                s = strjoin(cellfun(@char, val, 'UniformOutput', false), ', ');
            else
                s = mat2str(val);
            end
        end

        function LoadSelecEEGdata(app)
            % The Visualizing tab can be used without ever running a pipeline,
            % so do not assume anything upstream has initialised EEGLAB.
            [ok, msg] = ensureEeglabReady();
            if ~ok
                error('nestapp:eeglabUnavailable', '%s', msg);
            end
            for nfile = 1:numel(app.SelectedFilesforTEP)
                % SelectedFilesforTEP holds full paths; split for pop_loadset
                % so files from different folders all load correctly.
                [fp, nm, ex] = fileparts(app.SelectedFilesforTEP{nfile});
                EEGaux = pop_loadset('filename', [nm ex], 'filepath', fp);
                app.EEGofAllSelectedFiles{nfile} = EEGaux;
                app.EEGtime = EEGaux.times;
            end
            app.EEG_SelectedTEPFiles_Loaded = true;
        end

        function LoadLabels(app)
            all_labels = cell(1,numel(app.SelectedFilesforTEP));
            if ~app.EEG_SelectedTEPFiles_Loaded
                LoadSelecEEGdata(app)
            end
            for nn=1:numel(app.SelectedFilesforTEP)
                EEG = app.EEGofAllSelectedFiles{nn};
                all_labels{nn} = {EEG.chanlocs.labels};
            end
            % Availability = electrode present (case-insensitively) in EVERY
            % selected file. See electrodeAvailability for the pure, unit-tested
            % core. Common_Labels holds the canonical button labels for the
            % available electrodes; findTEPelecs and the topoplot read it. Using
            % elecList(isAvail) keeps the canonical case (e.g. 'FP1') even when a
            % file spells it 'Fp1', so a clicked button maps back to its channel.
            isAvail = electrodeAvailability(app.elecList, all_labels);
            app.Common_Labels.Items = app.elecList(isAvail);
            % Enable an electrode button only when that electrode is available;
            % disable (and untick) the rest. The state is applied EXHAUSTIVELY
            % every call - both 'on' and 'off' - so a button greyed out for a
            % previous file selection is re-enabled when a later dataset (e.g.
            % one with all channels re-interpolated) once again contains it.
            % Previously only 'off' was ever set, so stale disabled buttons
            % persisted.
            for nn = 1:numel(app.elecList)
                propName = [upper(app.elecList{nn}), 'Button'];
                if ~isprop(app, propName)
                    continue
                end
                if isAvail(nn)
                    app.(propName).Enable = 'on';
                else
                    app.(propName).Enable = 'off';
                    app.(propName).Value  = 0;
                end
            end
        end
        
        function findTEPelecs(app)
            mm = 0; % Selected TEP elecs Counter
            app.ROIelecsLabels = []; % Stores the ROI elecs
            if app.DontfindcommonelectrodesCheckBox.Value
                for nn = 1:length(app.elecList)
                    if app.([upper(app.elecList{nn}),'Button']).Value
                        mm = mm+1;
                        app.ROIelecsLabels{mm} = app.elecList{nn};
                    end
                end
            else
                for nn = 1:length(app.Common_Labels.Items)
                    if app.([upper(app.Common_Labels.Items{nn}),'Button']).Value
                        mm = mm+1;
                        app.ROIelecsLabels{mm} = app.Common_Labels.Items{nn};
                    end
                end
            end
        end
        
        function ptype = currentPlotType(app)
        % CURRENTPLOTTYPE  Active Visualizing-tab curve: 'TEP', 'GMFP' or 'LMFP'.
        %   Falls back to 'TEP' when the Plot Type selector is absent (older
        %   layouts) or has no selection.
            ptype = 'TEP';
            if isprop(app, 'PlotTypeButtonGroup') && ~isempty(app.PlotTypeButtonGroup) ...
                    && isvalid(app.PlotTypeButtonGroup) ...
                    && ~isempty(app.PlotTypeButtonGroup.SelectedObject)
                ptype = app.PlotTypeButtonGroup.SelectedObject.Text;
            end
        end

        function plotTEP(app)
            if ~app.EEG_SelectedTEPFiles_Loaded
                LoadSelecEEGdata(app)
            end
            plotType = currentPlotType(app);
            nFiles  = numel(app.EEGofAllSelectedFiles);
            nTimes  = numel(app.EEGtime);
            % One curve per file, averaged across files below. TEP is the
            % ROI-mean waveform; GMFP/LMFP are the spatial standard deviation
            % (mean field power, Lehmann & Skrandies 1980) taken across ALL
            % channels (global) or across the ROI only (local), computed on the
            % trial-averaged data. std(...,1,...) uses the population (1/N)
            % normalisation, the conventional GMFP definition.
            curveByFile = zeros(nFiles, nTimes);
            for nfile = 1:nFiles
                EEGaux = app.EEGofAllSelectedFiles{1, nfile};
                ROIind = roiChannelIndex({EEGaux.chanlocs.labels}, app.ROIelecsLabels);
                curveByFile(nfile,:) = tepFieldCurve(EEGaux.data, ROIind, plotType);
            end

            app.TEP2Export = curveByFile;
            grandMean = mean(curveByFile, 1, 'omitmissing');
            TEP_ROISD = std(curveByFile, 1, 1) / sqrt(nFiles);
            co    = app.UIAxes.ColorOrder;
            meanx = smoothdata(grandMean,  'movmean', app.SMOOTH_WIN_PTS);
            sdx   = smoothdata(TEP_ROISD, 'movmean', app.SMOOTH_WIN_PTS);
            xf = [app.EEGtime(1) app.EEGtime  app.EEGtime(end) app.EEGtime(end:-1:1)];
            yf = [meanx(1)-sdx(1)/2 meanx+sdx/2 meanx(end)-sdx(end)/2 meanx(end:-1:1)-sdx(end:-1:1)/2];

            % Legend label: base filename of first selected file
            if iscell(app.SelectedFilesforTEP) && ~isempty(app.SelectedFilesforTEP)
                [~, dispName, ~] = fileparts(app.SelectedFilesforTEP{1});
            else
                dispName = 'TEP';
            end

            if app.NewFigureButton.Value
                cla(app.UIAxes, 'reset');
                Colr = co(1, :);
                hold(app.UIAxes, 'on');
                fill(app.UIAxes, xf, yf, Colr, 'FaceAlpha', 0.5, 'LineStyle', 'none', 'HandleVisibility', 'off');
                plot(app.UIAxes, app.EEGtime, meanx, 'Color', Colr, 'LineWidth', 2, 'DisplayName', dispName);
                hold(app.UIAxes, 'off');
                xlim(app.UIAxes, app.DefaulTEPxLim);
            elseif app.AddtocurrentFigureButton.Value
                % Only count main TEP lines (HandleVisibility='on') to determine next color.
                mainLines = findobj(app.UIAxes, 'Type', 'Line', 'HandleVisibility', 'on');
                if isempty(mainLines)
                    usedColors = zeros(0, 3);
                else
                    usedColors = reshape([mainLines.Color], 3, [])';
                end
                Colr = co(1, :);
                for k = 1:size(co, 1)
                    candidate = co(k, :);
                    if ~any(all(abs(usedColors - candidate) < 1e-6, 2))
                        Colr = candidate;
                        break;
                    end
                end
                prevYLim = ylim(app.UIAxes);
                hold(app.UIAxes, 'on');
                fill(app.UIAxes, xf, yf, Colr, 'FaceAlpha', 0.5, 'LineStyle', 'none', 'HandleVisibility', 'off');
                plot(app.UIAxes, app.EEGtime, meanx, 'Color', Colr, 'LineWidth', 2, 'DisplayName', dispName);
                xlim(app.UIAxes, app.DefaulTEPxLim);
                % Expand y-axis to accommodate new data; never shrink existing range
                newYLim = ylim(app.UIAxes);
                ylim(app.UIAxes, [min(prevYLim(1), newYLim(1)), max(prevYLim(2), newYLim(2))]);
            end

            % Self-describe the axis for the active curve. cla(...,'reset') on
            % the New Figure path wipes the labels created in createComponents,
            % so (re)apply title/labels on every plot.
            switch plotType
                case 'GMFP'
                    title(app.UIAxes,  'Global Mean Field Power');
                    ylabel(app.UIAxes, 'GMFP (\muV)');
                case 'LMFP'
                    title(app.UIAxes,  'Local Mean Field Power');
                    ylabel(app.UIAxes, 'LMFP (\muV)');
                otherwise
                    title(app.UIAxes,  'TMS Evoked Potential');
                    ylabel(app.UIAxes, 'TEP (\muV)');
            end
            xlabel(app.UIAxes, 'Time (ms)');

            legend(app.UIAxes, 'show', 'Location', 'best');

            % Remember the displayed curve so the Analysis tab can measure it.
            app.TEPDisplayCurve = meanx;
            if ~strcmp(plotType, 'TEP')
                app.tepPeaks = [];
            end

            % Fill the Analysis windows table. For TEP this also (re)detects the
            % component peaks on the displayed curve, which the overlay reuses,
            % so the table and the plot stay in agreement.
            refreshAnalysisWindows(app);

            % "Show Components" overlays the signed TEP component peaks; that is
            % meaningful only for TEP (GMFP/LMFP are positive-only mean-field
            % power, with no signed peaks).
            if strcmp(plotType, 'TEP') && app.ShowComponentsButton.Value
                if isempty(app.tepPeaks)
                    uialert(app.UIFigure, ...
                        ['TESA not found. Add TESA to the MATLAB path to enable ' ...
                         'the component overlay (Show Components).'], 'TESA Required');
                    app.ShowComponentsButton.Value = false;
                else
                    overlayTEPComponents(app);
                end
            end
        end

        function EEG_topoplot(app)
        % Render the scalp topography into the in-app axes. The computation
        % (topoScalpData) and the drawing (drawScalpTopo) are split so the
        % pop-out figure can reuse both without duplicating either.
            [values, chanLocs] = topoScalpData(app);
            drawScalpTopo(app.UIAxes2, values, chanLocs);
        end

        function [values, chanLocs] = topoScalpData(app)
        % Time-window-averaged scalp values (uV) over the electrodes common to
        % every selected file, plus their locations.
            SMOOTH_METHOD = 'movmean';
            if ~app.EEG_SelectedTEPFiles_Loaded
                LoadSelecEEGdata(app)
            end
            LoadLabels(app);
            BIGEEG = zeros(numel(app.Common_Labels.Items), length(app.EEGtime),numel(app.EEGofAllSelectedFiles));
            for nfile = 1:numel(app.EEGofAllSelectedFiles)
                EEGaux = app.EEGofAllSelectedFiles{1,nfile};
                chanLocs = EEGaux.chanlocs;
                commonElectrodsInd = ismember(lower({chanLocs.labels}),lower(app.Common_Labels.Items));
                BIGEEG(:,:,nfile) = mean(EEGaux.data(commonElectrodsInd,:,:),3,"omitmissing");
            end
            chanLocs(~commonElectrodsInd) = [];
            yp = smoothdata(mean(BIGEEG,3,"omitmissing")',SMOOTH_METHOD,app.SMOOTH_WIN_PTS)'; % Smooth the EEGdata along subjects

            % Averaging window around the requested latency. Nearest sample,
            % not exact equality: any latency that is not exactly on a sample
            % (a non-integer sampling interval, or an odd window width) used to
            % yield an empty index and error out downstream.
            halfWin   = app.WindowsizefortimeaveragedTopoplotEditField.Value / 2;
            timepoint = app.TopoplottimeSpinner.Value;
            [~, firstIdx] = min(abs(app.EEGtime - (timepoint - halfWin)));
            [~, lastIdx]  = min(abs(app.EEGtime - (timepoint + halfWin)));
            values    = mean(yp(:, min(firstIdx,lastIdx):max(firstIdx,lastIdx)), 2, "omitmissing");
        end

        
        function tf = isFileSelected(app)
            tf = ~isempty(app.SelectedFilesforTEP);
        end

        function overlayTEPComponents(app)
        % Draw dashed vertical lines and text labels for each detected TEP
        % component. Re-callable: any previous overlay is cleared first, so it
        % can be redrawn after the windows are edited. Reads app.tepPeaks.
            ax = app.UIAxes;
            delete(findobj(ax, 'Tag', 'tepCompOverlay'));
            if isempty(app.tepPeaks)
                return
            end
            yLims = ylim(ax);
            % Place labels near the top of the axes (80% height)
            labelY = yLims(1) + 0.80 * (yLims(2) - yLims(1));
            hold(ax, 'on');
            for i = 1:numel(app.tepPeaks)
                pk = app.tepPeaks(i);
                if ~pk.found
                    continue
                end
                xline(ax, pk.latencyMs, '--', 'Color', [0.4 0.4 0.4], ...
                    'LineWidth', 1, 'HandleVisibility', 'off', 'Tag', 'tepCompOverlay');
                text(ax, pk.latencyMs, labelY, ...
                    sprintf('%s\n%.0f ms\n%.1f uV', pk.name, pk.latencyMs, pk.amplitudeUV), ...
                    'FontSize', 7, 'HorizontalAlignment', 'center', ...
                    'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'top', 'Tag', 'tepCompOverlay');
            end
            hold(ax, 'off');
        end

        function refreshAnalysisWindows(app)
        % REFRESHANALYSISWINDOWS  Fill the Windows-of-Interest table for the
        %   currently displayed curve. Mode-aware: every mode shows the window
        %   Mean; TEP adds the component peak latency/amplitude detected by the
        %   SAME tepPeakFinder that draws the on-plot overlay - so the table and
        %   the graph agree, including showing '-' where no peak was found. GMFP
        %   and LMFP add the window's area under the curve instead.
            defs  = app.tepComponentDefs;
            mode  = currentPlotType(app);
            isTEP = strcmp(mode, 'TEP');
            haveCurve = ~isempty(app.TEPDisplayCurve) && ~isempty(app.EEGtime);

            % For TEP, (re)detect component peaks on the displayed curve so the
            % table tracks the overlay and updates when windows are edited.
            if isTEP && haveCurve
                try
                    app.tepPeaks = tepPeakFinder(app.TEPDisplayCurve, app.EEGtime, defs);
                catch ME
                    if strcmp(ME.identifier, 'tepPeakFinder:noTESA')
                        app.tepPeaks = [];
                    else
                        rethrow(ME);
                    end
                end
            end

            if isTEP
                app.TEPComponentTable.ColumnName    = {'Window','T1 (ms)','T2 (ms)','Mean (uV)','Peak (ms)','Peak (uV)'};
                app.TEPComponentTable.ColumnEditable = [true true true false false false];
                app.TEPComponentTable.ColumnWidth   = {70, 55, 55, 75, 70, 70};
                nCol = 6;
            else
                % GMFP/LMFP: mean plus area under the curve (cumulative field power).
                app.TEPComponentTable.ColumnName    = {'Window','T1 (ms)','T2 (ms)',[mode ' Mean (uV)'],'AUC (uV*ms)'};
                app.TEPComponentTable.ColumnEditable = [true true true false false];
                app.TEPComponentTable.ColumnWidth   = {70, 55, 55, 90, 95};
                nCol = 5;
            end

            n = numel(defs);
            data = cell(n, nCol);
            hasPeaks = isTEP && numel(app.tepPeaks) == n;
            for i = 1:n
                data{i,1} = defs(i).name;
                data{i,2} = defs(i).winStart;
                data{i,3} = defs(i).winEnd;
                m = struct('mean', NaN, 'area', NaN);
                if haveCurve
                    m = computeWindowMeasures(app.TEPDisplayCurve, app.EEGtime, ...
                        defs(i).winStart, defs(i).winEnd, windowPolarity(defs(i)));
                end
                data{i,4} = numOrDash(app, m.mean);
                if isTEP
                    % Peak from the overlay's detector, so table and plot match
                    % (and show '-' for components it did not find).
                    if hasPeaks && app.tepPeaks(i).found
                        data{i,5} = round(app.tepPeaks(i).latencyMs, 2);
                        data{i,6} = round(app.tepPeaks(i).amplitudeUV, 2);
                    else
                        data{i,5} = '-';
                        data{i,6} = '-';
                    end
                else
                    data{i,5} = numOrDash(app, m.area);
                end
            end
            app.TEPComponentTable.Data = data;
        end

        function afterWindowsChanged(app)
        % Re-measure the windows after the list changed and, for a shown TEP,
        % redraw the component overlay so the table and the plot stay consistent.
            refreshAnalysisWindows(app);
            if app.TEPCreated && strcmp(currentPlotType(app), 'TEP') && app.ShowComponentsButton.Value
                overlayTEPComponents(app);
            end
        end

        function s = numOrDash(~, v)
        % Format a measure for the WOI table: 2-dp number, or '-' when NaN.
            if isempty(v) || isnan(v)
                s = '-';
            else
                s = round(v, 2);
            end
        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Apply tooltips to controls that are not self-explanatory.
        % Called once from startupFcn. Add new tooltips here as needed.
        function applyTooltips(app)
            % Pipeline builder
            app.AddButton.Tooltip           = 'Add the selected step to the pipeline';
            app.RemoveButton.Tooltip        = 'Remove the selected step from the pipeline';
            app.MoveUpButton.Tooltip        = 'Move the selected step earlier in the pipeline';
            app.MoveDownButton.Tooltip      = 'Move the selected step later in the pipeline';
            app.DefaultValueButton.Tooltip  = 'Reset the selected parameter to its default value';
            app.ReStartStepsButton.Tooltip  = ['Resume processing from the current step index. ' ...
                'Increment the step counter manually to skip steps, or reset to 1 to reprocess from the start.'];
            app.RunAnalysisButton.Tooltip   = 'Run the pipeline on the selected data file(s)';
            app.SelectDataButton.Tooltip    = 'Select a folder or individual files to process';

            % Visualizing tab
            app.PLOTTEPButton.Tooltip         = 'Plot TMS-evoked potential waveforms for the selected files and electrodes';
            app.ShowComponentsButton.Tooltip          = 'Detect and overlay TEP component peaks on the TEP plot';
            app.AddWindowButton.Tooltip    = 'Add a new window of interest to the Analysis table';
            app.RemoveWindowButton.Tooltip = 'Remove the selected window of interest';
            app.ResetWindowsButton.Tooltip = 'Restore the default TEP component windows (Beck et al. 2024)';
            app.TOPOPLOTButton.Tooltip        = 'Plot a scalp topographic map at the specified time point';
            app.ExportTEPFigureButton.Tooltip = 'Export the current TEP plot as PNG, PDF or MATLAB figure';
            app.OpenTEPFigureButton.Tooltip   = 'Open the TEP plot in a standard MATLAB figure for hand editing';
            app.OpenTopoFigureButton.Tooltip  = 'Open the topoplot in a standard MATLAB figure for hand editing';
            app.ReLoadAvailableElectrodesButton.Tooltip = ...
                'Reload the electrode list from the currently selected files';
            app.SelectAllCheckBox.Tooltip   = 'Select all available files for TEP plotting';
            app.UseCurrentlyCleanedDataCheckBox.Tooltip = ...
                'Use the most recently processed output instead of selecting files manually';
            app.DontfindcommonelectrodesCheckBox.Tooltip = ...
                ['When checked: show all selected electrodes regardless of whether they ' ...
                'appear in every file. When unchecked: restrict to electrodes present across all selected files.'];
        end

        % Code that executes after component creation
        function startupFcn(app)
            clc
            % Order matters. The picker asks which() what is installed, and
            % nothing EEGLAB provides - including every plugin - resolves until
            % eeglab() has run its path setup and plugin scan. So prefs (which
            % is where the EEGLAB folder is recorded) and EEGLAB itself have to
            % come up BEFORE the tree is built; otherwise a cold MATLAB hides
            % most of the registry as "not installed". See ensureEeglabReady.
            loadPrefs(app);
            initEeglab(app);
            % Fill the stage-grouped step-picker tree and the name->info map it
            % reads on selection. Both are built from availableSteps, so what is
            % offered here is exactly what the pre-flight will accept.
            populateStepsTree(app);

            app.spec = repmat(struct('name','','params',struct()), 0, 1);
            app.SelectedListBox.Items(:) = [];
            app.SelectedListBox.ItemsData(:) = [];
            app.UITable.Data = [];
            app.ItemNum = 1;
            % Snapshot base geometry before originalSize so the resize handler
            % (guarded on originalSize) always has it. Components are still at
            % their createComponents positions here (no resize has scaled them).
            app.baseLayout        = captureBaseLayout(app);
            app.originalSize      = app.UIFigure.Position(3:4);
            app.tepComponentDefs  = defaultTEPComponentDefs();
            refreshAnalysisWindows(app);   % show the default windows up-front
            initExploreTab(app);
            applyTooltips(app);
            % Dwell timer for the Steps tree legend. StartDelay is restarted by
            % every mouse move, so the tip appears only after the pointer has
            % been still this long.
            HOVER_DELAY = 3;
            app.hoverTimer = timer( ...
                'StartDelay',    HOVER_DELAY, ...
                'ExecutionMode', 'singleShot', ...
                'BusyMode',      'drop', ...
                'Name',          'nestappStepsHover', ...
                'TimerFcn',      @(~,~) showStepsTip(app));
            buildRecentFilesMenu(app);
            buildRecentPipelinesMenu(app);
            updateStatusBar(app);
            clc
        end


        % ── Explore tab ──────────────────────────────────────────────────
        function initExploreTab(app)
        % Fill the controls that do not depend on data: the plot catalogue, the
        % ROI presets, and the default windows.
            app.exploreWindows = defaultTEPComponentDefs();
            app.exploreRoi     = firstRoiPreset();
            refreshExploreRoi(app);
            refreshExploreWindows(app);
            refreshExplorePlots(app);
            refreshExploreGroups(app);
        end

        function refreshExplorePlots(app)
        % The picker is generated from the registry, so a new plot appears here
        % without touching the tab. Unavailable entries are LISTED with their
        % reason rather than hidden - the user is usually one group away from
        % them, and a feature that vanishes looks like a feature that is missing.
            ctx = struct('nGroups', numel(exploreGroupNames(app)), ...
                         'hasWindows', ~isempty(app.exploreWindows), ...
                         'hasChanlocs', exploreHasChanlocs(app));
            [entries, cats] = availablePlots(ctx);
            items = {}; data = {};
            for c = 1:numel(cats)
                for k = 1:numel(cats(c).entries)
                    e = cats(c).entries(k);
                    label = sprintf('%s  -  %s', cats(c).name, e.name);
                    if ~e.available
                        label = sprintf('%s   (%s)', label, e.reason);
                    end
                    items{end+1} = label; %#ok<AGROW>
                    data{end+1}  = e.name; %#ok<AGROW>
                end
            end
            keep = app.ExplorePlotDropDown.Value;
            app.ExplorePlotDropDown.Items     = items;
            app.ExplorePlotDropDown.ItemsData = data;
            if ~isempty(data)
                if ismember(keep, data)
                    app.ExplorePlotDropDown.Value = keep;
                else
                    app.ExplorePlotDropDown.Value = data{1};
                end
            end
            app.exploreAvailablePlots = entries;
        end

        function names = exploreGroupNames(app)
            names = {};
            if isempty(app.exploreEntries); return; end
            g = {app.exploreEntries.group};
            names = unique(g(~cellfun(@isempty, g)), 'stable');
        end

        function tf = exploreHasChanlocs(app)
            tf = false;
            ok = app.exploreCache;
            if isempty(ok); return; end
            for i = 1:numel(ok)
                if ok(i).ok && ~isempty(ok(i).chanlocs) && ...
                        isfield(ok(i).chanlocs, 'theta')
                    tf = true; return
                end
            end
        end

        function refreshExploreGroups(app)
            % datasetSummary returns the per-group array FIRST and the overall
            % totals second; reading groups off the totals silently produced an
            % empty list.
            groups = datasetSummary(app.exploreEntries);
            items = cell(1, numel(groups));
            data  = cell(1, numel(groups));
            for g = 1:numel(groups)
                % Show the n the ESTIMATE rests on, not the n assigned. Files on
                % a different cap are excluded by groupCurves, so the assigned
                % count can be higher - and the rail showing 16 beside a legend
                % showing 15 is how a user stops trusting either number.
                used = usedSubjectCount(app, groups(g).name);
                if isnan(used) || used == groups(g).nSubjects
                    items{g} = sprintf('%s   (n=%d subj, %d files)', ...
                        groups(g).name, groups(g).nSubjects, groups(g).nFiles);
                else
                    items{g} = sprintf('%s   (n=%d of %d subj, %d files)', ...
                        groups(g).name, used, groups(g).nSubjects, groups(g).nFiles);
                end
                data{g}  = groups(g).name;
            end
            app.ExploreGroupsListBox.Items     = items;
            app.ExploreGroupsListBox.ItemsData = data;
            app.ExploreRemoveGroupButton.Enable = onOffState(~isempty(data));
            hasData = ~isempty(data);
            app.ExploreFigureButton.Enable  = onOffState(hasData);
            app.ExploreCsvButton.Enable     = onOffState(hasData);
            app.ExploreResultsButton.Enable = onOffState(hasData);
            app.ExploreEmptyLabel.Visible   = onOffState(~hasData);
        end

        function n = usedSubjectCount(app, name)
        % Subjects behind the drawn estimate for this group, or NaN when there
        % is no result yet to ask.
            n = NaN;
            if isempty(app.exploreRes) || isempty(app.exploreRes.groups); return; end
            k = find(strcmp({app.exploreRes.groups.name}, name), 1);
            if ~isempty(k); n = app.exploreRes.est(k).n; end
        end

        function refreshExploreRoi(app)
            p = roiPresets();
            app.ExploreRoiDropDown.Items     = [{'(custom)'}, {p.name}];
            app.ExploreRoiDropDown.ItemsData = [{''}, {p.name}];
            match = '';
            for i = 1:numel(p)
                if isequal(sort(lower(p(i).labels)), sort(lower(app.exploreRoi)))
                    match = p(i).name; break
                end
            end
            app.ExploreRoiDropDown.Value = match;
            n = numel(app.exploreRoi);
            if n == 0
                app.ExploreRoiSummaryLabel.Text = 'No electrodes selected';
            else
                app.ExploreRoiSummaryLabel.Text = sprintf('%d electrode%s: %s', ...
                    n, plural(n), strjoin(app.exploreRoi, ' '));
            end
        end

        function refreshExploreWindows(app)
            w = app.exploreWindows;
            data = cell(numel(w), 3);
            for i = 1:numel(w)
                data(i, :) = {w(i).name, w(i).winStart, w(i).winEnd};
            end
            app.ExploreWindowsTable.Data = data;
        end

        function recomputeExplore(app)
        % One path from state to picture. Everything the rail changes lands
        % here, and it re-runs groupCurves rather than patching a cached
        % result - the whole point of caching trial averages is that this is
        % arithmetic on a few MB, so there is no stale-state class of bug.
            app.exploreRes = struct([]);
            if isempty(exploreGroupNames(app))
                refreshExploreGroups(app);
                renderExplorePlot(app);
                return
            end
            % Availability depends on the group count, so the catalogue has to
            % be re-evaluated whenever the group set changes - otherwise every
            % plot stays marked with the count it had when the tab was built and
            % rendering refuses to draw.
            refreshExplorePlots(app);
            entry = currentPlotEntry(app);
            mode = 'TEP';
            if ~isempty(entry) && ~isempty(entry.mode); mode = entry.mode; end
            try
                app.exploreRes = groupCurves(app.exploreCache, app.exploreEntries, ...
                    struct('roi', {app.exploreRoi}, 'mode', mode, ...
                           'design', exploreDesign(app), 'level', 0.95));
            catch ME
                app.ExploreStatusLabel.Text = ME.message;
                app.exploreRes = struct([]);
            end
            refreshExploreGroups(app);
            renderExplorePlot(app);
        end

        function d = exploreDesign(app)
        % Paired when every group holds the same subjects, unpaired otherwise.
        % Inferred rather than asked: the answer is already in the data, and a
        % control for it is a control the user can set wrongly.
            d = 'unpaired';
            [~, overall] = datasetSummary(app.exploreEntries);
            names = exploreGroupNames(app);
            if numel(names) >= 2 && overall.nComplete == overall.nSubjects ...
                    && overall.nComplete > 0
                d = 'paired';
            end
        end

        function entry = currentPlotEntry(app)
            entry = [];
            if isempty(app.exploreAvailablePlots); return; end
            k = find(strcmp({app.exploreAvailablePlots.name}, ...
                            app.ExplorePlotDropDown.Value), 1);
            if ~isempty(k); entry = app.exploreAvailablePlots(k); end
        end

        function renderExplorePlot(app)
        % Clear the canvas and build exactly the axes the chosen plot needs.
            delete(app.ExploreCanvas.Children);
            app.ExploreEmptyLabel = uilabel(app.ExploreCanvas, ...
                'Position', [20 180 app.ExploreCanvas.Position(3) - 40 40], ...
                'HorizontalAlignment', 'center', 'FontSize', 13, ...
                'FontColor', [0.45 0.48 0.53], 'WordWrap', 'on', ...
                'Text', 'Add a group to begin. A group is a set of recordings compared as one condition - pre and post, or one cohort against another.', ...
                'Visible', 'off');

            entry = currentPlotEntry(app);
            if isempty(entry); return; end
            app.ExplorePlotInfoLabel.Text = '';

            if ~entry.available
                app.ExplorePlotInfoLabel.Text = entry.reason;
                showExploreEmpty(app, entry.reason);
                return
            end
            if isempty(app.exploreRes) || isempty(app.exploreRes.groups)
                showExploreEmpty(app, '');
                return
            end

            try
                drawExploreInto(app, app.ExploreCanvas, entry);
                app.ExploreStatusLabel.Text = exploreStatusText(app);
            catch ME
                showExploreEmpty(app, ME.message);
                app.ExploreStatusLabel.Text = ME.message;
            end
        end

        function drawExploreInto(app, parent, entry)
        % Mint the axes the plot wants inside `parent`, then hand off to the
        % registry's draw function. Shared by the in-app canvas and the
        % popped-out figure, so what is exported is what was on screen.
            res = app.exploreRes;
            pos = parent.Position;
            switch entry.draw
                case 'drawGroupTopo'
                    n = numel(res.groups);
                    axList = gobjects(1, n);
                    w = (pos(3) - 20) / max(n, 1);
                    for k = 1:n
                        axList(k) = uiaxes(parent, ...
                            'Position', [10 + (k-1)*w, 30, w - 10, pos(4) - 60]);
                    end
                    win = exploreTopoWindow(app);
                    drawGroupTopo(axList, res, struct('window', win));
                otherwise
                    ax = uiaxes(parent, 'Position', [45 45 pos(3) - 70 pos(4) - 70]);
                    fn = str2func(entry.draw);
                    fn(ax, res, struct('mode', entry.mode));
            end
        end

        function win = exploreTopoWindow(app)
        % The scalp map averages over the first window of interest, so the map
        % and the measures describe the same interval by construction.
            win = [app.exploreRes.time(1) app.exploreRes.time(end)];
            if ~isempty(app.exploreWindows)
                win = [app.exploreWindows(1).winStart app.exploreWindows(1).winEnd];
            end
        end

        function showExploreEmpty(app, msg)
            if ~isempty(msg)
                app.ExploreEmptyLabel.Text = msg;
            end
            app.ExploreEmptyLabel.Visible = 'on';
        end

        function txt = exploreStatusText(app)
            res = app.exploreRes;
            bits = {};
            for g = 1:numel(res.groups)
                bits{end+1} = sprintf('%s n=%d', res.groups(g).name, ...
                                      res.est(g).n); %#ok<AGROW>
            end
            txt = sprintf('%s  |  %s, 95%% CI  |  %d channels', ...
                strjoin(bits, ', '), res.design, numel(res.channelLabels));
            m = res.info.montage;
            if ~isempty(m.excluded)
                txt = sprintf('%s  |  %d file%s excluded (different cap)', ...
                    txt, numel(m.excluded), plural(numel(m.excluded)));
            end
            if ~isempty(res.dropped)
                txt = sprintf('%s  |  %d subject%s without a complete set', ...
                    txt, numel(res.dropped), plural(numel(res.dropped)));
            end
        end

        % -- callbacks ------------------------------------------------------
        function ExploreAddGroupButtonPushed(app, ~)
            startFolder = getpref('nestapp', 'lastDataFolder', '');
            paths = selectDataTree(startFolder, {'*.set'});
            if isempty(paths); return; end
            if isvalid(app.UIFigure); figure(app.UIFigure); end

            answer = inputdlg('Name for this group:', 'Add group', [1 40], ...
                              {sprintf('group %d', numel(exploreGroupNames(app)) + 1)});
            if isempty(answer) || isempty(strtrim(answer{1})); return; end
            name = strtrim(answer{1});

            dlg = uiprogressdlg(app.UIFigure, 'Title', 'Adding group', ...
                'Message', sprintf('Loading %d file(s)...', numel(paths)), ...
                'Indeterminate', 'on');
            closeDlg = onCleanup(@() close(dlg));
            try
                added = exploreDataset(paths, {}, struct());
                for i = 1:numel(added); added(i).group = name; end
                [newCache, warns] = loadReducedSets(paths, struct( ...
                    'progressFcn', @(i, n, ~) 0));
                app.exploreEntries = [app.exploreEntries, added];
                app.exploreCache   = [app.exploreCache, newCache];
                if isempty(app.exploreRoi)
                    app.exploreRoi = firstRoiPreset();
                    refreshExploreRoi(app);
                end
                clear closeDlg
                if ~isempty(warns)
                    uialert(app.UIFigure, strjoin(warns, newline), ...
                        'Some files could not be loaded', 'Icon', 'warning');
                end
            catch ME
                clear closeDlg
                uialert(app.UIFigure, ME.message, 'Could not add group', ...
                        'Icon', 'error');
                return
            end
            refreshExplorePlots(app);
            recomputeExplore(app);
        end

        function ExploreRemoveGroupButtonPushed(app, ~)
            name = app.ExploreGroupsListBox.Value;
            if isempty(name); return; end
            drop = strcmp({app.exploreEntries.group}, name);
            gone = {app.exploreEntries(drop).path};
            app.exploreEntries(drop) = [];
            % Drop the cached datasets no remaining group refers to.
            keepCache = ~ismember({app.exploreCache.path}, gone);
            app.exploreCache = app.exploreCache(keepCache);
            refreshExplorePlots(app);
            recomputeExplore(app);
        end

        function ExploreRoiEditButtonPushed(app, ~)
            picked = roiPicker(app.exploreRoi, exploreAvailableElectrodes(app), ...
                struct('parent', app.UIFigure, ...
                       'availableNote', 'not on the modal cap'));
            if isempty(picked) && ~iscell(picked)
                return          % cancelled - [] rather than {}
            end
            app.exploreRoi = picked;
            refreshExploreRoi(app);
            recomputeExplore(app);
        end

        function labels = exploreAvailableElectrodes(app)
        % The modal montage of what is loaded, which is what groupCurves will
        % actually compute on - so the picker greys exactly what cannot be used.
            labels = {};
            if isempty(app.exploreRes) || ~isfield(app.exploreRes, 'channelLabels')
                ok = app.exploreCache([app.exploreCache.ok]);
                if ~isempty(ok); labels = ok(1).labels; end
                return
            end
            labels = app.exploreRes.channelLabels;
        end

        function ExploreRoiDropDownValueChanged(app, ~)
            name = app.ExploreRoiDropDown.Value;
            if isempty(name); return; end
            p = roiPresets();
            k = find(strcmp({p.name}, name), 1);
            if isempty(k); return; end
            app.exploreRoi = p(k).labels;
            refreshExploreRoi(app);
            recomputeExplore(app);
        end

        function ExplorePlotDropDownValueChanged(app, ~)
            recomputeExplore(app);
        end

        function ExploreWindowsTableCellEdit(app, event)
            r = event.Indices(1);
            c = event.Indices(2);
            if r > numel(app.exploreWindows); return; end
            switch c
                case 1, app.exploreWindows(r).name     = char(event.NewData);
                case 2, app.exploreWindows(r).winStart = event.NewData;
                case 3, app.exploreWindows(r).winEnd   = event.NewData;
            end
            refreshExploreWindows(app);
            renderExplorePlot(app);
        end

        function ExploreWindowsResetButtonPushed(app, ~)
            app.exploreWindows = defaultTEPComponentDefs();
            refreshExploreWindows(app);
            renderExplorePlot(app);
        end

        function ExploreFigureButtonPushed(app, ~)
        % A real MATLAB figure, drawn fresh rather than copied: the in-app
        % canvas is for looking, and a figure someone will edit and save wants
        % its own axes at its own size.
            if isempty(app.exploreRes); return; end
            entry = currentPlotEntry(app);
            if isempty(entry) || ~entry.available; return; end
            fig = figure('Name', sprintf('nestapp - %s', entry.name), ...
                         'NumberTitle', 'off', 'Color', 'w', ...
                         'Position', [120 120 900 520]);
            holder = uipanel(fig, 'Units', 'pixels', 'BorderType', 'none', ...
                             'Position', [0 0 900 520]);
            drawExploreInto(app, holder, entry);
        end

        function ExploreCsvButtonPushed(app, ~)
            if isempty(app.exploreRes); return; end
            T = exploreMeasures(withMode(app.exploreRes, currentMode(app)), ...
                                app.exploreWindows);
            if isempty(T) || height(T) == 0
                uialert(app.UIFigure, 'No measures to export yet.', 'Nothing to save');
                return
            end
            [f, p] = uiputfile({'*.csv', 'Comma-separated values'}, ...
                               'Save measures', 'tep_measures.csv');
            if isequal(f, 0); return; end
            writetable(T, fullfile(p, f));
            app.ExploreStatusLabel.Text = sprintf('Wrote %d rows to %s', height(T), f);
        end

        function ExploreResultsButtonPushed(app, ~)
            if isempty(app.exploreRes); return; end
            entry = currentPlotEntry(app);
            plotName = '';
            if ~isempty(entry); plotName = entry.name; end
            out = exploreResults(app.exploreRes, app.exploreEntries, struct( ...
                'roi', {app.exploreRoi}, 'windows', app.exploreWindows, ...
                'mode', currentMode(app), 'plot', plotName));

            choice = uiconfirm(app.UIFigure, ...
                ['The full result - curves at sampling rate, intervals and ' ...
                 'provenance. Save it as a .mat, or put it in the base ' ...
                 'workspace to carry on in MATLAB?'], 'Results', ...
                'Options', {'Save as .mat', 'To workspace', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
            switch choice
                case 'Save as .mat'
                    [f, p] = uiputfile({'*.mat', 'MATLAB data'}, ...
                                       'Save results', 'tep_results.mat');
                    if isequal(f, 0); return; end
                    save(fullfile(p, f), 'out');
                    app.ExploreStatusLabel.Text = sprintf('Saved results to %s', f);
                case 'To workspace'
                    assignin('base', 'tepResults', out);
                    app.ExploreStatusLabel.Text = ...
                        'Results assigned to "tepResults" in the base workspace.';
            end
        end

        function initEeglab(app)
        % INITEEGLAB  Bring EEGLAB up at launch, with feedback and a verdict.
        %   The plugin scan takes a couple of seconds and the window is already
        %   on screen by now, so it gets a progress dialog rather than a
        %   silent freeze. A failure is worth interrupting for: without EEGLAB
        %   the picker can only offer the handful of steps that need nothing,
        %   and the user would otherwise have to guess why.
            dlg = uiprogressdlg(app.UIFigure, 'Title', 'Starting nestapp', ...
                'Message', 'Initialising EEGLAB and its plugins...', ...
                'Indeterminate', 'on');
            closeDlg = onCleanup(@() close(dlg));
            [ok, msg] = ensureEeglabReady();
            if ~ok
                clear closeDlg
                uialert(app.UIFigure, msg, 'EEGLAB Not Ready', 'Icon', 'warning');
            end
        end

        % Selection changed function: StepsTree
        function StepsTreeSelectionChanged(app, ~)
            % Category and operation nodes have empty NodeData - they group, they
            % are not steps, so selecting one just clears the Info panel.
            name = selectedStepName(app);
            if isempty(name)
                app.InfoTextArea.Value = '';
            elseif isKey(app.info, name)
                app.InfoTextArea.Value = stepInfoLines(app, name);
            end
            app.selectedItem = [];
        end

        % Double-clicked callback: StepsTree
        function StepsTreeDoubleClicked(app, ~)
            % Double-clicking a step adds it; double-clicking a category/
            % operation header (empty NodeData) does nothing here and lets the
            % tree's native expand/collapse take over.
            name = selectedStepName(app);
            if isempty(name)
                return
            end
            appendStep(app, name);
        end

        % Button pushed function: AddButton
        function AddButtonPushed(app, ~)
            name = selectedStepName(app);
            if isempty(name)
                return   % a category/operation header is selected - nothing to add
            end
            appendStep(app, name);
        end

        % Button pushed function: MoveUpButton
        function MoveUpButtonPushed(app, ~)
            ind = selectedStepIndex(app);
            moveStep(app, ind, -1);
        end

        % Button pushed function: SavePipelineButton
        function SavePipelineButtonPushed(app, ~)
            startFolder = getpref('nestapp', 'lastPipelineFolder', '');
            [fName, fPath] = uiputfile('*.mat', 'Save Pipeline', ...
                fullfile(startFolder, 'pipeline.mat'));
            if isequal(fName, 0); return; end   % user cancelled
            spec         = app.spec;
            pipelineName = app.pipelineName;
            version      = '3';
            save(fullfile(fPath, fName), 'spec', 'pipelineName', 'version');
            setpref('nestapp', 'lastPipelineFolder', fPath);
            pushRecent(app, 'recentPipelines', fullfile(fPath, fName));
            [~, baseName, ~] = fileparts(fName);
            app.pipelineName  = baseName;
            app.pipelineDirty = false;
            updateStatusBar(app);
        end

        % Button pushed function: RemoveButton
        function RemoveButtonPushed(app, ~)
            ind = selectedStepIndex(app);
            removeStep(app, ind);
        end

        % Button pushed function: MoveDownButton
        function MoveDownButtonPushed(app, ~)
            ind = selectedStepIndex(app);
            moveStep(app, ind, +1);
        end

        % Button pushed function: LoadPipelineButton
        function LoadPipelineButtonPushed(app, ~)
            startFolder = getpref('nestapp', 'lastPipelineFolder', '');
            [pName, pPath] = uigetfile('*.mat', 'Load Pipeline', startFolder);
            if isequal(pName, 0); return; end
            fullPath = fullfile(pPath, pName);
            loadPipelineData(app, fullPath);
            setpref('nestapp', 'lastPipelineFolder', pPath);
            pushRecent(app, 'recentPipelines', fullPath);
            buildRecentPipelinesMenu(app);
            [~, nm, ~] = fileparts(pName);
            app.pipelineName  = nm;
            app.pipelineDirty = false;
            updateStatusBar(app);
        end

        % Button pushed function: SelectDataButton
        % Button pushed function: SelectDataButton ("Browse...")
        function SelectDataButtonPushed(app, ~)
        % SELECTDATABUTTONPUSHED  Open the data browser and queue checked files.
        %   selectDataTree shows the folder tree beneath a chosen parent as a
        %   checkbox tree with a path filter, so recordings spread across many
        %   subject folders (e.g. just the SPL files, or just session 1) can
        %   be picked in one place. Returns the full paths of every checked
        %   file; setFileQueue then adopts them as the run queue.
            startFolder = getpref('nestapp', 'lastDataFolder', '');
            paths = selectDataTree(startFolder, app.dataFileExts());
            if isempty(paths); return; end
            setFileQueue(app, paths);
            if isvalid(app.UIFigure); figure(app.UIFigure); end
        end

        function setFileQueue(app, fullPaths)
        % SETFILEQUEUE  Adopt a flat list of full file paths as the run queue.
        %   The single source of truth Run Analysis reads from. When every
        %   file shares one folder we keep app.path set and show basenames
        %   (so the TEP "use cleaned data" reuse and single-folder status
        %   bar keep working); when files span folders app.path is cleared
        %   and labels carry the parent-folder name to disambiguate.
            fullPaths = fullPaths(:)';
            if isempty(fullPaths); return; end

            [labels, uniqueParents, parents] = buildFileLabels(app, fullPaths);
            if isscalar(uniqueParents)
                app.path = uniqueParents{1};
            else
                app.path = '';   % files span folders - no single path
            end

            app.filePaths   = fullPaths;
            app.file        = labels;
            app.NSelecFiles = numel(fullPaths);
            app.SelectedFilesListBox.Items = labels;

            % Note: the "Data folder" pref (lastDataFolder) is updated by
            % selectDataTree to the browse root, not clobbered to a subfolder.
            pushRecent(app, 'recentFiles', parents{1});
            buildRecentFilesMenu(app);
            updateStatusBar(app);

            fprintf('[nestapp] Queued %d file(s) from %d folder(s).\n', ...
                numel(fullPaths), numel(uniqueParents));
        end

        function exts = dataFileExts(~)
        % DATAFILEEXTS  Glob patterns for the data formats nestapp loads.
            exts = {'*.set', '*.vhdr', '*.cdt', '*.cnt'};
        end

        function [labels, uniqueParents, parents] = buildFileLabels(~, fullPaths)
        % BUILDFILELABELS  Display labels for a flat list of full file paths.
        %   Basenames when every file shares one folder; parentFolder/basename
        %   when the list spans folders, so same-named files from different
        %   subjects stay distinguishable. Also returns the unique parent
        %   folders (callers use the count / common path) and each file's
        %   parent. Shared by the Cleaning (setFileQueue) and Visualize
        %   (setTEPFileList) tabs so the labelling rule lives in one place.
            [parents, names, exts] = cellfun(@fileparts, fullPaths, ...
                'UniformOutput', false);
            uniqueParents = unique(parents);
            labels = cell(1, numel(fullPaths));
            if isscalar(uniqueParents)
                for i = 1:numel(fullPaths)
                    labels{i} = [names{i} exts{i}];
                end
            else
                for i = 1:numel(fullPaths)
                    [~, folderName] = fileparts(parents{i});
                    labels{i}       = [folderName '/' names{i} exts{i}];
                end
            end
        end

        % Button pushed function: ReStartStepsButton
        function ReStartStepsButtonPushed(app, ~)
            confirmClear = getpref('nestapp', 'confirmClear', true);
            if confirmClear
                answer = uiconfirm(app.UIFigure, ...
                    'Clear all pipeline steps? This cannot be undone.', ...
                    'Clear Pipeline', ...
                    'Options', {'Clear', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2);
                if strcmp(answer, 'Cancel'); return; end
            end
            clc
            clearSteps(app);
        end

        % Menu selected function: Load Template...
        function LoadTemplateMenuSelected(app, ~)
        % LOADTEMPLATEMENUSELECTED  Show a template picker and load the chosen template.
        %   Reads template .mat files from src/templates/ - the same format
        %   as user-saved pipelines.  No override logic runs at runtime.
            % which('nestapp') points at the class folder
            % (src/@nestapp/nestapp.m); templates live one directory up
            % under src/templates/.
            classDir    = fileparts(which('nestapp'));
            templateDir = fullfile(fileparts(classDir), 'templates');
            files = dir(fullfile(templateDir, '*.mat'));
            if isempty(files)
                uialert(app.UIFigure, ...
                    'No template files found in src/templates/.  Run buildTemplates() to generate them.', ...
                    'Templates');
                return
            end

            % Read pipelineName from each file for the picker list.
            n     = numel(files);
            names = cell(n, 1);
            paths = cell(n, 1);
            for i = 1:n
                paths{i} = fullfile(files(i).folder, files(i).name);
                try
                    tmp = load(paths{i});
                    if isfield(tmp, 'pipelineName') && ~isempty(tmp.pipelineName)
                        names{i} = tmp.pipelineName;
                    else
                        [~, names{i}] = fileparts(files(i).name);
                    end
                catch
                    [~, names{i}] = fileparts(files(i).name);
                end
            end

            % Modal picker
            dlg = uifigure('Name', 'Load Template', ...
                'Position', [300 300 320 200], ...
                'WindowStyle', 'modal', 'Resize', 'off');
            uilabel(dlg, 'Text', 'Select a pipeline template:', ...
                'Position', [15 165 290 22]);
            lb = uilistbox(dlg, 'Items', names, ...
                'Position', [15 60 290 100], 'Value', names{1});
            uibutton(dlg, 'Text', 'Cancel', 'Position', [120 15 85 30], ...
                'ButtonPushedFcn', @(~,~) close(dlg));
            uibutton(dlg, 'Text', 'Load', 'Position', [215 15 90 30], ...
                'BackgroundColor', [0.20 0.55 0.20], 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) doLoad());
            uiwait(dlg);

            % Closing the modal picker can leave the main window buried behind
            % other apps (Chrome, etc.); raise nestapp so it isn't lost.
            if isvalid(app.UIFigure)
                figure(app.UIFigure);
            end

            function doLoad()
                idx = find(strcmp(names, lb.Value), 1);
                close(dlg);
                if isempty(idx); return; end
                clearSteps(app);
                clc
                loadPipelineData(app, paths{idx});
                app.pipelineName  = names{idx};
                app.pipelineDirty = true;
                updateStatusBar(app);
                if ~isempty(app.SelectedListBox.Items)
                    app.SelectedListBox.Value = app.SelectedListBox.ItemsData{1};
                    refreshParamTable(app, 1);
                end
                promptForRequiredParams(app);
            end
        end

        function promptForRequiredParams(app)
        % Some templates cannot carry a working default for every setting -
        % AARATEP needs an output folder and there is no reasonable guess. Ask
        % on load, with that step's parameter table already in front of the
        % user, rather than letting them start a run that fails on the first
        % file for a reason they then have to go and find.
        %
        % Which parameters are required is declared on the parameter itself
        % (makeParam(..., 'required', true)) and found by
        % unsetRequiredParams, so this does not need updating when a step
        % gains one.
            [stepIdx, ~, labels] = unsetRequiredParams(app.spec);
            if isempty(stepIdx); return; end

            % Put the offending step's parameters on screen first, so the
            % dialog is pointing at something the user can actually edit.
            if numel(app.SelectedListBox.ItemsData) >= stepIdx
                app.SelectedListBox.Value = app.SelectedListBox.ItemsData{stepIdx};
                refreshParamTable(app, stepIdx);
            end

            uialert(app.UIFigure, sprintf( ...
                ['"%s" needs these before the pipeline can run:\n\n    %s\n\n' ...
                 'Its parameters are shown below - fill them in, then Run.'], ...
                app.spec(stepIdx).name, strjoin(labels, sprintf('\n    '))), ...
                'Settings needed', 'Icon', 'info');
        end

        % Button pushed function: RunAnalysisButton
        function RunAnalysisButtonPushed(app, ~)
            app.RunAnalysisButton.Text = {'Run';'Analysis'};
            if isempty(app.file)
                uialert(app.UIFigure, 'Please select at least one data file.', '');
                return
            end
            if isempty(app.spec)
                uialert(app.UIFigure, 'Please add at least one pipeline step.', '');
                return
            end

            % Normally a no-op - startupFcn has already done this - but the
            % run is the point at which EEGLAB stops being optional, so check
            % rather than assume the session still has it.
            [ok, msg] = ensureEeglabReady();
            if ~ok
                uialert(app.UIFigure, msg, 'EEGLAB Init Failed', 'Icon', 'error');
                return
            end

            % app.filePaths holds full paths and spans folders when the
            % "Folders..." picker was used. Fall back to the single-folder
            % join for any selection made before filePaths was populated.
            if ~isempty(app.filePaths)
                filePaths = app.filePaths;
            else
                filePaths = cellfun(@(f) fullfile(app.path, f), app.file, 'UniformOutput', false);
            end

            % Pre-select channel location file once if the pipeline needs it.
            app.preSelectedChanFile = '';
            for psi = 1:numel(app.spec)
                if strcmp(app.spec(psi).name, 'Load Channel Location')
                    p = app.spec(psi).params;
                    needChan     = isfield(p, 'needchanloc') && strcmp(p.needchanloc, 'yes');
                    eachFileDiff = isfield(p, 'eachFilediffPath') && strcmp(p.eachFilediffPath, 'yes');
                    if needChan && ~eachFileDiff
                        [chName, chPath] = uigetfile('*.*', 'Select channel location file');
                        if isequal(chName, 0); return; end
                        app.preSelectedChanFile = fullfile(chPath, chName);
                    end
                    break
                end
            end

            % Steps that wait for a human cannot run on a parallel worker:
            % workers get uiFigure = [] and no display, so the run errors on
            % every file or blocks with nothing to click - and only after the
            % batch has started. Warn and offer to turn parallel off first.
            if app.ParallelCheckBox.Value
                blocking = interactivePipelineSteps(app.spec);
                if ~isempty(blocking)
                    choice = uiconfirm(app.UIFigure, sprintf([ ...
                        'This pipeline contains %d step(s) that wait for you:\n\n' ...
                        '    %s\n\n' ...
                        'They cannot run on a parallel worker, so the run would ' ...
                        'fail or hang. Turn parallel processing off and run the ' ...
                        'files one at a time?'], ...
                        numel(blocking), strjoin(blocking, sprintf('\n    '))), ...
                        'Interactive steps in pipeline', ...
                        'Options', {'Turn off parallel', 'Cancel'}, ...
                        'DefaultOption', 1, 'CancelOption', 2, 'Icon', 'warning');
                    if ~strcmp(choice, 'Turn off parallel'); return; end
                    app.ParallelCheckBox.Value = false;
                end
            end

            opts.uiFigure     = app.UIFigure;
            opts.pipelineName = app.pipelineName;
            opts.statusBar    = app.StatusBar;
            opts.parallel     = app.ParallelCheckBox.Value;
            opts.chanLocFile  = app.preSelectedChanFile;

            try
                [allReports, allSummaries, failed] = runPipelineCore(app.spec, filePaths, opts);
            catch err
                if strcmp(err.identifier, 'nestapp:cancelled')
                    return   % backed out before anything ran - nothing to say
                end
                if strcmp(err.identifier, 'nestapp:cancelledPartial')
                    % The run got far enough to write per-file reports and a
                    % partial session summary; the message names the folder.
                    uialert(app.UIFigure, err.message, 'Run Cancelled', 'Icon', 'warning');
                    return
                end
                uialert(app.UIFigure, err.message, 'Pipeline Error', 'Icon', 'error');
                return
            end

            % Keep this run's failures so the dashboard + summary can show
            % them (they have no report of their own).
            app.lastFailed = failed;

            % A single-file run gets a session summary too - the methods
            % paragraph and citations are just as useful for one file.
            if ~isempty(allReports)
                summEntry.text      = summarizeReports(allReports, failed);
                summEntry.report    = [];
                summEntry.isSummary = true;
                app.allPipelineReports{end+1} = summEntry;
            end
            for ri = 1:numel(allSummaries)
                entry.text      = allSummaries{ri};
                entry.report    = allReports{ri};
                entry.isSummary = false;
                app.allPipelineReports{end+1} = entry;
            end
            updateReportsTab(app);
            if getpref('nestapp', 'showReport', true) && ~isempty(allSummaries)
                app.TabGroup.SelectedTab = app.ReportsTab;
            end
            if app.UseCurrentlyCleanedDataCheckBox.Value
                UseCurrentlyCleanedDataCheckBoxValueChanged(app)
            end
        end

        % Value changed function: TextArea
        function TextAreaValueChanged(app, ~)
            if isempty(app.currentParamKey); return; end
            stepIdx = selectedStepIndex(app);
            if isempty(stepIdx) || stepIdx > numel(app.spec); return; end

            raw = app.TextArea.Value;
            if iscell(raw) || isstring(raw)
                raw = strjoin(raw, ' ');
            end

            val = convertParam(raw, app.currentParamType);
            app.spec(stepIdx).params.(app.currentParamKey) = val;
            refreshParamTable(app, stepIdx);
            app.pipelineDirty = true;
            updateStatusBar(app);
        end

        % Cell selection callback: UITable
        function UITableCellSelection(app, event)
            if isempty(event.Indices); return; end
            row     = event.Indices(1);
            stepIdx = selectedStepIndex(app);
            if isempty(stepIdx) || stepIdx > numel(app.spec); return; end

            reg    = stepRegistry();
            step   = app.spec(stepIdx);
            regIdx = find(strcmp({reg.name}, step.name), 1);
            if isempty(regIdx); return; end
            params = reg(regIdx).params;
            if row > numel(params); return; end

            paramMeta = params(row);
            app.currentParamKey  = paramMeta.key;
            app.currentParamType = paramMeta.type;

            val = step.params.(paramMeta.key);
            if isnumeric(val)
                app.TextArea.Value = num2str(val);
            elseif iscell(val)
                % Cell params may mix char and numeric entries (e.g. SSP-SIR
                % PC = {'data', 90}); strjoin needs char/string, so stringify
                % each element first instead of erroring on the numeric one.
                parts = cell(1, numel(val));
                for ii = 1:numel(val)
                    v = val{ii};
                    if ischar(v)
                        parts{ii} = v;
                    elseif isstring(v)
                        parts{ii} = char(v);
                    elseif isnumeric(v) || islogical(v)
                        parts{ii} = num2str(v);
                    else
                        parts{ii} = char(string(v));
                    end
                end
                app.TextArea.Value = strjoin(parts, ', ');
            elseif ischar(val) && ~isrow(val) && ~isempty(val)
                app.TextArea.Value = cellstr(val);   % char matrix -> cell for TextArea
            else
                app.TextArea.Value = char(val);
            end
        end

        % Button pushed function: DefaultValueButton
        function DefaultValueButtonPushed(app, ~)
            stepIdx = selectedStepIndex(app);
            if isempty(stepIdx) || stepIdx > numel(app.spec); return; end
            reg  = stepRegistry();
            name = app.spec(stepIdx).name;
            app.spec(stepIdx) = makePipelineStep(name, reg);
            app.currentParamKey  = '';
            app.currentParamType = '';
            app.TextArea.Value   = '';
            refreshParamTable(app, stepIdx);
            app.pipelineDirty = true;
            updateStatusBar(app);
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, ~)
            pool = gcp('nocreate');
            if ~isempty(pool)
                nestLog('PAR', 'nestapp closing - shutting down parallel pool (%d workers)', ...
                    pool.NumWorkers);
                delete(pool);
            end
            delete(app);
        end

        % Size changed function: UIFigure
        function UIFigureSizeChanged(app, ~)
            if isempty(app.originalSize); return; end
            % enforceMinWindowSize writes Position, which fires this callback
            % again - and drawnow below lets that re-entry actually run. Left
            % unguarded the two feed each other for as long as resize events
            % keep arriving.
            if app.isResizing; return; end
            app.isResizing = true;
            done = onCleanup(@() endResize(app));

            drawnow limitrate  % throttle: skip redraws that arrive faster than screen refresh
            newSize = enforceMinWindowSize(app);
            sX = newSize(1) / app.originalSize(1);
            sY = newSize(2) / app.originalSize(2);
            rescaleComponents(app, sX, sY);
            reRenderReportsOnResize(app);  % reflow the Quality Dashboard if it's showing
        end

        function endResize(app)
            app.isResizing = false;
        end

        function newSize = enforceMinWindowSize(app)
        % Grow the window back to the minimum WITHOUT moving it on screen.
        % clampWindowPosition owns the arithmetic - and the explanation of why
        % the top edge has to be pinned - so it can be tested without launching
        % the app. This method is the part that genuinely needs a figure.
            MIN_SIZE = [650 420];
            [newPos, changed] = clampWindowPosition(app.UIFigure.Position, MIN_SIZE);
            newSize = newPos(3:4);
            if changed
                app.UIFigure.Position = newPos;
            end
        end

        % Cell edit callback: UITable
        function UITableCellEdit(app, event)
            stepIdx = selectedStepIndex(app);
            if isempty(stepIdx) || stepIdx > numel(app.spec); return; end

            reg    = stepRegistry();
            step   = app.spec(stepIdx);
            regIdx = find(strcmp({reg.name}, step.name), 1);
            if isempty(regIdx); return; end

            row    = event.Indices(1);
            params = reg(regIdx).params;
            % Reject edits to a parameter that is disabled for this step -
            % overridden by a mutually-exclusive sibling, or gated off by
            % another param's value. Revert the cell and explain why.
            if row <= numel(params)
                [disabled, reasons] = disabledParamKeys(reg(regIdx), step.params);
                key = params(row).key;
                if any(strcmp(key, disabled))
                    uialert(app.UIFigure, reasons.(key), 'Parameter disabled');
                    refreshParamTable(app, stepIdx);   % revert the edited cell
                    return
                end
            end

            app.spec = applyParamEdit(app.spec, stepIdx, row, event.NewData, reg(regIdx));
            app.pipelineDirty = true;
            updateStatusBar(app);
            % Re-render so setting/clearing one mutually-exclusive param updates
            % the disabled state of its sibling.
            refreshParamTable(app, stepIdx);
        end

        % Value changed function: SelectedListBox
        function SelectedListBoxValueChanged(app, ~)
            stepIdx = selectedStepIndex(app);
            if isempty(stepIdx) || stepIdx > numel(app.spec); return; end
            app.currentParamKey  = '';
            app.currentParamType = '';
            app.TextArea.Value   = '';
            refreshParamTable(app, stepIdx);
        end

        % Button pushed function: PLOTTEPButton
        function PLOTTEPButtonPushed(app, ~)
            if ~isFileSelected(app)
                warning('Please select at least a file to plot the TEP!');
            else
                LoadLabels(app);
                findTEPelecs(app);
                plotTEP(app)
                app.TEPWindowSlider.Limits = [app.EEGtime(1) app.EEGtime(end)];
                app.TEPCreated = true;
                app.TEPWindowSlider.Value = app.DefaulTEPxLim;
                app.ExportTEPDataButton.Enable    = 'on';
                app.TEPvarNameEditFieldLabel.Enable = 'on';
                app.TEPvarNameEditField.Enable    = 'on';
            end
        end

        % Selection changed function: PlotTypeButtonGroup
        function PlotTypeButtonGroupSelectionChanged(app, ~)
            % Swap the displayed curve (TEP/GMFP/LMFP) in place. Only re-plot
            % once a TEP has been drawn; otherwise the next PLOT TEP press picks
            % up the new selection.
            if app.TEPCreated && app.EEG_SelectedTEPFiles_Loaded
                findTEPelecs(app);
                plotTEP(app);
            else
                % No plot yet - still update the Analysis table headers/columns
                % so they reflect the newly selected mode.
                refreshAnalysisWindows(app);
            end
        end


        % Value changed function: UseCurrentlyCleanedDataCheckBox
        function UseCurrentlyCleanedDataCheckBoxValueChanged(app, ~)
            value = app.UseCurrentlyCleanedDataCheckBox.Value;
            if value
                % app.path is only set for a single-folder cleaning run; the
                % cleaned .set files land next to their source with the
                % cleanedName suffix. Build their full paths and feed the
                % same list setter the browser uses.
                if ~isempty(app.path) && ~isempty(app.cleanedName)
                    cleanedPaths = cell(1, app.NSelecFiles);
                    for nn = 1:app.NSelecFiles
                        base = app.file{nn};
                        dots = find(ismember(base, '.'));
                        if isempty(dots), stem = base; else, stem = base(1:dots(end)-1); end
                        cleanedPaths{nn} = fullfile(app.path, [stem '_' app.cleanedName '.set']);
                    end
                    setTEPFileList(app, cleanedPaths);
                    app.TEPCreated = false;  % file selection changed - existing plot is stale
                elseif ~isempty(app.FilesListBox.Items)
                    warning('No files have been cleaned recently. Try selecting files!')
                end
                app.TOPOPLOTButton.Enable = 'on';
                app.ExportTEPFigureButton.Enable = "on";
                app.OpenTEPFigureButton.Enable = "on";
                app.OpenTopoFigureButton.Enable = "on";
                app.PLOTTEPButton.Enable = "on";
            else
                warning('Try selecting files!')
            end
        end

        % Button pushed function: SelectDataButton_2
        function SelectDataButton_2Pushed(app, ~)
            % Same folder-tree browser as the Cleaning tab, so cleaned .set
            % files can be picked across many subject folders for plotting.
            startFolder = getpref('nestapp', 'lastDataFolder', '');
            if isempty(startFolder) && ~isempty(app.PathofSelectedFilesforTEP)
                startFolder = app.PathofSelectedFilesforTEP;
            end
            paths = selectDataTree(startFolder, {'*.set'});
            if isempty(paths); return; end
            setTEPFileList(app, paths);
            if isvalid(app.UIFigure); figure(app.UIFigure); end
        end

        function setTEPFileList(app, fullPaths)
        % SETTEPFILELIST  Populate the Visualize-tab file list from full paths.
        %   Mirrors the Cleaning tab's setFileQueue. The listbox shows
        %   readable labels (basename, or parentFolder/basename when the
        %   selection spans folders) while its ItemsData carries the full
        %   path, so loading / TEP extraction work regardless of which
        %   folders the files came from.
            fullPaths = fullPaths(:)';
            if isempty(fullPaths); return; end

            [labels, uniqueParents] = buildFileLabels(app, fullPaths);
            if isscalar(uniqueParents)
                app.PathofSelectedFilesforTEP = uniqueParents{1};
                app.FolderEditField_2.Value   = uniqueParents{1};
            else
                app.PathofSelectedFilesforTEP = '';   % files span folders
                app.FolderEditField_2.Value   = sprintf('(%d folders)', numel(uniqueParents));
            end

            app.FilesListBox.Value     = {};          % clear before swapping items
            app.FilesListBox.Items     = labels;
            app.FilesListBox.ItemsData = fullPaths;   % selections carry full paths

            % New file set - nothing selected yet; clear derived state.
            % (lastDataFolder is maintained by selectDataTree, not here.)
            applyTEPSelection(app, {});
            app.SelectAllCheckBox.Value = 0;

            app.TOPOPLOTButton.Enable        = 'on';
            app.ExportTEPFigureButton.Enable = "on";
            app.OpenTEPFigureButton.Enable   = "on";
            app.OpenTopoFigureButton.Enable  = "on";
            app.PLOTTEPButton.Enable         = "on";
            app.PlotEEGdataButton.Enable     = 'on';
            app.EEGDatasetDropDown.Enable    = "on";
        end

        function applyTEPSelection(app, sel)
        % APPLYTEPSELECTION  Adopt a new TEP file selection (full paths) and
        %   invalidate everything derived from the previous one. sel is
        %   always stored as a cell so downstream code never re-checks its
        %   type. Shared by the listbox, Select-all, and new-file-set paths.
            if ~iscell(sel); sel = {sel}; end
            app.SelectedFilesforTEP         = sel;
            app.EEGofAllSelectedFiles       = {};
            app.EEG_SelectedTEPFiles_Loaded = false;
            refreshTEPDropdown(app);
        end

        function refreshTEPDropdown(app)
        % REFRESHTEPDROPDOWN  Sync the per-file dropdown to the current
        %   selection. Items show basenames; ItemsData carries full paths
        %   so EEGDatasetDropDown.Value matches SelectedFilesforTEP.
            sel = app.SelectedFilesforTEP;   % always a cell (via applyTEPSelection)
            if isempty(sel)
                app.EEGDatasetDropDown.Items     = {};
                app.EEGDatasetDropDown.ItemsData = {};
                return
            end
            names = cell(1, numel(sel));
            for i = 1:numel(sel)
                [~, nm, ex] = fileparts(sel{i});
                names{i}    = [nm ex];
            end
            app.EEGDatasetDropDown.Items     = names;
            app.EEGDatasetDropDown.ItemsData = sel;
        end

        % Value changed function: FilesListBox
        function FilesListBoxValueChanged(app, event)
            sel = event.Value;              % ItemsData = full paths
            applyTEPSelection(app, sel);
            if ~isempty(sel)
                app.SelectAllCheckBox.Value = 0;   % manual pick is not "all"
            end
        end

        % Button pushed function: TOPOPLOTButton
        function TOPOPLOTButtonPushed(app, ~)
            if isFileSelected(app)
                EEG_topoplot(app)
            end
        end

        % Value changed function: SelectAllCheckBox
        function SelectAllCheckBoxValueChanged(app, ~)
            if app.SelectAllCheckBox.Value
                app.FilesListBox.Value = app.FilesListBox.ItemsData;  % every row
            else
                app.FilesListBox.Value = {};
            end
            applyTEPSelection(app, app.FilesListBox.Value);
        end

        % Value changed function: DontfindcommonelectrodesCheckBox
        function DontfindcommonelectrodesCheckBoxValueChanged(app, ~)
            value = app.DontfindcommonelectrodesCheckBox.Value;
            if ~value
                app.ReLoadAvailableElectrodesButton.Enable = 1;
            else
                app.ReLoadAvailableElectrodesButton.Enable = 0;
            end
        end

        % Button pushed function: ReLoadAvailableElectrodesButton
        function ReLoadAvailableElectrodesButtonPushed(app, ~)
            if isFileSelected(app)
                LoadLabels(app);
            end

        end

        % Button pushed function: ExportTEPFigureButton
        function ExportTEPFigureButtonPushed(app, ~)
            if ~app.TEPCreated
                uialert(app.UIFigure, 'Please plot a TEP first.', 'No figure');
                return
            end
            [fname, fpath] = uiputfile( ...
                {'*.png','PNG image';'*.pdf','PDF file';'*.fig','MATLAB figure'}, ...
                'Export TEP Figure', 'tep_figure');
            if isequal(fname, 0)
                return
            end
            outPath = fullfile(fpath, fname);
            [~, ~, ext] = fileparts(fname);
            if strcmpi(ext, '.fig')
                % Save a real figure, not the uifigure. savefig on the app's
                % own window produced a .fig that reopened as the entire
                % application rather than as an editable plot.
                fig = popOutAxes(app.UIAxes, struct( ...
                    'name', 'nestapp TEP', 'visible', 'off'));
                cleanup = onCleanup(@() delete(fig));
                savefig(fig, outPath);
            else
                exportgraphics(app.UIAxes, outPath, 'Resolution', 300);
            end
        end

        % Button pushed function: OpenTEPFigureButton
        function OpenTEPFigureButtonPushed(app, ~)
        % Hand the plotted curve to a standard MATLAB figure so it can be
        % edited with the plot editor / Property Inspector and saved from
        % there in any format.
            if ~app.TEPCreated
                uialert(app.UIFigure, 'Please plot a TEP first.', 'No figure');
                return
            end
            popOutAxes(app.UIAxes, struct('name', 'nestapp TEP', 'style', 'curve'));
        end

        % Button pushed function: OpenTopoFigureButton
        function OpenTopoFigureButtonPushed(app, ~)
        % Same for the scalp map. This draws into a classic axes directly
        % rather than copying out of UIAxes2, so the popped-out map is at full
        % resolution and carries its own uV colorbar.
            if ~isFileSelected(app)
                uialert(app.UIFigure, 'Please select data first.', 'No data');
                return
            end
            [values, chanLocs] = topoScalpData(app);
            fig = figure('Name', 'nestapp Topoplot', 'NumberTitle', 'off', 'Color', 'w');
            ax  = axes(fig);
            drawScalpTopo(ax, values, chanLocs);
            title(ax, sprintf('%g ms (+/-%g ms)', ...
                app.TopoplottimeSpinner.Value, ...
                app.WindowsizefortimeaveragedTopoplotEditField.Value / 2));
        end

        % Value changing function: TEPWindowSlider
        function TEPWindowSliderValueChanging(app, event)
            changingValue = event.Value;
            app.UIAxes.XLim = changingValue;
        end

        % Value changed function: WindowsizefortimeaveragedTopoplotEditField
        function TopoWindowSizeValueChanged(app, ~)
        % The averaging half-window is read at render time, so changing it
        % only needs a re-render - without this the field silently did nothing
        % until the time spinner or TOPOPLOT was touched.
            if isFileSelected(app)
                EEG_topoplot(app)
            end
        end

        % Value changed function: TopoplottimeSpinner
        function TopoplottimeSpinnerValueChanged(app, ~)
            % The topoplot reads the spinner's value directly (see
            % EEG_topoplot), so changing the time just needs a re-render.
            if isFileSelected(app)
                EEG_topoplot(app)
            end
        end

        % Value changed function: EEGDatasetDropDown
        function EEGDatasetDropDownValueChanged(~, ~)
        end

        % Button pushed function: PlotEEGdataButton
        function PlotEEGdataButtonPushed(app, ~)
            subInd = strcmpi(app.SelectedFilesforTEP, app.EEGDatasetDropDown.Value);
            if isFileSelected(app)
                if ~app.EEG_SelectedTEPFiles_Loaded
                    LoadSelecEEGdata(app)
                end
                pop_eegplot(app.EEGofAllSelectedFiles{subInd},1,1,1)
            end
        end

        % Button pushed function: ExportTEPDataButton
        function ExportTEPDataButtonPushed(app, ~)
        % Export a struct to the base workspace: the per-file x per-window
        % results table for the active mode, plus the raw curve matrix.
            findTEPelecs(app);
            res = analysisWindowResults(app);
            out = struct( ...
                'windows', res, ...
                'curves',  app.TEP2Export, ...
                'time',    app.EEGtime, ...
                'mode',    currentPlotType(app), ...
                'roi',     {app.ROIelecsLabels});
            assignin('base', app.TEPvarNameEditField.Value, out);
            app.AnalysisStatusLabel.Text = sprintf( ...
                'Exported "%s" (%d window x file rows, %s) to workspace.', ...
                app.TEPvarNameEditField.Value, height(res), currentPlotType(app));
        end

        function T = analysisWindowResults(app)
        % ANALYSISWINDOWRESULTS  Per-file x per-window measures for the loaded
        %   selection in the active mode. Computes each file's curve with
        %   tepFieldCurve, then defers to the pure tepWindowTable builder.
            mode   = currentPlotType(app);
            nFiles = numel(app.EEGofAllSelectedFiles);
            nT     = numel(app.EEGtime);
            curves = zeros(nFiles, nT);
            labels = cell(1, nFiles);
            for f = 1:nFiles
                EEGaux = app.EEGofAllSelectedFiles{f};
                roiIdx = roiChannelIndex({EEGaux.chanlocs.labels}, app.ROIelecsLabels);
                curves(f,:) = smoothdata(tepFieldCurve(EEGaux.data, roiIdx, mode), 'movmean', app.SMOOTH_WIN_PTS);
                if iscell(app.SelectedFilesforTEP) && f <= numel(app.SelectedFilesforTEP)
                    [~, labels{f}] = fileparts(app.SelectedFilesforTEP{f});
                else
                    labels{f} = sprintf('file%d', f);
                end
            end
            T = tepWindowTable(labels, curves, app.EEGtime, app.tepComponentDefs, mode);
        end

        % Value changed function: TEPvarNameEditField
        function TEPvarNameEditFieldValueChanged(~, ~)
        end

        % Value changed function: ShowComponentsButton
        function ShowComponentsButtonValueChanged(app, ~)
            if app.TEPCreated
                if app.ShowComponentsButton.Value
                    overlayTEPComponents(app);
                else
                    % Replot without overlays - cla then replot
                    plotTEP(app);
                end
            end
        end

        % Cell edit callback: TEPComponentTable (windows of interest)
        function WOITableCellEdit(app, event)
        % Edit a window's Name/T1/T2 inline, then recompute its measures.
            r = event.Indices(1);
            c = event.Indices(2);
            if r > numel(app.tepComponentDefs); return; end
            switch c
                case 1
                    app.tepComponentDefs(r).name = char(event.NewData);
                case 2
                    app.tepComponentDefs(r).winStart = event.NewData;
                case 3
                    app.tepComponentDefs(r).winEnd = event.NewData;
            end
            afterWindowsChanged(app);
        end

        % Button pushed function: AddWindowButton
        function AddWindowButtonPushed(app, ~)
            n = numel(app.tepComponentDefs);
            newDef = struct('name', sprintf('W%d', n+1), 'polarity', 'auto', ...
                'nomLatency', 100, 'winStart', 50, 'winEnd', 150);
            if isempty(app.tepComponentDefs)
                app.tepComponentDefs = newDef;
            else
                app.tepComponentDefs(n+1) = newDef;
            end
            afterWindowsChanged(app);
        end

        % Button pushed function: RemoveWindowButton
        function RemoveWindowButtonPushed(app, ~)
            sel = app.TEPComponentTable.Selection;
            if isempty(sel)
                uialert(app.UIFigure, 'Select a window row to remove.', 'No selection');
                return
            end
            rows = unique(sel(:));
            rows(rows > numel(app.tepComponentDefs)) = [];
            app.tepComponentDefs(rows) = [];
            afterWindowsChanged(app);
        end

        % Button pushed function: ResetWindowsButton
        function ResetWindowsButtonPushed(app, ~)
            app.tepComponentDefs = defaultTEPComponentDefs();
            afterWindowsChanged(app);
        end

        % -- Analysis Tab callbacks ----------------------------------------

        % Button pushed function: ExtractPeaksCSVButton
        function ExtractPeaksCSVButtonPushed(app, ~)
        % Extract peaks across all selected files and save as CSV.
            findTEPelecs(app);   % refresh ROI from current electrode button state
            if isempty(app.ROIelecsLabels)
                uialert(app.UIFigure, ...
                    'No ROI electrodes selected. Choose electrodes on the Visualizing tab.', ...
                    'Extract Peaks');
                return
            end
            if isempty(app.SelectedFilesforTEP)
                uialert(app.UIFigure, ...
                    'No files selected. Select .set files on the Visualizing tab.', ...
                    'Extract Peaks');
                return
            end
            mode = currentPlotType(app);
            defName = sprintf('tep_windows_%s.csv', lower(mode));
            [fname, fpath] = uiputfile('*.csv', 'Save Window Measures CSV', defName);
            if isequal(fname, 0); return; end
            csvPath = fullfile(fpath, fname);

            % SelectedFilesforTEP already holds full paths (may span folders).
            tepPaths = app.SelectedFilesforTEP;

            d = uiprogressdlg(app.UIFigure, ...
                'Title',          'Extracting Window Measures', ...
                'Message',        'Starting...', ...
                'Cancelable',     'off', ...
                'ShowPercentage', 'on');

            try
                [results, warnings] = batchWindowExtract(tepPaths, app.ROIelecsLabels, ...
                    mode, app.tepComponentDefs, ...
                    'csvPath',     csvPath, ...
                    'progressFcn', @(i,n) updateExtractionProgress(d, i, n, tepPaths));
            catch ME
                if isvalid(d); close(d); end
                uialert(app.UIFigure, ME.message, 'Extraction Error');
                return
            end
            if isvalid(d); close(d); end

            nRows = height(results);
            if isempty(warnings)
                app.AnalysisStatusLabel.Text = sprintf('Extracted %d rows -> %s', nRows, fname);
            else
                app.AnalysisStatusLabel.Text = sprintf( ...
                    'Extracted %d rows -> %s  (%d warning(s))', nRows, fname, numel(warnings));
                uialert(app.UIFigure, strjoin(warnings, newline), 'Extraction Warnings');
            end

            function updateExtractionProgress(dlg, iFile, nFiles, fps)
                [~, nm] = fileparts(fps{iFile});
                dlg.Value   = (iFile - 1) / nFiles;
                dlg.Message = sprintf('File %d / %d  -  %s', iFile, nFiles, nm);
                drawnow limitrate
            end
        end

        % Selection changed function: TabGroup
        function TabGroupSelectionChanged(app, event)
        % Refresh the Analysis tab selection summary whenever it becomes active.
            if event.NewValue == app.AnalysisTab
                updateAnalysisSelectionSummary(app);
            end
        end

        function updateAnalysisSelectionSummary(app)
        % Update the read-only summary label on the Analysis tab.
            findTEPelecs(app);   % refresh ROI from current electrode button state
            refreshAnalysisWindows(app);   % keep the WOI table/mode current
            nFiles = numel(app.SelectedFilesforTEP);
            nROI   = numel(app.ROIelecsLabels);
            if nFiles == 0 && nROI == 0
                app.AnalysisSelectionLabel.Text = ...
                    'Select files and ROI electrodes on the Visualizing tab.';
                return
            end
            fileStr = sprintf('%d file(s) selected', nFiles);
            if nROI == 0
                roiStr = 'No ROI electrodes selected';
            elseif nROI <= 6
                roiStr = sprintf('ROI: %s', strjoin(app.ROIelecsLabels, ', '));
            else
                roiStr = sprintf('ROI: %s ... (%d electrodes total)', ...
                    strjoin(app.ROIelecsLabels(1:6), ', '), nROI);
            end
            app.AnalysisSelectionLabel.Text = sprintf('%s          %s', fileStr, roiStr);
        end

    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components - body in @nestapp/createComponents.m
        createComponents(app)
    end

    % Public methods callable from external functions (e.g. runPipelineCore)
    methods (Access = public)

        function updateReportsTab(app)
        % UPDATEREPORTSTAB  Public entry point - refreshes the Reports tab.
        %   Delegates to the private implementation. Exposed as public so
        %   runPipelineCore.m can call it after each processing run.
            updateReportsTabImpl(app);
        end

    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = nestapp

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            % Stop the hover timer first: a pending callback would otherwise
            % fire against a half-deleted app.
            if ~isempty(app.hoverTimer) && isvalid(app.hoverTimer)
                stop(app.hoverTimer);
                delete(app.hoverTimer);
            end

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end

function s = onOffState(tf)
if tf; s = 'on'; else; s = 'off'; end
end

function labels = firstRoiPreset()
p = roiPresets();
labels = {};
if ~isempty(p); labels = p(1).labels; end
end

function res = withMode(res, mode)
res.mode = mode;
end
