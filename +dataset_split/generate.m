function report = generate(trials, plan, options)
%GENERATE 按内存预算批量预读并划分；距离向量随输出文件一起保存。
% 覆盖模式不保留备份。所有输出先生成并校验，再替换原文件，删除旧分片。
language = options.Language;
if ~isfield(options, 'ProgressFcn'), options.ProgressFcn = []; end
if ~isfield(options, 'CancelFcn'), options.CancelFcn = []; end
if ~isfield(options, 'SpeedLevel'), options.SpeedLevel = 2; end
% 保留按帧限制的调用接口；界面通过速度档位自动确定批量大小。
if ~isfield(options, 'ChunkFrames'), options.ChunkFrames = Inf; end
if ~isfield(options, 'MappingDir')
    options.MappingDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'range_mapping');
end
[source, output] = dataset_split.paths(options.SourceRoot, options.OutputRoot, ...
    options.Overwrite, language);
memoryBudget = dataset_split.io_budget(options.SpeedLevel);
bufferedFiles = 0; chunkedFiles = 0; reusedFiles = 0;
cache = []; prefetchedTrials = 0; prefetchBatches = 0; sourceFileLoads = 0;
peakCacheBytes = 0; peakCacheTrials = 0;
rangeAxes = {};
if options.AddRange
    dataset_split.check_cancel(options.CancelFcn, language);
    notify('range_check', 0, 0, numel(trials), '');
    rangeAxes = dataset_split.range_axes(string({trials.Id}) + ".mat", options.MappingDir, language);
    for i = 1:numel(trials)
        first = trials(i).Sources(1);
        radar = first.Info(strcmp({first.Info.name}, 'radar_data_real'));
        if radar.size(1) ~= numel(rangeAxes{i})
            error('add_range_bin_to_mat:RangeSize', '%s', ...
                dataset_split.text(language, 'range_size', trials(i).Id));
        end
        if mod(i,20) == 0 || i == numel(trials)
            dataset_split.check_cancel(options.CancelFcn, language);
            notify('range_check', 0.03 * i / numel(trials), i, numel(trials), trials(i).Id);
        end
    end
end
parent = fileparts(output);
if ~isfolder(parent), mkdir(parent); end
estimate = 0;
for i = 1:numel(trials)
    estimate = estimate + sum([trials(i).Sources.Bytes]);
end
available = double(java.io.File(parent).getUsableSpace());
if available > 0 && available < estimate * 1.1
    error('dataset_split:space', '%s', dataset_split.text(language, 'space', estimate * 1.1 / 1e9));
end
stage = tempname(parent);
mkdir(stage);
cleanupState = containers.Map({'Keep'}, {false});
cleanup = onCleanup(@() cleanStage(stage, cleanupState));
prefixes = unique({trials.Prefix});
createLayout(stage);
outputFiles = {};
expectedCounts = [];
totalOutputs = sum(plan.TrainFrames > 0) + sum(plan.TestFrames > 0);
if strcmp(plan.Method, 'none'), totalOutputs = numel(trials); end
try
    for i = 1:numel(trials)
        dataset_split.check_cancel(options.CancelFcn, language);
        trial = trials(i);
        if strcmp(plan.Method, 'none')
            parts = {'full'}; starts = 1; counts = trial.Frames;
        else
            parts = {'train', 'test'};
            starts = [1, plan.TrainFrames(i) + 1];
            counts = [plan.TrainFrames(i), plan.TestFrames(i)];
        end
        % 精确覆盖一个原分片时直接复制；仍执行静态变量、源变化和输出校验。
        sourceStarts = [1, 1 + cumsum([trial.Sources(1:end-1).Frames])];
        reusable = zeros(size(counts));
        for p = 1:numel(parts)
            match = find(starts(p) == sourceStarts & counts(p) == [trial.Sources.Frames], 1);
            if ~isempty(match), reusable(p) = match; end
        end
        reuseTrial = all(reusable(counts > 0) > 0);
        if (isempty(cache) || i > cache.Last) && ~reuseTrial
            clear cache
            budget = min(memoryBudget, dataset_split.io_budget(options.SpeedLevel));
            cache = dataset_split.prefetch(trials, i, budget, source, language, ...
                options.ProgressFcn, options.CancelFcn, 0.03 + 0.92 * numel(outputFiles) / totalOutputs);
            count = cache.Last - cache.First + 1;
            prefetchedTrials = prefetchedTrials + count;
            prefetchBatches = prefetchBatches + (count > 0);
            sourceFileLoads = sourceFileLoads + cache.SourceFiles;
            peakCacheBytes = max(peakCacheBytes, cache.Bytes);
            peakCacheTrials = max(peakCacheTrials, count);
        end
        % 即便已缓存，也在使用前再次核对源文件，保留原有的并发修改保护。
        dataset_split.check_sources(trial, source, language);
        cached = ~isempty(cache) && i >= cache.First && i <= cache.Last;
        if cached
            sourceObjects = cache.Entries{i - cache.First + 1};
        else
            sourceObjects = cell(numel(trial.Sources), 1);
            for s = 1:numel(trial.Sources)
                sourceObjects{s} = matfile(trial.Sources(s).Path);
            end
        end
        % 静态变量保持原值；range_bin 完全由本次复选框控制，不作为帧数据拼接。
        first = trial.Sources(1);
        staticNames = setdiff({first.Info.name}, [first.FrameVars, {'range_bin'}]);
        metadata = struct();
        if ~isempty(staticNames)
            if cached, metadata = rmfield(sourceObjects{1}, first.FrameVars);
            else, metadata = load(first.Path, staticNames{:}); end
        end
        for s = 2:numel(trial.Sources)
            if isempty(staticNames), break; end
            if cached, other = rmfield(sourceObjects{s}, first.FrameVars);
            else, other = load(trial.Sources(s).Path, staticNames{:}); end
            for v = 1:numel(staticNames)
                name = staticNames{v};
                if ~isequaln(metadata.(name), other.(name))
                    error('dataset_split:static_mismatch', '%s', ...
                        dataset_split.text(language, 'static_mismatch', trial.Id, name));
                end
            end
        end
        frameInfo = first.Info(ismember({first.Info.name}, first.FrameVars));
        fastNumeric = true;
        complexNames = {};
        for s = 1:numel(trial.Sources)
            items = trial.Sources(s).Info(ismember({trial.Sources(s).Info.name}, first.FrameVars));
            fastNumeric = fastNumeric && ~any([items.complex]) && ~any([items.sparse]);
            complexNames = union(complexNames, {items([items.complex]).name});
        end
        bytesPerFrame = sum([frameInfo.bytes]) / first.Frames;
        largestFrame = max([frameInfo.bytes]) / first.Frames;
        staticBytes = sum([first.Info(ismember({first.Info.name}, staticNames)).bytes]);
        if cached
            % 预读批次已为输出数组与保存过程预留空间；扣除仍存活的全部缓存。
            payloadBudget = max(1, (cache.BudgetBytes - cache.Bytes) / 2 - staticBytes);
        else
            % 放不下完整试次时仍采用低内存分块路径。
            payloadBudget = max(1, min(memoryBudget, dataset_split.io_budget(options.SpeedLevel)) / 3 - staticBytes);
        end
        chunkFrames = min(options.ChunkFrames, max(1, floor(payloadBudget / largestFrame)));
        for p = 1:numel(parts)
            if counts(p) == 0, continue; end
            if strcmp(parts{p}, 'full')
                relative = fullfile(trial.Prefix, 'radardata', [trial.Id, '.mat']);
            else
                relative = fullfile(trial.Prefix, parts{p}, 'radardata', ...
                    [trial.Id, '_', parts{p}, '.mat']);
            end
            targetPath = fullfile(stage, relative);
            initial = metadata;
            if options.AddRange
                initial.range_bin = rangeAxes{i};
                notify('range_add', 0.03 + 0.92 * numel(outputFiles) / totalOutputs, ...
                    numel(outputFiles) + 1, totalOutputs, trial.Id);
            end
            buffered = counts(p) * bytesPerFrame <= payloadBudget && counts(p) <= options.ChunkFrames;
            if reusable(p) > 0
                axis = [];
                if options.AddRange, axis = rangeAxes{i}; end
                copyFragment(trial.Sources(reusable(p)), targetPath, options.AddRange, axis);
                reusedFiles = reusedFiles + 1;
            elseif fastNumeric
                writeChunk = chunkFrames;
                if buffered, writeChunk = counts(p); end
                read = @(name, begin, n) assembleVariable(trial.Sources, sourceObjects, ...
                    name, first.Info(strcmp({first.Info.name}, name)), starts(p) + begin - 1, n, language);
                update = @(fraction) notify('write', ...
                    0.03 + 0.92 * (numel(outputFiles) + 0.9 * fraction) / totalOutputs, ...
                    numel(outputFiles) + 1, totalOutputs, trial.Id);
                dataset_split.write_numeric(targetPath, initial, frameInfo, counts(p), ...
                    writeChunk, read, update, options.CancelFcn, language);
                % 匿名函数持有源缓存引用，必须在下一批预读前释放。
                clear read update
                bufferedFiles = bufferedFiles + buffered;
                chunkedFiles = chunkedFiles + ~buffered;
            elseif buffered
                % 输出能放入预算时，在内存中拼接后一次性压缩保存，减少 HDF5 操作。
                for v = 1:numel(first.FrameVars)
                    dataset_split.check_cancel(options.CancelFcn, language);
                    name = first.FrameVars{v};
                    info = first.Info(strcmp({first.Info.name}, name));
                    initial.(name) = assembleVariable(trial.Sources, sourceObjects, ...
                        name, info, starts(p), counts(p), language);
                    notify('write', 0.03 + 0.92 * (numel(outputFiles) + 0.9 * v / numel(first.FrameVars)) / totalOutputs, ...
                        numel(outputFiles) + 1, totalOutputs, trial.Id);
                end
                dataset_split.check_cancel(options.CancelFcn, language);
                save(targetPath, '-struct', 'initial', '-v7.3');
                bufferedFiles = bufferedFiles + 1;
            else
                % 大文件采用自适应大块读写，每个源文件对象在整个试次中复用。
                for v = 1:numel(first.FrameVars)
                    name = first.FrameVars{v};
                    info = first.Info(strcmp({first.Info.name}, name));
                    zero = cast(0, info.class);
                    if ismember(name, complexNames)
                        % 非零虚部确保模板保存为复数；多帧模板保留第三维供 matfile 索引。
                        % 模板中的占位值将在后续分块写入中全部覆盖。
                        initial.(name) = repmat(complex(zero), [info.size(1:2), min(2, counts(p))]);
                        initial.(name)(1) = complex(zero, cast(1, info.class));
                    else
                        initial.(name) = repmat(zero, [info.size(1:2), 0]);
                    end
                end
                save(targetPath, '-struct', 'initial', '-v7.3');
                target = matfile(targetPath, 'Writable', true);
                for v = 1:numel(first.FrameVars)
                    name = first.FrameVars{v};
                    info = first.Info(strcmp({first.Info.name}, name));
                    zero = cast(0, info.class);
                    % matfile 的实数数据集不能接收复数块，预分配时保留复数表示。
                    if ismember(name, complexNames), zero = complex(zero); end
                    if counts(p) == 1 && ismember(name, complexNames)
                        target.(name)(info.size(1), info.size(2)) = zero;
                    else
                        target.(name)(info.size(1), info.size(2), counts(p)) = zero;
                    end
                end
                written = 0;
                for begin = starts(p):chunkFrames:starts(p) + counts(p) - 1
                    dataset_split.check_cancel(options.CancelFcn, language);
                    finish = min(begin + chunkFrames - 1, starts(p) + counts(p) - 1);
                    sourceOffset = 0;
                    for s = 1:numel(trial.Sources)
                        fragment = trial.Sources(s);
                        firstFrame = max(begin, sourceOffset + 1);
                        lastFrame = min(finish, sourceOffset + fragment.Frames);
                        if firstFrame <= lastFrame
                            sourceIndices = firstFrame - sourceOffset:lastFrame - sourceOffset;
                            destinationIndices = firstFrame - starts(p) + 1:lastFrame - starts(p) + 1;
                            for v = 1:numel(first.FrameVars)
                                name = first.FrameVars{v};
                                block = readFrames(sourceObjects{s}, name, fragment.Frames, sourceIndices);
                                if counts(p) == 1
                                    target.(name)(:, :) = block;
                                else
                                    target.(name)(:, :, destinationIndices) = block;
                                end
                                clear block
                            end
                            written = written + numel(sourceIndices);
                        end
                        sourceOffset = sourceOffset + fragment.Frames;
                    end
                    notify('write', 0.03 + 0.92 * (numel(outputFiles) + ...
                        0.9 * (finish - starts(p) + 1) / counts(p)) / totalOutputs, ...
                        numel(outputFiles) + 1, totalOutputs, trial.Id);
                end
                if written ~= counts(p)
                    error('dataset_split:verification', '%s', dataset_split.text(language, 'verification', trial.Id));
                end
                chunkedFiles = chunkedFiles + 1;
                clear target
            end
            clear initial
            saved = whos('-file', targetPath);
            for v = 1:numel(first.FrameVars)
                info = saved(strcmp({saved.name}, first.FrameVars{v}));
                dims = [info.size, ones(1, max(0, 3 - numel(info.size)))];
                original = first.Info(strcmp({first.Info.name}, first.FrameVars{v}));
                if ~isequal(dims, [original.size(1:2), counts(p)]) || ~strcmp(info.class, original.class)
                    error('dataset_split:verification', '%s', dataset_split.text(language, 'verification', trial.Id));
                end
            end
            if options.AddRange
                stored = load(targetPath, 'range_bin');
                if ~isequal(stored.range_bin, rangeAxes{i})
                    error('add_range_bin_to_mat:WriteVerification', '%s', ...
                        dataset_split.text(language, 'range_verify', trial.Id));
                end
            end
            outputFiles{end + 1, 1} = relative; %#ok<AGROW>
            expectedCounts(end + 1, 1) = counts(p); %#ok<AGROW>
            notify('write', 0.03 + 0.92 * numel(outputFiles) / totalOutputs, ...
                numel(outputFiles), totalOutputs, trial.Id);
        end
        if cached
            row = i - cache.First + 1;
            cache.Entries{row} = []; cache.Bytes = cache.Bytes - cache.Sizes(row);
        end
        clear sourceObjects
    end
    % 全片段读取完成后再次核对源文件，阻止并发修改造成不一致的覆盖结果。
    for i = 1:numel(trials)
        for s = 1:numel(trials(i).Sources)
            fragment = trials(i).Sources(s); now = dir(fragment.Path);
            if isempty(now) || now.bytes ~= fragment.Bytes || now.datenum ~= fragment.Date
                error('dataset_split:changed', '%s', dataset_split.text(language, 'changed', trials(i).Id));
            end
        end
    end
    dataset_split.check_cancel(options.CancelFcn, language);
    notify('commit', 0.95, 0, numel(outputFiles), '');
    cleanupState('Keep') = true; % 替换失败时保留尚未安装的临时生成结果。
    createLayout(output);
    for i = 1:numel(outputFiles)
        destination = fullfile(output, outputFiles{i});
        if isfile(destination) && ~options.Overwrite
            error('dataset_split:output_busy', '%s', dataset_split.text(language, 'output_busy', output));
        end
        movefile(fullfile(stage, outputFiles{i}), destination, 'f');
        notify('commit', 0.95 + 0.05 * i / numel(outputFiles), i, numel(outputFiles), '');
    end
    if options.Overwrite
        newPaths = string(fullfile(output, outputFiles));
        oldFolders = {};
        for i = 1:numel(trials)
            for s = 1:numel(trials(i).Sources)
                old = trials(i).Sources(s).Path;
                oldFolders{end + 1} = fileparts(old); %#ok<AGROW>
                if ~ismember(string(old), newPaths), delete(old); end
            end
        end
        if strcmp(plan.Method, 'none')
            for folder = unique(oldFolders)
                removeEmpty(folder{1});
                removeEmpty(fileparts(folder{1}));
            end
        end
    end
    cleanupState('Keep') = false; %#ok<NASGU> % onCleanup 读取同一个 Map 句柄的状态。
catch ME
    if cleanupState('Keep')
        error('dataset_split:commit_failed', '%s', ...
            dataset_split.text(language, 'commit_failed', stage, ME.identifier));
    end
    rethrow(ME);
end
report = struct('OutputRoot', output, 'NumFiles', numel(outputFiles), ...
    'TotalFrames', sum(expectedCounts), 'TrainFrames', sum(plan.TrainFrames), ...
    'TestFrames', sum(plan.TestFrames), 'MemoryBudgetBytes', memoryBudget, ...
    'BufferedFiles', bufferedFiles, 'ChunkedFiles', chunkedFiles, 'ReusedFiles', reusedFiles, ...
    'PrefetchedTrials', prefetchedTrials, 'PrefetchBatches', prefetchBatches, ...
    'PrefetchSourceFiles', sourceFileLoads, 'PeakCacheBytes', peakCacheBytes, ...
    'PeakCacheTrials', peakCacheTrials);

    function createLayout(root)
        for prefix = prefixes
            if strcmp(plan.Method, 'none')
                layoutDir = fullfile(root, prefix{1}, 'radardata');
                if ~isfolder(layoutDir), mkdir(layoutDir); end
            else
                for part = {'train','test'}
                    layoutDir = fullfile(root, prefix{1}, part{1}, 'radardata');
                    if ~isfolder(layoutDir), mkdir(layoutDir); end
                end
            end
        end
    end
    function notify(phase, fraction, current, total, name)
        if ~isempty(options.ProgressFcn)
            options.ProgressFcn(struct('Phase', phase, 'Fraction', fraction, ...
                'Current', current, 'Total', total, 'Name', name));
        end
    end
end

function value = assembleVariable(fragments, objects, name, info, firstFrame, count, language)
% 每个输出只分配一次数组，跨原 train/test 边界时按帧填充。
offset = 0;
for s = 1:numel(fragments)
    if firstFrame > offset && firstFrame + count - 1 <= offset + fragments(s).Frames
        value = readFrames(objects{s}, name, fragments(s).Frames, ...
            firstFrame - offset:firstFrame - offset + count - 1);
        return;
    end
    offset = offset + fragments(s).Frames;
end
value = repmat(cast(0, info.class), [info.size(1:2), count]);
offset = 0; written = 0;
for s = 1:numel(fragments)
    begin = max(firstFrame, offset + 1);
    finish = min(firstFrame + count - 1, offset + fragments(s).Frames);
    if begin <= finish
        sourceIndices = begin - offset:finish - offset;
        destinationIndices = begin - firstFrame + 1:finish - firstFrame + 1;
        value(:,:,destinationIndices) = readFrames(objects{s}, name, fragments(s).Frames, sourceIndices);
        written = written + numel(sourceIndices);
    end
    offset = offset + fragments(s).Frames;
end
if written ~= count
    error('dataset_split:verification', '%s', dataset_split.text(language, 'verification', name));
end
end

function value = readFrames(object, name, frames, indices)
% 单帧变量省略末尾单例维；matfile 必须用实际维数索引。
if isstruct(object) && numel(indices) == frames
    value = object.(name);
elseif frames == 1
    value = object.(name)(:,:);
else
    value = object.(name)(:,:,indices);
end
end

function copyFragment(fragment, targetPath, addRange, axis)
% 复制到临时目录后只调整可选距离变量，原始压缩数据无需解压或重编码。
copyfile(fragment.Path, targetPath);
fileattrib(targetPath, '+w');
if ismember('range_bin', {fragment.Info.name})
    file = H5F.open(targetPath, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(file));
    H5L.delete(file, 'range_bin', 'H5P_DEFAULT');
    clear cleanup
end
if addRange
    data = struct('range_bin', axis);
    save(targetPath, '-struct', 'data', '-append');
end
end

function cleanStage(stage, context)
if ~context('Keep') && isfolder(stage), rmdir(stage, 's'); end
end

function removeEmpty(folder)
if isfolder(folder)
    contents = dir(folder);
    if ~any(~ismember({contents.name}, {'.', '..'})), rmdir(folder); end
end
end
