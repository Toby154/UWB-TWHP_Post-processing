function [source, output] = paths(source, output, overwrite, language)
%PATHS 规范化路径，阻止非覆盖模式下目录交叠和写入非空输出。
if ~isfolder(source)
    error('dataset_split:bad_source', '%s', dataset_split.text(language, 'bad_source'));
end
source = char(java.io.File(char(source)).getCanonicalPath());
if overwrite
    output = source;
    return;
end
if strlength(string(output)) == 0
    error('dataset_split:bad_output', '%s', dataset_split.text(language, 'bad_output'));
end
output = char(java.io.File(char(output)).getCanonicalPath());
if isfile(output)
    error('dataset_split:bad_output', '%s', dataset_split.text(language, 'bad_output'));
end
a = [source, filesep]; b = [output, filesep];
if ispc, a = lower(a); b = lower(b); end
if startsWith(a, b) || startsWith(b, a)
    error('dataset_split:overlap', '%s', dataset_split.text(language, 'overlap'));
end
if isfolder(output)
    contents = dir(output);
    if any(~ismember({contents.name}, {'.', '..'}))
        error('dataset_split:output_busy', '%s', dataset_split.text(language, 'output_busy', output));
    end
end
end
