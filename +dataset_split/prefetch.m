function cache = prefetch(trials, firstIndex, budget, root, language, progressFcn, cancelFcn, fraction)
%PREFETCH 串行批量预读完整试次，每个分片一次加载全部所需变量。
% 缓存总量 + 最大试次的两倍 <= 预算，额外空间供输出切片、拼接和压缩保存使用。
remaining = numel(trials) - firstIndex + 1;
cache = struct('First', firstIndex, 'Last', firstIndex - 1, ...
    'Entries', {cell(remaining,1)}, 'Sizes', zeros(remaining,1), ...
    'Bytes', 0, 'Largest', 0, 'BudgetBytes', budget, 'SourceFiles', 0);
for i = firstIndex:numel(trials)
    dataset_split.check_cancel(cancelFcn, language);
    trial = trials(i); bytes = 0;
    for s = 1:numel(trial.Sources)
        info = trial.Sources(s).Info;
        bytes = bytes + sum([info(~strcmp({info.name}, 'range_bin')).bytes]);
    end
    largest = max(cache.Largest, bytes);
    if cache.Bytes + bytes + 2 * largest > budget, break; end
    dataset_split.check_sources(trial, root, language);
    notify(i);
    fragments = cell(numel(trial.Sources), 1);
    for s = 1:numel(trial.Sources)
        dataset_split.check_cancel(cancelFcn, language);
        fragment = trial.Sources(s);
        names = setdiff({fragment.Info.name}, {'range_bin'});
        % load 一次读取整个分片，避免 train/test 输出各自反复解压相同的 HDF5 块。
        fragments{s} = load(fragment.Path, names{:});
    end
    dataset_split.check_sources(trial, root, language);
    row = i - firstIndex + 1;
    cache.Entries{row} = fragments; cache.Sizes(row) = bytes;
    cache.Bytes = cache.Bytes + bytes; cache.Largest = largest;
    cache.Last = i; cache.SourceFiles = cache.SourceFiles + numel(fragments);
    clear fragments
    notify(i);
end

    function notify(index)
        if ~isempty(progressFcn)
            progressFcn(struct('Phase','prefetch','Fraction',fraction, ...
                'Current',index,'Total',numel(trials),'Name',trials(index).Id, ...
                'CacheTrials',cache.Last - cache.First + 1,'CacheBytes',cache.Bytes));
        end
    end
end
