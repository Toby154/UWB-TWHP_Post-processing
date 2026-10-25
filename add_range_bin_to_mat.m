function report = add_range_bin_to_mat(datasetRoot, mappingDir, dryRun, progressFcn, language)
%ADD_RANGE_BIN_TO_MAT 按公开查找表向已有 v7.3 MAT 文件追加 range_bin。
% 查找表按不含 _train/_test 后缀及 .mat 扩展名的完整试次标识匹配。
% range_bin 为 N×1 double，单位为米，表示各距离单元的双基地总路径距离。
% 用法：add_range_bin_to_mat(datasetRoot)
% 仅检查：add_range_bin_to_mat(datasetRoot, mappingDir, true)
% 全量预检查通过后仅追加新变量；已有且一致的变量跳过，不覆盖不一致值。
% 可选第 4、5 参数为进度回调和语言（'zh'/'en'），供划分界面统一显示进度。

if nargin < 4, progressFcn = []; end
if nargin < 5, language = 'en'; end
if nargin < 1 || ~isfolder(datasetRoot)
    error('add_range_bin_to_mat:DatasetRoot', '%s', dataset_split.text(language, 'range_root'));
end
if nargin < 2 || isempty(mappingDir)
    mappingDir = fullfile(fileparts(mfilename('fullpath')), 'range_mapping');
end
if nargin < 3
    dryRun = false;
end

files = dir(fullfile(datasetRoot, '**', '*.mat'));
[fileNames, order] = sort(string({files.name}).');
files = files(order);
if isempty(files)
    error('add_range_bin_to_mat:NoFiles', '%s', dataset_split.text(language, 'no_files'));
end
if numel(unique(fileNames)) ~= numel(files)
    error('add_range_bin_to_mat:DuplicateFiles', '%s', dataset_split.text(language, 'file_duplicates'));
end
[axes, axisFileNames] = dataset_split.range_axes(fileNames, mappingDir, language);
needsWrite = false(numel(files), 1);
filePaths = string(fullfile({files.folder}, {files.name})).';

% 先检查全部目标，避免处理到后面才发现映射缺失、尺寸错误或已有值冲突。
fprintf('%s', dataset_split.text(language, 'range_check_start', numel(files)));
for i = 1:numel(files)
    notify('range_check', 0.3 * i / numel(files), i);
    if ~H5F.is_hdf5(filePaths(i))
        error('add_range_bin_to_mat:MatVersion', '%s', dataset_split.text(language, 'range_version', fileNames(i)));
    end
    info = whos('-file', filePaths(i));
    names = {info.name};
    if ~all(ismember({'radar_data_real', 'radar_data_imag'}, names))
        error('add_range_bin_to_mat:RadarVariables', '%s', dataset_split.text(language, 'range_variables', fileNames(i)));
    end
    realInfo = info(strcmp(names, 'radar_data_real'));
    imagInfo = info(strcmp(names, 'radar_data_imag'));
    if ~isequal(realInfo.size, imagInfo.size) || ...
            realInfo.size(1) ~= numel(axes{i})
        error('add_range_bin_to_mat:RangeSize', '%s', dataset_split.text(language, 'range_size', fileNames(i)));
    end
    if ismember('range_bin', names)
        existing = load(filePaths(i), 'range_bin');
        if ~isequal(existing.range_bin, axes{i})
            error('add_range_bin_to_mat:ExistingConflict', ...
                '%s', dataset_split.text(language, 'range_conflict', fileNames(i)));
        end
    else
        needsWrite(i) = true;
    end
end

status = repmat("already_present", numel(files), 1);
status(needsWrite) = "would_add";
if ~dryRun
    for i = find(needsWrite).'
        notify('range_add', 0.3 + 0.7 * (i - 1) / numel(files), i);
        % v7.3 的按变量写入不需要加载或重写体积庞大的雷达、姿态数组。
        target = matfile(filePaths(i), 'Writable', true);
        target.range_bin = axes{i};
        written = load(filePaths(i), 'range_bin');
        if ~isequal(written.range_bin, axes{i})
            error('add_range_bin_to_mat:WriteVerification', '%s', dataset_split.text(language, 'range_verify', fileNames(i)));
        end
        status(i) = "added";
    end
end
report = table(fileNames, axisFileNames, status, ...
    'VariableNames', {'file_name', 'range_axis_file', 'status'});
notify('range_add', 1, numel(files));
fprintf('%s', dataset_split.text(language, 'range_finished', ...
    sum(status == "added"), sum(status == "already_present"), sum(status == "would_add")));

    function notify(phase, fraction, current)
        if ~isempty(progressFcn)
            progressFcn(struct('Phase', phase, 'Fraction', fraction, ...
                'Current', current, 'Total', numel(files), 'Name', char(fileNames(current))));
        end
    end
end
