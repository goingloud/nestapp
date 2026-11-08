% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function dlg = editPipelineDialog(parentFig, spec, available, describe, blocks, onOK, startAt)
% EDITPIPELINEDIALOG  Add, remove and reorder pipeline steps in one window.
%   dlg = EDITPIPELINEDIALOG(parentFig, spec, available, describe, blocks, onOK)
%   dlg = EDITPIPELINEDIALOG(..., startAt)   open with step startAt selected
%
%   spec       the pipeline as it stands (struct array: name, params)
%   available  cellstr of step names this machine can run (availableSteps)
%   describe   @(name) -> text describing a step (shown under the library)
%   blocks     @(name) -> true for a step that waits for the user (marked in
%              the library)
%   onOK       called with the edited spec when OK is pressed; Cancel or
%              closing the window leaves the pipeline as it was
%
%   The library of steps is on the left, grouped by stage as in stepTaxonomy,
%   with a search box. The pipeline is on the right, coloured against how it
%   was when the window opened: added steps green, removed steps red (still
%   listed where they were, unnumbered), steps whose order changed blue.
%   Existing steps keep their settings; added steps start at their defaults.
%
%   Does not wait: the result arrives through onOK.
%
%   See also: stepTaxonomy, availableSteps, settingsForm

reg   = stepRegistry();
nOrig = numel(spec);
work  = struct('name', {}, 'params', {}, 'orig', {});
for i = 1:nOrig
    work(i) = struct('name', spec(i).name, 'params', spec(i).params, 'orig', i);
end

pos = [0 0 820 520];
if ~isempty(parentFig) && isvalid(parentFig)
    p = parentFig.Position;
    pos(1:2) = p(1:2) + (p(3:4) - pos(3:4)) / 2;
end
navy = nestColours('navy');
dlg = appWindow('Name', 'Edit pipeline', 'Position', pos, 'WindowStyle', 'modal', ...
    'Color', nestColours('page'));

uilabel(dlg, 'Position', [15 485 330 22], 'Text', 'Available steps', ...
    'FontWeight', 'bold', 'FontSize', 14, 'FontColor', navy);
uieditfield(dlg, 'Position', [15 455 330 24], 'Placeholder', 'Search steps', ...
    'ValueChangingFcn', @(~, e) fillTree(e.Value));
tree = uitree(dlg, 'Position', [15 168 330 280], 'SelectionChangedFcn', @(~, ~) describeSelected());
if isprop(tree, 'DoubleClickedFcn'), tree.DoubleClickedFcn = @(~, ~) addSelected(); end
info = uitextarea(dlg, 'Position', [15 60 330 100], 'Editable', 'off', 'BackgroundColor', 'w');

uibutton(dlg, 'Position', [355 300 110 28], 'Text', ['Add ' char(8594)], 'ButtonPushedFcn', @(~, ~) addSelected());
uibutton(dlg, 'Position', [355 262 110 28], 'Text', [char(8592) ' Remove'], 'ButtonPushedFcn', @(~, ~) removeSelected());
uibutton(dlg, 'Position', [355 200 110 28], 'Text', 'Move up', 'ButtonPushedFcn', @(~, ~) moveSelected(-1));
uibutton(dlg, 'Position', [355 162 110 28], 'Text', 'Move down', 'ButtonPushedFcn', @(~, ~) moveSelected(+1));

uilabel(dlg, 'Position', [475 485 330 22], 'Text', 'Pipeline', ...
    'FontWeight', 'bold', 'FontSize', 14, 'FontColor', navy);
list = uilistbox(dlg, 'Position', [475 60 330 418], 'Items', {}, 'FontSize', 13);
uibutton(dlg, 'Position', [475 15 120 28], 'Text', 'Clear all', 'ButtonPushedFcn', @(~, ~) clearAll());
uibutton(dlg, 'Position', [610 15 90 28], 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(dlg));
uibutton(dlg, 'Position', [710 15 95 28], 'Text', 'OK', 'FontWeight', 'bold', ...
    'BackgroundColor', nestColours('mint'), 'FontColor', navy, 'ButtonPushedFcn', @(~, ~) finish());

flag = stepInteractiveIcon();
fillTree('');
if nargin < 7 || isempty(startAt), startAt = 1; end
render(min(startAt, numel(work)));

% ---------------------------------------------------------------------------

    function fillTree(query)
        delete(tree.Children);
        tax = stepTaxonomy();
        placed = {};
        for c = 1:numel(tax)
            names = {};
            for o = 1:numel(tax(c).ops)
                names = [names, {tax(c).ops(o).variants.step}]; %#ok<AGROW>
            end
            names = names(ismember(names, available));
            placed = [placed, names]; %#ok<AGROW>
            addGroup(tax(c).name, names, query);
        end
        addGroup('Other', setdiff(available, placed, 'stable'), query);
        if ~isempty(query), expand(tree, 'all'); end
    end

    function addGroup(title, names, query)
        if ~isempty(query)
            names = names(contains(lower(names), lower(strtrim(query))));
        end
        if isempty(names), return; end
        g = uitreenode(tree, 'Text', title, 'NodeData', '');
        for k = 1:numel(names)
            leaf = uitreenode(g, 'Text', names{k}, 'NodeData', names{k});
            if blocks(names{k}), try leaf.Icon = flag; catch, end, end %#ok<CTCH>
        end
    end

    function name = selectedLibraryStep()
        name = '';
        n = tree.SelectedNodes;
        if ~isempty(n) && ~isempty(n(1).NodeData), name = n(1).NodeData; end
    end

    function describeSelected()
        name = selectedLibraryStep();
        if isempty(name)
            info.Value = '';
        else
            info.Value = [{name}; reshape(cellstr(describe(name)), [], 1)];
        end
    end

    function k = selectedEntry()
        % Index into work of the selected pipeline row; [] for none or a
        % removed (red) row.
        k = [];
        v = list.Value;
        if ischar(v) && startsWith(v, 'e'), k = str2double(v(2:end)); end
    end

    function addSelected()
        name = selectedLibraryStep();
        if isempty(name), return; end
        k = selectedEntry();
        if isempty(k), k = numel(work); end
        step = makePipelineStep(name, reg);
        work = [work(1:k), struct('name', name, 'params', step.params, 'orig', 0), work(k+1:end)];
        render(k + 1);
    end

    function removeSelected()
        k = selectedEntry();
        if isempty(k), return; end
        work(k) = [];
        render(min(k, numel(work)));
    end

    function moveSelected(d)
        k = selectedEntry();
        if isempty(k) || k + d < 1 || k + d > numel(work), return; end
        work([k, k + d]) = work([k + d, k]);
        render(k + d);
    end

    function clearAll()
        if isempty(work), return; end
        if getpref('nestapp', 'confirmClear', true)
            answer = uiconfirm(dlg, 'Remove every step from the pipeline?', 'Clear all', ...
                'Options', {'Clear all', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(answer, 'Clear all'), return; end
        end
        work = work([]);
        render(0);
    end

    function finish()
        out = struct('name', {}, 'params', {});
        for i = 1:numel(work)
            out(i) = struct('name', work(i).name, 'params', work(i).params);
        end
        delete(dlg);
        onOK(out);
    end

    function render(selectK)
        % Rows: the current steps, numbered, with each removed original step
        % slotted in after the last surviving step that preceded it.
        origs = [work.orig];
        removed = setdiff(1:nOrig, origs(origs > 0));
        items = arrayfun(@(k) sprintf('%d  %s', k, work(k).name), 1:numel(work), 'UniformOutput', false);
        data  = arrayfun(@(k) sprintf('e%d', k), 1:numel(work), 'UniformOutput', false);
        kind  = repmat({'same'}, 1, numel(work));
        kind(origs == 0) = {'added'};
        kept = origs(origs > 0);
        movedOrig = kept(kept ~= sort(kept));
        kind(ismember(origs, movedOrig) & origs > 0) = {'moved'};
        for r = removed
            before = find(origs > 0 & origs < r, 1, 'last');
            if isempty(before), at = 0; else, at = find(strcmp(data, sprintf('e%d', before))); end
            items = [items(1:at), {['     ' spec(r).name]}, items(at+1:end)];
            data  = [data(1:at),  {sprintf('r%d', r)},       data(at+1:end)];
            kind  = [kind(1:at),  {'removed'},               kind(at+1:end)];
        end
        list.Items = items;
        list.ItemsData = data;
        removeStyle(list);
        colours = struct('added', [0.0 0.5 0.15], 'removed', nestColours('problem'), 'moved', [0.1 0.35 0.75]);
        for f = fieldnames(colours)'
            idx = find(strcmp(kind, f{1}));
            if ~isempty(idx), addStyle(list, uistyle('FontColor', colours.(f{1})), 'item', idx); end
        end
        if selectK >= 1 && selectK <= numel(work)
            list.Value = sprintf('e%d', selectK);
        elseif ~isempty(data)
            list.Value = data{1};
        end
    end
end
