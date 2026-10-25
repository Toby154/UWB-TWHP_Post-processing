function dataset_splitter(mappingDir)
%DATASET_SPLITTER 中英文数据集重新划分向导。
% 运行后选择语言和路径；原时间切片按 train -> test 顺序还原。
if nargin < 1
    mappingDir = fullfile(fileparts(mfilename('fullpath')), 'range_mapping');
end
state = struct('Language', 'en', 'Source', '', 'Output', '', 'IndependentOutput', '', ...
    'Overwrite', false, 'AddRange', false, 'SpeedLevel', 2, 'Method', 'frame', 'Percent', 80, ...
    'Subjects', false(15, 1), 'SelectedTrials', [], 'Trials', [], 'Plan', [], ...
    'Controls', struct(), 'Busy', false, 'Commit', false, 'Cancelled', false, ...
    'CloseRequested', false, 'VisibleRows', [], 'Filters', ones(1, 4), ...
    'LastPhase', '', 'LastUpdate', tic);
fig = figure('Name', '数据集划分工具 / Dataset Splitter', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'normalized', 'Position', [0.09, 0.08, 0.82, 0.84], ...
    'MenuBar', 'none', 'ToolBar', 'none', 'CloseRequestFcn', @closeWindow, ...
    'Tag', 'DatasetSplitter');
heading = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.04, 0.92, 0.92, 0.055], 'FontSize', 18, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
body = uipanel(fig, 'Units', 'normalized', 'Position', [0.04, 0.045, 0.92, 0.85], ...
    'BorderType', 'none', 'BackgroundColor', 'w');
showLanguage();

    function value = msg(key, varargin)
        value = dataset_split.text(state.Language, key, varargin{:});
    end
    function page(key)
        delete(allchild(body)); state.Controls = struct();
        set(heading, 'String', msg(key));
        set(fig, 'Name', msg('title'));
    end
    function handle = label(value, position, tag)
        if nargin < 3, tag = ''; end
        handle = uicontrol(body, 'Style', 'text', 'String', value, 'Units', 'normalized', ...
            'Position', position, 'BackgroundColor', 'w', 'FontSize', 11, ...
            'HorizontalAlignment', 'left', 'Tag', tag);
    end
    function handle = button(key, position, callback, tag)
        if nargin < 4, tag = key; end
        handle = uicontrol(body, 'Style', 'pushbutton', 'String', msg(key), ...
            'Units', 'normalized', 'Position', position, 'FontSize', 11, ...
            'Callback', callback, 'Tag', tag);
    end
    function handle = edit(value, position, callback, tag)
        handle = uicontrol(body, 'Style', 'edit', 'String', value, 'Units', 'normalized', ...
            'Position', position, 'FontSize', 11, 'HorizontalAlignment', 'left', ...
            'BackgroundColor', 'w', 'Callback', callback, 'Tag', tag);
    end
    function showLanguage()
        page('language');
        zh = button('confirm', [0.18, 0.43, 0.28, 0.15], @(~,~) chooseLanguage('zh'), 'LanguageZh');
        en = button('confirm', [0.54, 0.43, 0.28, 0.15], @(~,~) chooseLanguage('en'), 'LanguageEn');
        set(zh, 'String', '简体中文', 'FontSize', 18);
        set(en, 'String', 'English', 'FontSize', 18);
    end
    function chooseLanguage(language)
        state.Language = language; showPaths();
    end
    function showPaths()
        state.Busy = false; page('paths');
        label(msg('source'), [0.04, 0.83, 0.92, 0.05]);
        state.Controls.Source = edit(state.Source, [0.04, 0.74, 0.72, 0.07], @sourceEdited, 'SourcePath');
        button('browse', [0.79, 0.74, 0.17, 0.07], @(~,~) browsePath('source'), 'BrowseSource');
        label(msg('output'), [0.04, 0.61, 0.92, 0.05]);
        state.Controls.Output = edit(state.Output, [0.04, 0.52, 0.72, 0.07], [], 'OutputPath');
        state.Controls.OutputBrowse = button('browse', [0.79, 0.52, 0.17, 0.07], ...
            @(~,~) browsePath('output'), 'BrowseOutput');
        state.Controls.Overwrite = uicontrol(body, 'Style', 'checkbox', 'String', msg('overwrite'), ...
            'Units', 'normalized', 'Position', [0.04, 0.40, 0.92, 0.07], ...
            'Value', state.Overwrite, 'BackgroundColor', 'w', 'FontSize', 12, ...
            'Callback', @overwriteChanged, 'Tag', 'Overwrite');
        label(msg('speed'), [0.04, 0.30, 0.23, 0.055]);
        uicontrol(body, 'Style', 'popupmenu', 'Units', 'normalized', ...
            'Position', [0.28, 0.30, 0.68, 0.06], 'FontSize', 11, ...
            'String', {msg('speed_1'),msg('speed_2'),msg('speed_3'),msg('speed_4')}, ...
            'Value', state.SpeedLevel, 'Callback', @speedChanged, 'Tag', 'SpeedLevel');
        label(msg('speed_help'), [0.04, 0.12, 0.92, 0.15], 'SpeedHelp');
        setOutputEnabled();
        button('back', [0.04, 0.02, 0.18, 0.075], @(~,~) showLanguage(), 'PathsBack');
        button('confirm', [0.78, 0.02, 0.18, 0.075], @confirmPaths, 'PathsConfirm');
    end
    function speedChanged(src,~)
        state.SpeedLevel = get(src, 'Value');
    end
    function sourceEdited(~,~)
        if state.Overwrite
            set(state.Controls.Output, 'String', get(state.Controls.Source, 'String'));
        end
    end
    function overwriteChanged(src,~)
        value = logical(get(src, 'Value'));
        if value && ~state.Overwrite
            state.IndependentOutput = get(state.Controls.Output, 'String');
        elseif ~value && state.Overwrite
            set(state.Controls.Output, 'String', state.IndependentOutput);
        end
        state.Overwrite = value; setOutputEnabled();
    end
    function setOutputEnabled()
        enabled = 'on';
        if state.Overwrite
            enabled = 'off';
            set(state.Controls.Output, 'String', get(state.Controls.Source, 'String'));
        end
        set(state.Controls.Output, 'Enable', enabled);
        set(state.Controls.OutputBrowse, 'Enable', enabled);
    end
    function browsePath(which)
        initial = pwd;
        if strcmp(which, 'source'), field = 'Source'; else, field = 'Output'; end
        current = get(state.Controls.(field), 'String');
        if isfolder(current), initial = current; end
        chosen = chooseFolder(initial);
        if ~isempty(chosen)
            set(state.Controls.(field), 'String', chosen);
            if strcmp(which, 'source'), sourceEdited([], []); end
        end
    end
    function confirmPaths(~,~)
        source = get(state.Controls.Source, 'String');
        output = get(state.Controls.Output, 'String');
        try
            [state.Source, state.Output] = dataset_split.paths(source, output, state.Overwrite, state.Language);
            showProgress();
            state.Trials = dataset_split.inventory(state.Source, state.Language, @progress, @isCancelled);
            state.SelectedTrials = false(numel(state.Trials), 1); state.Filters(:) = 1;
            state.Busy = false;
            if state.CloseRequested, delete(fig); return; end
            showMethod();
        catch ME
            state.Busy = false;
            if state.CloseRequested, delete(fig); return; end
            showPaths(); displayError(ME);
        end
    end
    function showMethod()
        page('method');
        methods = {'frame','subject','trial','none'};
        for i = 1:4
            method = methods{i}; y = 0.82 - (i - 1) * 0.16;
            button(method, [0.03, y, 0.29, 0.09], @(~,~) selectMethod(method), ['Method_', method]);
            label(msg([method, '_help']), [0.35, y - 0.01, 0.62, 0.10]);
        end
        uicontrol(body, 'Style', 'checkbox', 'String', msg('range'), 'Value', state.AddRange, ...
            'Units', 'normalized', 'Position', [0.03, 0.20, 0.94, 0.07], ...
            'BackgroundColor', 'w', 'FontSize', 12, 'Callback', @rangeChanged, 'Tag', 'AddRange');
        label(msg('range_help'), [0.03, 0.11, 0.94, 0.07]);
        button('back', [0.03, 0.01, 0.18, 0.07], @(~,~) showPaths(), 'MethodBack');
    end
    function rangeChanged(src,~)
        state.AddRange = logical(get(src, 'Value'));
    end
    function selectMethod(method)
        state.Method = method;
        switch method
            case 'frame', showFrame();
            case 'subject', showSubject();
            case 'trial', showTrial();
            case 'none', showOverview();
        end
    end
    function showFrame()
        page('frame');
        label(msg('train_ratio'), [0.10, 0.72, 0.28, 0.06]);
        label(msg('test_ratio'), [0.65, 0.72, 0.28, 0.06]);
        state.Controls.Train = edit(num2str(state.Percent), [0.10, 0.62, 0.25, 0.075], ...
            @(src,~) ratioEdited(src, true), 'TrainPercent');
        state.Controls.Test = edit(num2str(100 - state.Percent), [0.65, 0.62, 0.25, 0.075], ...
            @(src,~) ratioEdited(src, false), 'TestPercent');
        state.Controls.Slider = uicontrol(body, 'Style', 'slider', 'Units', 'normalized', ...
            'Position', [0.10, 0.46, 0.80, 0.10], 'Min', 0, 'Max', 100, ...
            'Value', state.Percent, 'SliderStep', [0.01, 0.1], ...
            'Callback', @(src,~) updateRatio(round(get(src,'Value'))), 'Tag', 'RatioSlider');
        button('confirm', [0.36, 0.28, 0.28, 0.08], @(~,~) showOverview(), 'FrameConfirm');
        button('back', [0.04, 0.02, 0.18, 0.07], @(~,~) showMethod(), 'FrameBack');
    end
    function ratioEdited(src, isTrain)
        value = str2double(get(src, 'String'));
        if ~isscalar(value) || ~isfinite(value) || value < 0 || value > 100 || value ~= round(value)
            updateRatio(state.Percent);
            errordlg(msg('bad_ratio'), msg('error_title')); return;
        end
        if ~isTrain, value = 100 - value; end
        updateRatio(value);
    end
    function updateRatio(value)
        state.Percent = value;
        set(state.Controls.Train, 'String', num2str(value));
        set(state.Controls.Test, 'String', num2str(100 - value));
        set(state.Controls.Slider, 'Value', value);
    end
    function showSubject()
        page('subject_select');
        label(msg('subject_note'), [0.04, 0.85, 0.92, 0.07]);
        state.Controls.Subjects = gobjects(15, 1);
        for h = 0:14
            state.Controls.Subjects(h + 1) = uicontrol(body, 'Style', 'checkbox', ...
                'String', sprintf('H%d', h), 'Value', state.Subjects(h + 1), ...
                'Units', 'normalized', 'Position', [0.06 + mod(h,5) * 0.18, 0.67 - floor(h/5) * 0.17, 0.16, 0.08], ...
                'BackgroundColor', 'w', 'FontSize', 13, 'Tag', sprintf('SubjectH%d', h));
        end
        button('confirm', [0.38, 0.17, 0.24, 0.08], @confirmSubjects, 'SubjectsConfirm');
        button('back', [0.04, 0.02, 0.18, 0.07], @(~,~) showMethod(), 'SubjectsBack');
    end
    function confirmSubjects(~,~)
        for i = 1:15, state.Subjects(i) = logical(get(state.Controls.Subjects(i), 'Value')); end
        showOverview();
    end
    function showTrial()
        page('trial_select');
        keys = {'people','subjects','actions','c_number'};
        values = {cellstr(string(unique([state.Trials.People]))), ...
            unique({state.Trials.SubjectKey}), unique({state.Trials.ActionKey}), ...
            cellstr("C" + string(unique([state.Trials.C])))};
        state.Controls.Filters = gobjects(4, 1);
        for i = 1:4
            x = 0.02 + (i - 1) * 0.245;
            label(msg(keys{i}), [x, 0.91, 0.235, 0.04]);
            state.Controls.Filters(i) = uicontrol(body, 'Style', 'popupmenu', ...
                'String', [{msg('all')}, reshape(values{i}, 1, [])], ...
                'Value', state.Filters(i), 'Units', 'normalized', 'Position', [x, 0.83, 0.235, 0.065], ...
                'FontSize', 10, 'Callback', @filtersChanged, 'Tag', ['Filter_', keys{i}]);
        end
        state.Controls.Table = uitable(body, 'Units', 'normalized', 'Position', [0.02, 0.27, 0.96, 0.52], ...
            'ColumnName', {msg('test_column'),msg('trial_id'),msg('people'),msg('subjects'),msg('actions'),msg('frames')}, ...
            'ColumnEditable', [true,false,false,false,false,false], ...
            'ColumnFormat', {'logical','char','numeric','char','char','numeric'}, ...
            'ColumnWidth', {90,340,60,150,150,100}, 'RowName', [], ...
            'CellEditCallback', @trialEdited, 'Tag', 'TrialTable');
        button('select_visible', [0.02, 0.18, 0.30, 0.065], @(~,~) selectVisible(true), 'SelectVisible');
        button('clear_visible', [0.35, 0.18, 0.30, 0.065], @(~,~) selectVisible(false), 'ClearVisible');
        button('clear_all', [0.68, 0.18, 0.30, 0.065], @(~,~) clearSelections(), 'ClearAll');
        state.Controls.Statistics = label('', [0.02, 0.10, 0.96, 0.06], 'TrialStatistics');
        button('back', [0.02, 0.01, 0.18, 0.07], @(~,~) showMethod(), 'TrialsBack');
        button('confirm', [0.80, 0.01, 0.18, 0.07], @(~,~) showOverview(), 'TrialsConfirm');
        renderTrials();
    end
    function filtersChanged(~,~)
        for i = 1:4, state.Filters(i) = get(state.Controls.Filters(i), 'Value'); end
        renderTrials();
    end
    function value = filterValue(index)
        control = state.Controls.Filters(index); options = get(control, 'String');
        if get(control, 'Value') == 1, value = ''; else, value = options{get(control,'Value')}; end
    end
    function renderTrials()
        people = filterValue(1); if ~isempty(people), people = str2double(people); end
        c = filterValue(4); if ~isempty(c), c = str2double(c(2:end)); end
        mask = dataset_split.trial_filter(state.Trials, people, filterValue(2), filterValue(3), c);
        state.VisibleRows = find(mask);
        % 批量提取列，避免逐行访问含完整源文件元数据的向导状态。
        visible = state.Trials(state.VisibleRows);
        data = [num2cell(state.SelectedTrials(state.VisibleRows)), ...
            reshape({visible.Id}, [], 1), num2cell(reshape([visible.People], [], 1)), ...
            reshape({visible.SubjectKey}, [], 1), reshape({visible.ActionKey}, [], 1), ...
            num2cell(reshape([visible.Frames], [], 1))];
        set(state.Controls.Table, 'Data', data); updateStatistics();
    end
    function trialEdited(~, event)
        if event.Indices(2) == 1
            state.SelectedTrials(state.VisibleRows(event.Indices(1))) = logical(event.NewData);
            updateStatistics();
        end
    end
    function selectVisible(value)
        state.SelectedTrials(state.VisibleRows) = value; renderTrials();
    end
    function clearSelections()
        state.SelectedTrials(:) = false; renderTrials();
    end
    function updateStatistics()
        frames = [state.Trials.Frames].'; selected = sum(frames(state.SelectedTrials));
        set(state.Controls.Statistics, 'String', msg('selection', numel(state.VisibleRows), ...
            sum(state.SelectedTrials), selected, sum(frames) - selected));
    end
    function showOverview()
        selectedIds = {state.Trials(state.SelectedTrials).Id};
        state.Plan = dataset_split.plan(state.Trials, state.Method, state.Percent, ...
            find(state.Subjects).' - 1, selectedIds);
        page('overview');
        if strcmp(state.Method, 'none')
            totals = msg('full_totals', state.Plan.NumTrials, state.Plan.TotalFrames);
        else
            totals = msg('totals', state.Plan.NumTrials, state.Plan.TotalFrames, ...
                sum(state.Plan.TrainFrames), sum(state.Plan.TestFrames));
        end
        label([msg(state.Method), newline, totals], [0.04, 0.73, 0.92, 0.20], 'OverviewTotals');
        label([msg('output'), ': ', state.Output], [0.04, 0.65, 0.92, 0.07]);
        if ismember(state.Method, {'subject','trial'})
            if strcmp(state.Method, 'subject')
                training = state.Plan.TrainCombinations; testing = state.Plan.TestCombinations;
                kind = msg('combinations');
            else
                training = state.Plan.TrainTrials; testing = state.Plan.TestTrials; kind = msg('trials');
            end
            if isempty(training), training = {''}; end
            if isempty(testing), testing = {''}; end
            label(msg('train_list', kind), [0.04, 0.57, 0.44, 0.05]);
            label(msg('test_list', kind), [0.52, 0.57, 0.44, 0.05]);
            uicontrol(body, 'Style', 'listbox', 'String', training, 'Units', 'normalized', ...
                'Position', [0.04, 0.15, 0.44, 0.40], 'BackgroundColor', 'w', 'Tag', 'TrainingList');
            uicontrol(body, 'Style', 'listbox', 'String', testing, 'Units', 'normalized', ...
                'Position', [0.52, 0.15, 0.44, 0.40], 'BackgroundColor', 'w', 'Tag', 'TestList');
        end
        key = 'start'; if strcmp(state.Method, 'none'), key = 'full_start'; end
        button(key, [0.65, 0.02, 0.31, 0.075], @startGeneration, 'StartGeneration');
        button('back', [0.04, 0.02, 0.18, 0.075], @overviewBack, 'OverviewBack');
    end
    function overviewBack(~,~)
        % 完整试次模式没有参数页，返回时直接进入划分方式菜单。
        if strcmp(state.Method, 'none'), showMethod(); else, selectMethod(state.Method); end
    end
    function showProgress()
        state.Busy = true; state.Commit = false; state.Cancelled = false; state.LastPhase = '';
        page('processing');
        state.Controls.Message = label('', [0.06, 0.63, 0.88, 0.17], 'ProgressMessage');
        axis = axes(body, 'Units', 'normalized', 'Position', [0.06,0.53,0.88,0.07], ...
            'XLim',[0,1], 'YLim',[0,1], 'XTick',[], 'YTick',[], 'Box','on');
        state.Controls.Bar = patch(axis, [0,0,0,0], [0,0,1,1], [0.1,0.5,0.85], 'EdgeColor','none');
        state.Controls.Percent = label('0%', [0.06, 0.43, 0.88, 0.06]);
        state.Controls.Cancel = button('cancel', [0.38,0.20,0.24,0.075], @cancelGeneration, 'CancelGeneration');
        drawnow;
    end
    function progress(event)
        if ~isgraphics(fig), return; end
        state.Commit = strcmp(event.Phase, 'commit');
        if state.Commit, set(state.Controls.Cancel, 'Enable', 'off'); end
        if ~state.Commit, dataset_split.check_cancel(@isCancelled, state.Language); end
        if toc(state.LastUpdate) < 0.1 && strcmp(state.LastPhase,event.Phase) && event.Fraction < 1, return; end
        state.LastUpdate = tic; state.LastPhase = event.Phase;
        switch event.Phase
            case 'scan', key = 'scan_progress';
            case 'prefetch', key = 'prefetch_progress';
            case 'write'
                key = 'write_progress';
                if state.AddRange, key = 'write_range_progress'; end
            case 'range_check', key = 'range_check';
            case 'range_add', key = 'range_add';
            case 'commit', key = 'commit_progress';
        end
        if strcmp(event.Phase, 'prefetch')
            value = msg(key,event.Current,event.Total,event.CacheTrials,event.CacheBytes / 1024^2,event.Name);
        elseif state.Commit
            value = msg(key,event.Current,event.Total);
        else
            value = msg(key,event.Current,event.Total,event.Name);
        end
        fraction = max(0,min(1,event.Fraction));
        set(state.Controls.Message,'String',value);
        set(state.Controls.Bar,'XData',[0,fraction,fraction,0]);
        set(state.Controls.Percent,'String',sprintf('%d%%',round(fraction*100)));
        drawnow;
    end
    function cancelGeneration(~,~)
        state.Cancelled = true;
    end
    function value = isCancelled()
        value = state.Cancelled;
    end
    function startGeneration(~,~)
        showProgress();
        options = struct('SourceRoot',state.Source,'OutputRoot',state.Output, ...
            'Overwrite',state.Overwrite,'AddRange',state.AddRange,'Language',state.Language, ...
            'SpeedLevel',state.SpeedLevel,'ProgressFcn',@progress,'CancelFcn',@isCancelled,'MappingDir',mappingDir);
        try
            report = dataset_split.generate(state.Trials,state.Plan,options);
            state.Busy = false;
            page('overview');
            label(msg('done',report.NumFiles,report.TotalFrames,report.OutputRoot), ...
                [0.04,0.55,0.92,0.25],'Completion');
            button('back',[0.04,0.02,0.18,0.075],@(~,~) showPaths(),'CompletionBack');
        catch ME
            state.Busy = false;
            if state.CloseRequested, delete(fig); return; end
            if strcmp(ME.identifier,'dataset_split:commit_failed'), showPaths(); else, showOverview(); end
            displayError(ME);
        end
    end
    function displayError(ME)
        if strcmp(ME.identifier,'dataset_split:cancel_id')
            value = msg('cancelled');
        elseif startsWith(ME.identifier,'dataset_split:') || startsWith(ME.identifier,'add_range_bin_to_mat:')
            value = ME.message;
        else
            value = msg('generic_error',ME.identifier);
        end
        errordlg(value,msg('error_title'));
    end
    function closeWindow(~,~)
        if state.Busy
            if ~state.Commit, state.Cancelled = true; state.CloseRequested = true; end
        else
            delete(fig);
        end
    end
    function chosen = chooseFolder(initial)
        % 自建目录选择器，使选择/取消等控件也遵循向导语言。
        chosen = ''; current = initial;
        dialog = figure('Name',msg('browse'),'NumberTitle','off','MenuBar','none', ...
            'ToolBar','none','WindowStyle','modal','Units','normalized', ...
            'Position',[0.22,0.20,0.56,0.58],'CloseRequestFcn',@dismiss);
        pathEdit = uicontrol(dialog,'Style','edit','Units','normalized','Position',[0.04,0.86,0.72,0.075], ...
            'String',current,'HorizontalAlignment','left','Callback',@enterPath);
        uicontrol(dialog,'Style','pushbutton','String',msg('parent'),'Units','normalized', ...
            'Position',[0.79,0.86,0.17,0.075],'Callback',@goParent);
        folders = uicontrol(dialog,'Style','listbox','Units','normalized','Position',[0.04,0.21,0.92,0.60], ...
            'Callback',@openFolder);
        uicontrol(dialog,'Style','pushbutton','String',msg('choose'),'Units','normalized', ...
            'Position',[0.49,0.05,0.47,0.10],'Callback',@accept);
        uicontrol(dialog,'Style','pushbutton','String',msg('cancel'),'Units','normalized', ...
            'Position',[0.04,0.05,0.25,0.10],'Callback',@dismiss);
        refreshFolders(); uiwait(dialog);
        if isgraphics(dialog), delete(dialog); end
        function refreshFolders()
            entries = dir(current); names = {entries([entries.isdir]).name};
            names = names(~ismember(names,{'.','..'}));
            if isempty(names), names = {''}; end
            set(pathEdit,'String',current); set(folders,'String',sort(names),'Value',1);
        end
        function enterPath(src,~)
            value = get(src,'String');
            if isfolder(value), current = value; refreshFolders(); else, set(src,'String',current); end
        end
        function goParent(~,~)
            parent = fileparts(current);
            if isfolder(parent), current = parent; refreshFolders(); end
        end
        function openFolder(~,~)
            if strcmp(get(dialog,'SelectionType'),'open')
                names = get(folders,'String');
                if ~isempty(names), current = fullfile(current,names{get(folders,'Value')}); refreshFolders(); end
            end
        end
        function accept(~,~)
            chosen = current; uiresume(dialog);
        end
        function dismiss(~,~)
            uiresume(dialog);
        end
    end
end
