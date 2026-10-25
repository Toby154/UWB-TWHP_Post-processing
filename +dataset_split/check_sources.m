function check_sources(trial, root, language)
%CHECK_SOURCES 在预读和使用缓存前核对源路径、大小和修改时间。
for s = 1:numel(trial.Sources)
    fragment = trial.Sources(s);
    if ~startsWith(fragment.Path, [root, filesep])
        error('dataset_split:bad_file', '%s', dataset_split.text(language, 'bad_file', trial.Id));
    end
    current = dir(fragment.Path);
    if isempty(current) || current.bytes ~= fragment.Bytes || current.datenum ~= fragment.Date
        error('dataset_split:changed', '%s', dataset_split.text(language, 'changed', trial.Id));
    end
end
end
