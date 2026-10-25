function mask = trial_filter(trials, people, subjectKey, actionKey, cNumber)
%TRIAL_FILTER 组合筛选为完全相等，独立于按受试者划分的包含关系。
mask = true(numel(trials), 1);
if ~isempty(people), mask = mask & [trials.People].' == people; end
if ~isempty(subjectKey), mask = mask & strcmp({trials.SubjectKey}.', subjectKey); end
if ~isempty(actionKey), mask = mask & strcmp({trials.ActionKey}.', actionKey); end
if ~isempty(cNumber), mask = mask & [trials.C].' == cNumber; end
end
