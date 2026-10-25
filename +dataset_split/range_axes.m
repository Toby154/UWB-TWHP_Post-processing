function [axes, axisFileNames] = range_axes(fileNames, mappingDir, language)
%RANGE_AXES 按完整试次标识解析距离表；每份 CSV 只读取一次。
% train/test 分片和完整 MAT 文件共用不含后缀及扩展名的同一个键。
fileNames = string(fileNames(:));
trialKeys = regexprep(fileNames, '(_train|_test)?\.mat$', '');
lookup = readtable(fullfile(mappingDir, 'file_range_lookup.csv'), ...
    'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
if ~all(ismember({'file_name','range_axis_file'}, lookup.Properties.VariableNames))
    error('add_range_bin_to_mat:LookupColumns', '%s', dataset_split.text(language, 'range_columns'));
end
if numel(unique(lookup.file_name)) ~= height(lookup)
    error('add_range_bin_to_mat:DuplicateLookup', '%s', dataset_split.text(language, 'range_duplicates'));
end
% 精确比较整个标识，避免 C1 误匹配到 C10 等其他试次。
[found, rows] = ismember(trialKeys, lookup.file_name);
if ~all(found)
    missing = fileNames(~found);
    error('add_range_bin_to_mat:MissingMapping', '%s', ...
        dataset_split.text(language, 'range_missing', missing(1), numel(missing)));
end
axisFileNames = lookup.range_axis_file(rows);
if any(ismissing(axisFileNames) | strlength(axisFileNames) == 0)
    error('add_range_bin_to_mat:UnresolvedMapping', '%s', dataset_split.text(language, 'range_unresolved'));
end
[uniqueFiles, ~, index] = unique(axisFileNames);
values = cell(numel(uniqueFiles), 1);
for i = 1:numel(uniqueFiles)
    axis = readmatrix(fullfile(mappingDir, uniqueFiles(i)));
    if ~isvector(axis) || any(~isfinite(axis(:))) || any(diff(axis(:)) <= 0)
        error('add_range_bin_to_mat:InvalidAxis', '%s', ...
            dataset_split.text(language, 'range_invalid', uniqueFiles(i)));
    end
    values{i} = double(axis(:));
end
axes = values(index);
end
