function plan = plan(trials, method, trainPercent, testSubjects, testTrials)
%PLAN 计算精确帧数；时间划分每试次向下取整，其余帧全部进入测试集。
if nargin < 3, trainPercent = 80; end
if nargin < 4, testSubjects = []; end
if nargin < 5, testTrials = {}; end
frames = [trials.Frames].';
switch method
    case 'frame'
        assert(isscalar(trainPercent) && isfinite(trainPercent) && ...
            trainPercent >= 0 && trainPercent <= 100 && trainPercent == round(trainPercent));
        training = floor(frames * trainPercent / 100);
    case 'subject'
        isTest = arrayfun(@(trial) any(ismember(trial.Subjects, testSubjects)), trials);
        training = frames .* ~isTest;
    case 'trial'
        isTest = ismember(string({trials.Id}).', string(testTrials));
        training = frames .* ~isTest;
    case 'none'
        training = zeros(size(frames));
    otherwise, error('dataset_split:Method', 'Unknown split method.');
end
testing = frames - training;
if strcmp(method, 'none'), testing(:) = 0; end
plan = struct('Method', method, 'TrainPercent', trainPercent, 'TrainFrames', training, ...
    'TestFrames', testing, 'TotalFrames', sum(frames), 'NumTrials', numel(trials), ...
    'TrainCombinations', {unique({trials(training > 0).SubjectKey})}, ...
    'TestCombinations', {unique({trials(testing > 0).SubjectKey})}, ...
    'TrainTrials', { {trials(training > 0).Id} }, 'TestTrials', { {trials(testing > 0).Id} });
end
