function outStr = letterVarCombine(letter, var)
    % 检查 var 是否为数值向量或标量 / Check if var is a numeric scalar or vector
    if isscalar(var)
        % 如果是标量，直接字母加数值 / Scalar: letter + number
        outStr = [letter, num2str(var)];
    elseif isvector(var)
        % 如果是向量，需要用 '-' 连接每个元素 / Vector: join elements with '-'
        % 把每个元素转为字符串 / Convert each element to string
        elemStrs = arrayfun(@num2str, var, 'UniformOutput', false);
        % 用 '-' 连接 / Join with '-'
        outStr = [letter, strjoin(elemStrs, '-')];
    else
        error('输入的变量必须是数值或数值向量 / Input must be a numeric scalar or vector');
    end
end