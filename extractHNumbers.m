function num_values = extractHNumbers(str)
    % 使用正则表达式提取所有数字 / Extract all numbers using regex
    numbers = regexp(str, '\d+', 'match');
    % 将字符串数组转换为数值数组 / Convert string array to numeric array
    num_values = str2double(numbers);
end