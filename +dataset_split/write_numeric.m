function write_numeric(path, initial, info, count, chunkFrames, readFcn, progressFcn, cancelFcn, language)
%WRITE_NUMERIC 写入自包含的 v7.3 MAT；仅用于稠密实数/逻辑帧变量。
% save 生成标准文件头和类型属性；帧数组使用无损 shuffle + deflate(3)。
% readFcn(variable, firstFrame, count) 的帧编号相对于当前输出文件。
for v = 1:numel(info)
    initial.(info(v).name) = cast(0, info(v).class);
end
save(path, '-struct', 'initial', '-v7.3');
clear initial
file = H5F.open(path, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
fileCleanup = onCleanup(@() H5F.close(file));
for v = 1:numel(info)
    dataset_split.check_cancel(cancelFcn, language);
    item = info(v);
    dims = [item.size(1:2), count];
    if count == 1, dims = dims(1:2); end
    dataset = createArray(file, item.name, dims, item.bytes / prod(item.size));
    datasetCleanup = onCleanup(@() H5D.close(dataset));
    fileSpace = H5D.get_space(dataset);
    spaceCleanup = onCleanup(@() H5S.close(fileSpace));
    for firstFrame = 1:chunkFrames:count
        dataset_split.check_cancel(cancelFcn, language);
        n = min(chunkFrames, count - firstFrame + 1);
        block = readFcn(item.name, firstFrame, n);
        blockDims = [dims(1:2), n]; offset = [0, 0, firstFrame - 1];
        if count == 1, blockDims = blockDims(1:2); offset = offset(1:2); end
        memorySpace = H5S.create_simple(numel(blockDims), fliplr(blockDims), []);
        memoryCleanup = onCleanup(@() H5S.close(memorySpace));
        H5S.select_hyperslab(fileSpace, 'H5S_SELECT_SET', fliplr(offset), [], [], fliplr(blockDims));
        % logical 在 MAT 的 HDF5 层以 uint8 存储；MATLAB_class 属性保留其逻辑类型。
        if islogical(block), block = uint8(block); end
        H5D.write(dataset, 'H5ML_DEFAULT', memorySpace, fileSpace, 'H5P_DEFAULT', block);
        clear block memoryCleanup
        progressFcn(((v - 1) + (firstFrame + n - 1) / count) / numel(info));
    end
    clear spaceCleanup datasetCleanup
end
end

function dataset = createArray(file, name, dims, bytesPerElement)
% 从 save 生成的标量复制类型及全部属性，避免手工重建 MATLAB 类型约定。
prototype = H5D.open(file, name);
prototypeCleanup = onCleanup(@() H5D.close(prototype));
type = H5D.get_type(prototype);
typeCleanup = onCleanup(@() H5T.close(type));
H5L.delete(file, name, 'H5P_DEFAULT');
maximum = repmat(H5ML.get_constant_value('H5S_UNLIMITED'), size(dims));
space = H5S.create_simple(numel(dims), fliplr(dims), maximum);
spaceCleanup = onCleanup(@() H5S.close(space));
properties = H5P.create('H5P_DATASET_CREATE');
propertiesCleanup = onCleanup(@() H5P.close(properties));
% 雷达以帧为单位；较小的标签变量在同一块中保存多帧，避免大量微小压缩块。
chunk = dims; chunk(3:end) = 1;
while prod(chunk) * bytesPerElement > 128 * 1024
    [~, axis] = max(chunk(1:2)); chunk(axis) = ceil(chunk(axis) / 2);
end
if numel(chunk) == 3
    chunk(3) = min(dims(3), max(1, floor(128 * 1024 / (prod(chunk(1:2)) * bytesPerElement))));
end
H5P.set_chunk(properties, fliplr(chunk));
H5P.set_shuffle(properties);
H5P.set_deflate(properties, 3);
dataset = H5D.create(file, name, type, space, properties);
% H5ML.id 自带关闭机制；异常时尚未返回的 dataset 也会被释放。
attributes = H5O.get_info(prototype);
for a = 0:attributes.num_attrs - 1
    source = H5A.open_by_idx(prototype, '.', 'H5_INDEX_NAME', 'H5_ITER_INC', a);
    sourceCleanup = onCleanup(@() H5A.close(source));
    attrType = H5A.get_type(source); attrSpace = H5A.get_space(source);
    attrTypeCleanup = onCleanup(@() H5T.close(attrType));
    attrSpaceCleanup = onCleanup(@() H5S.close(attrSpace));
    target = H5A.create(dataset, H5A.get_name(source), attrType, attrSpace, 'H5P_DEFAULT');
    targetCleanup = onCleanup(@() H5A.close(target));
    H5A.write(target, attrType, H5A.read(source, attrType));
    clear targetCleanup attrSpaceCleanup attrTypeCleanup sourceCleanup
end
end
