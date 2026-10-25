function trials = inventory(root, language, progressFcn, cancelFcn)
%INVENTORY 只读扫描；train 在 test 之前，单个完整文件也可重新划分。
if nargin < 2, language = 'en'; end
if nargin < 3, progressFcn = []; end
if nargin < 4, cancelFcn = []; end
files = dir(fullfile(root, '**', '*.mat'));
if isempty(files)
    error('dataset_split:no_files', '%s', dataset_split.text(language, 'no_files'));
end
records = cell(numel(files), 1);
required = {'radar_data_real', 'radar_data_imag', 'joint', 'action'};
for i = 1:numel(files)
    dataset_split.check_cancel(cancelFcn, language);
    file = files(i);
    token = regexp(file.name, ...
        '^N(\d+)_H(\d+(?:-\d+)*)_A(\d+(?:-\d+)*)_C(\d+)(?:_(train|test))?\.mat$', ...
        'tokens', 'once');
    path = fullfile(file.folder, file.name);
    if isempty(token) || ~H5F.is_hdf5(path)
        error('dataset_split:bad_file', '%s', dataset_split.text(language, 'bad_file', file.name));
    end
    relativeFolder = file.folder(numel(root) + 2:end);
    [parent, leaf] = fileparts(relativeFolder);
    if ~strcmp(leaf, 'radardata')
        error('dataset_split:bad_file', '%s', dataset_split.text(language, 'bad_file', file.name));
    end
    split = 'full';
    suffix = regexp(file.name, '_(train|test)\.mat$', 'tokens', 'once');
    if ~isempty(suffix), split = suffix{1}; end
    if ~strcmp(split, 'full')
        [prefix, splitFolder] = fileparts(parent);
        if ~strcmp(splitFolder, split)
            error('dataset_split:bad_file', '%s', dataset_split.text(language, 'bad_file', file.name));
        end
    else
        prefix = parent;
    end
    subjects = sscanf(strrep(token{2}, '-', ' '), '%d').';
    actions = sscanf(strrep(token{3}, '-', ' '), '%d').';
    people = str2double(token{1});
    if numel(subjects) ~= people || numel(unique(subjects)) ~= people || ...
            any(subjects < 0 | subjects > 14) || numel(actions) ~= people || isempty(prefix)
        error('dataset_split:bad_file', '%s', dataset_split.text(language, 'bad_file', file.name));
    end
    info = whos('-file', path); names = {info.name};
    if ~all(ismember(required, names))
        error('dataset_split:bad_variables', '%s', dataset_split.text(language, 'bad_variables', file.name));
    end
    radar = info(strcmp(names, 'radar_data_real'));
    radarSize = [radar.size, ones(1, max(0, 3 - numel(radar.size)))];
    frames = radarSize(3);
    frameVars = required;
    if ismember('conf', names), frameVars = [required, {'conf'}]; end
    for v = 1:numel(frameVars)
        item = info(strcmp(names, frameVars{v}));
        dims = [item.size, ones(1, max(0, 3 - numel(item.size)))];
        if numel(dims) ~= 3 || dims(3) ~= frames || ...
                ~ismember(item.class, {'single', 'double', 'logical', 'uint8', 'int8', ...
                'uint16', 'int16', 'uint32', 'int32', 'uint64', 'int64'})
            error('dataset_split:bad_variables', '%s', dataset_split.text(language, 'bad_variables', file.name));
        end
    end
    imag = info(strcmp(names, 'radar_data_imag'));
    joints = info(strcmp(names, 'joint')); labels = info(strcmp(names, 'action'));
    if ~isequal(radar.size, imag.size) || joints.size(1) ~= people || ...
            joints.size(2) ~= 48 || labels.size(1) ~= people || labels.size(2) ~= 1
        error('dataset_split:bad_variables', '%s', dataset_split.text(language, 'bad_variables', file.name));
    end
    if ismember('conf', names)
        conf = info(strcmp(names, 'conf'));
        if conf.size(1) ~= people || conf.size(2) ~= 1
            error('dataset_split:bad_variables', '%s', dataset_split.text(language, 'bad_variables', file.name));
        end
    end
    id = regexprep(file.name, '(_train|_test)?\.mat$', '');
    records{i} = struct('Id', id, 'People', people, 'Subjects', subjects, ...
        'SubjectKey', ['H', token{2}], 'ActionKey', ['A', token{3}], ...
        'C', str2double(token{4}), 'Prefix', prefix, 'Frames', frames, ...
        'Path', path, 'Split', split, 'Info', info, 'FrameVars', {frameVars}, ...
        'Bytes', file.bytes, 'Date', file.datenum);
    if ~isempty(progressFcn) && (mod(i, 20) == 0 || i == numel(files))
        progressFcn(struct('Phase', 'scan', 'Fraction', i / numel(files), ...
            'Current', i, 'Total', numel(files), 'Name', file.name));
    end
end
records = vertcat(records{:});
[ids, ~, groups] = unique({records.Id});
[~, groupedOrder] = sort(groups);
groupStarts = [1; cumsum(accumarray(groups(:), 1)) + 1];
trials = repmat(struct('Id', '', 'People', 0, 'Subjects', [], 'SubjectKey', '', ...
    'ActionKey', '', 'C', 0, 'Prefix', '', 'Frames', 0, 'Sources', []), numel(ids), 1);
for i = 1:numel(ids)
    rows = records(groupedOrder(groupStarts(i):groupStarts(i + 1) - 1));
    splits = {rows.Split};
    if numel(unique(splits)) ~= numel(rows) || (ismember('full', splits) && numel(rows) > 1)
        error('dataset_split:bad_pair', '%s', dataset_split.text(language, 'bad_pair', ids{i}));
    end
    [~, order] = ismember(splits, {'train', 'test', 'full'});
    [~, order] = sort(order); rows = rows(order);
    first = rows(1);
    for j = 2:numel(rows)
        if ~strcmp(first.Prefix, rows(j).Prefix) || ...
                ~isequal(first.FrameVars, rows(j).FrameVars) || ...
                ~isequal(setdiff({first.Info.name}, {'range_bin'}), ...
                setdiff({rows(j).Info.name}, {'range_bin'}))
            error('dataset_split:bad_pair', '%s', dataset_split.text(language, 'bad_pair', ids{i}));
        end
        for v = 1:numel(first.FrameVars)
            a = first.Info(strcmp({first.Info.name}, first.FrameVars{v}));
            b = rows(j).Info(strcmp({rows(j).Info.name}, first.FrameVars{v}));
            if ~isequal(a.size(1:2), b.size(1:2)) || ~strcmp(a.class, b.class)
                error('dataset_split:bad_pair', '%s', dataset_split.text(language, 'bad_pair', ids{i}));
            end
        end
    end
    trials(i) = struct('Id', first.Id, 'People', first.People, 'Subjects', first.Subjects, ...
        'SubjectKey', first.SubjectKey, 'ActionKey', first.ActionKey, 'C', first.C, ...
        'Prefix', first.Prefix, 'Frames', sum([rows.Frames]), 'Sources', rows);
end
% 人数和 C 按数值排序，组合按完整标识排序。
ordering = table([trials.People].', string({trials.SubjectKey}).', ...
    string({trials.ActionKey}).', [trials.C].', 'VariableNames', {'N','H','A','C'});
[~, order] = sortrows(ordering, {'N','H','A','C'}); trials = trials(order);
end
