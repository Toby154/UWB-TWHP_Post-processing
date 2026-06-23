%% 读取光学动捕数据，并保存每帧关节点 / Read optical mocap data & save per-frame joint positions
function [positionMatrix, BodyID] = NOKOV_json_read(jsonFile, radar_x, radar_y)
    % 读取JSON数据 / Read JSON data
    fid = fopen(jsonFile);
    rawData = fread(fid, inf, '*char')';
    fclose(fid);
    data = jsondecode(rawData);

    % 主要关节点定义 / Main joint definitions
    mainJoints = {
        'Head', 'Neck', 'Spine', 'Spine3', ...
        'LeftArm', 'LeftForeArm', 'LeftHand', ...
        'RightArm', 'RightForeArm', 'RightHand', ...
        'LeftUpLeg', 'LeftLeg', 'LeftFoot', ...
        'RightUpLeg', 'RightLeg', 'RightFoot'
    };

    % 预处理 / Preprocessing
    maxBodies = max(arrayfun(@(f) numel(f.data), data));
    totalFrames = numel(data);
    totalJoints = numel(mainJoints);

    % 正则预编译加速 / Precompile regex patterns for speed
    bodyPattern = 'Body\d+';  % 使用标准的正则表达式字符串 / Standard regex string
    numPattern = '\d+';       % 匹配数字部分的正则表达式 / Regex to match numeric part

    % 预分配内存 / Pre-allocate memory
    BodyID = nan(totalFrames, maxBodies);
    positionMatrix = nan(maxBodies, totalJoints*3, totalFrames);

    for f = 1:totalFrames

        frameData = data(f).data;
        numBodies = numel(frameData);

        % 提取BodyID / Extract body IDs
        if numBodies > 0
            bodyNames = {frameData.avatarName};
            idStrs = regexp(bodyNames, numPattern, 'match', 'once');
            validIDs = str2double(idStrs);
            BodyID(f, 1:numBodies) = validIDs;
        end

        for b = 1:numel(frameData)
            body = data(f).data(b);
            jointPos = zeros(numel(mainJoints), 3);

            % 向量化坐标提取 / Vectorized coordinate extraction
            validJoints = isfield(body, mainJoints);
            for j = find(validJoints)
                pos = body.(mainJoints{j}).pos;
                jointPos(j,:) = [pos(1), pos(3), pos(2)]; % XYZ -> XZY (coordinate system conversion)
            end
            jointPos(~validJoints,:) = nan;

            % 调整坐标（转换至雷达坐标系） / Transform to radar-centric coordinate system
            jointPos(:,1) = -jointPos(:,1) - radar_x;
            jointPos(:,2) = jointPos(:,2) - radar_y;

            % 存入矩阵 / Store into position matrix
            positionMatrix(b, :, f) = squeeze(reshape(jointPos,1,totalJoints*3));
        end
    end
end