function check_cancel(cancelFcn, language)
if ~isempty(cancelFcn) && cancelFcn()
    error('dataset_split:cancel_id', '%s', dataset_split.text(language, 'cancel_id'));
end
end
