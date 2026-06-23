function abnormalFrames = detectAbnormalFramesVectorized(positionMatrix)
    % 创建异常值掩码（动捕丢帧时坐标值约为 ±9999.999）
    % Create outlier mask (mocap dropout marker values are approx. ±9999.999)
    abnormalMask = abs(abs(positionMatrix) - 9999.999) < 100;
    % 检查每个人的所有坐标是否都是异常值 / Check if all coordinates of a person are abnormal
    personAbnormal = all(abnormalMask, 2); % 在坐标维度上取all / all across coordinate dimension
    % 检查每帧中是否有至少一个人异常 / Check if at least one person is abnormal in each frame
    frameAbnormal = any(personAbnormal, 1); % 在人数维度上取any / any across person dimension
    % 压缩维度并获取异常帧号 / Squeeze dimensions and get abnormal frame indices
    frameAbnormal = squeeze(frameAbnormal);
    abnormalFrames = find(frameAbnormal);
    % 输出结果 / Output results
    if isempty(abnormalFrames)
        fprintf('未发现异常帧。 / No abnormal frames detected.\n');
    else
        fprintf('发现 %d 个异常帧：%s / %d abnormal frame(s) found: %s\n', length(abnormalFrames), mat2str(abnormalFrames), length(abnormalFrames), mat2str(abnormalFrames));
    end
end