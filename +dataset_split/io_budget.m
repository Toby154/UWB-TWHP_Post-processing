function bytes = io_budget(level, availableBytes)
%IO_BUDGET 速度档位的缓冲预算；最多使用当前可用物理内存的四分之一。
% 预算包含为读取临时数组及保存过程预留的空间，不代表 MATLAB 总内存上限。
validateattributes(level, {'numeric'}, {'scalar','integer','>=',1,'<=',4});
limits = [64,256,1024,4096] * 1024^2;
if nargin < 2, availableBytes = availableMemory(); end
bytes = min(limits(level), max(1, floor(availableBytes / 4)));
end

function bytes = availableMemory()
% 无额外工具箱；无法读取硬件信息时退回保守预算。
bytes = 256 * 1024^2;
if ispc
    [~, system] = memory;
    bytes = double(system.PhysicalMemory.Available);
elseif isfile('/proc/meminfo')
    info = fileread('/proc/meminfo');
    token = regexp(info, 'MemAvailable:\s*(\d+)\s*kB', 'tokens', 'once');
    if ~isempty(token), bytes = str2double(token{1}) * 1024; end
elseif usejava('jvm')
    bean = java.lang.management.ManagementFactory.getOperatingSystemMXBean();
    if ismethod(bean, 'getFreePhysicalMemorySize')
        free = double(bean.getFreePhysicalMemorySize());
        if free > 0, bytes = free; end
    end
end
end
