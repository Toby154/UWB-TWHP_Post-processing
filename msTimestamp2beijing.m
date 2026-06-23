function beijingTime = msTimestamp2beijing(msTimestamp)
% 将毫秒级时间戳转换为北京时间字符串 / Convert millisecond Unix timestamp to Beijing time string
% 输入 / Input：毫秒级时间戳（自1970-01-01 00:00:00 UTC以来的毫秒数） / ms since 1970-01-01 00:00:00 UTC
% 输出 / Output：北京时间字符串，格式为 'yyyy-MM-dd HH:mm:ss.SSS' / Beijing time string in 'yyyy-MM-dd HH:mm:ss.SSS'

    % 将毫秒时间戳转换为秒（带小数部分） / Convert ms timestamp to seconds (with fractional part)
    secondsTimestamp = double(msTimestamp) / 1000;

    % 将时间戳转换为UTC时间的datetime对象 / Convert to UTC datetime object
    dtUTC = datetime(secondsTimestamp, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');

    % 转换为北京时间（UTC+8） / Convert to Beijing time (UTC+8)
    dtUTC.TimeZone = 'Asia/Shanghai';

    % 格式化为字符串（精确到毫秒） / Format to string (millisecond precision)
    beijingTime = datestr(dtUTC, 'yyyy-mm-dd HH:MM:SS.FFF');
end