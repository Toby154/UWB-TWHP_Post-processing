%% 构造数据集 / Build Dataset
clc;clear all;close all

%% 雷达坐标变换参数设置 / Radar coordinate transform parameters
radar_x = 0;
radar_y = -5;

%% 数据集保存地址设置 / Dataset output path configuration
pathSave_1_train = '/media/user_name/Data/UWB-TWHP/1/train/radardata';
pathSave_1_test = '/media/user_name/Data/UWB-TWHP/1/test/radardata';

pathSave_2_train = '/media/user_name/Data/UWB-TWHP/2/train/radardata';
pathSave_2_test = '/media/user_name/Data/UWB-TWHP/2/test/radardata';

pathSave_3_train = '/media/user_name/Data/UWB-TWHP/3/train/radardata';
pathSave_3_test = '/media/user_name/Data/UWB-TWHP/3/test/radardata';

mkdir(pathSave_1_train)
mkdir(pathSave_1_test)
mkdir(pathSave_2_train)
mkdir(pathSave_2_test)
mkdir(pathSave_3_train)
mkdir(pathSave_3_test)

pathSave_train_list = [pathSave_1_train;pathSave_2_train;pathSave_3_train];
pathSave_test_list = [pathSave_1_test;pathSave_2_test;pathSave_3_test];

%% 指定一级目录(数据目录) / Specify root data directory
FolderRoot = '/media/toby-wong/Repository/UWB-TWHP_DATA_part1';
fileInfoR = dir(fullfile(FolderRoot, '*'));
fileInfoR = fileInfoR(~ismember({fileInfoR.name}, {'.', '..'}));%% 排除当前目录和上一级目录符号 / Exclude '.' and '..'

%% 读取人数目录 / Iterate over person-count directories
for s = 1:length(fileInfoR)
    FolderName1 = fileInfoR(s).name;
    Folder1 = fullfile(FolderRoot, FolderName1);
    fileInfo1 = dir(fullfile(Folder1, '*'));
    fileInfo1 = fileInfo1(~ismember({fileInfo1.name}, {'.', '..'}));%% 排除当前目录和上一级目录符号 / Exclude '.' and '..'

    pathSave_train = pathSave_train_list(s,:);
    pathSave_test = pathSave_test_list(s,:);

    %% 读取人员目录 / Iterate over subject directories
    for ss = 1:length(fileInfo1)
        FolderName2 = fileInfo1(ss).name;
        Folder2 = fullfile(Folder1, FolderName2);
        fileInfo2 = dir(fullfile(Folder2, '*'));
        fileInfo2 = fileInfo2(~ismember({fileInfo2.name}, {'.', '..'}));%% 排除当前目录和上一级目录符号 / Exclude '.' and '..'

        human_tag = extractHNumbers(FolderName2);%% 获取人员编号 / Extract subject ID

        %% 读取动作目录 / Iterate over action directories
        for sss = 1:length(fileInfo2)
            FolderName3 = fileInfo2(sss).name;
            Folder3 = fullfile(Folder2, FolderName3);
            fileInfo3 = dir(fullfile(Folder3, '*'));
            fileInfo3 = fileInfo3(~ismember({fileInfo3.name}, {'.', '..'}));%% 排除当前目录和上一级目录符号 / Exclude '.' and '..'

            % 去掉双人和三人文件夹中，给动作目录添加的编号前缀
            % Strip numeric prefix from action folder names in 2/3-person scenarios
            if s == 1
                FolderName3_new = FolderName3;
            else
                FolderName3_new = FolderName3(4:end);
            end

            action_tag = extractHNumbers(FolderName3_new);%% 获取动作编号 / Extract action ID

            %% 读取文件目录 / Iterate over clip directories
            for ssss = 1:length(fileInfo3)
                FolderName4 = fileInfo3(ssss).name;
                Folder4 = fullfile(Folder3, FolderName4);

                %% 读取JSON / Read JSON (mocap data)
                JSON_file = fullfile(Folder4, 'nokov.json');
                if isfile(JSON_file)
                    [positionMatrix, BodyID] = NOKOV_json_read(JSON_file, radar_x, radar_y);
                else
                    disp(['动捕文件缺失 / Mocap file missing, ',Folder3,' 已跳过 / skipped'])
                    continue
                end

                %% 读取回波 / Read radar echo data
                NOV_file = dir(fullfile(Folder4, '*.NOV'));
                NOV_filePath = fullfile(Folder4, NOV_file.name);

                range_data_temp = gen_range_data_complex(NOV_filePath);

                %% 更新帧数（动捕帧数与雷达帧数对齐） / Align mocap frames to radar frame count
                positionMatrix = positionMatrix(:, :, 1:size(range_data_temp,3));
                BodyID = BodyID(1:size(range_data_temp,3), :);

                %% 检查动捕丢帧 / Detect abnormal mocap frames
                abnormalFrames = detectAbnormalFramesVectorized(positionMatrix);

                %% 若丢帧，剔除异常帧 / Remove abnormal frames if any
                if ~isempty(abnormalFrames)
                    keepFrames = true(1, size(positionMatrix,3));
                    keepFrames(abnormalFrames) = false;

                    % 删除异常帧 / Remove abnormal frames
                    positionMatrix = positionMatrix(:, :, keepFrames);
                    BodyID = BodyID(keepFrames, :);
                    range_data_temp = range_data_temp(:, :, keepFrames);

                    fprintf('异常帧清理完成！/ Abnormal frame removal completed!\n');
                end

                range_data_real_temp = real(range_data_temp);
                range_data_imag_temp = imag(range_data_temp);

                %% 调整动作标签顺序，生成 action / Reorder action labels to match body order
                [frames, n] = size(BodyID);
                Action = zeros(frames, n);
                for f = 1:frames
                    [~, idx] = ismember(BodyID(f, :), human_tag);
                    Action(f, :) = action_tag(idx);
                end

                action_temp = Action';
                action_temp = reshape(action_temp, size(action_temp,1), 1, size(action_temp,2));

                %% 生成 conf（置信度掩码） / Generate confidence mask
                conf_temp = ones(size(action_temp));

                %% 生成文件名 / Generate output filename
                baseName1 = letterVarCombine('N', s);
                baseName2 = letterVarCombine('H', human_tag);
                baseName3 = letterVarCombine('A', action_tag);
                baseName4 = letterVarCombine('C', ssss);
                baseName = [baseName1,'_',baseName2,'_',baseName3,'_',baseName4];

                %% 分割训练集和测试集（前80%训练，后20%测试） / Train/test split (80% train, 20% test)
                train_num = floor(size(range_data_temp,3)/5*4);
                % 保存测试集 / Save test set
                radar_data_real = single(range_data_real_temp(:,:,train_num+1:end));
                radar_data_imag = single(range_data_imag_temp(:,:,train_num+1:end));
                joint = single(positionMatrix(:,:,train_num+1:end));
                action = single(action_temp(:,:,train_num+1:end));
                conf = single(conf_temp(:,:,train_num+1:end));

                filename_MAT = fullfile(pathSave_test,[baseName,'_test.mat']);
                save(filename_MAT,'radar_data_real','radar_data_imag','joint','action','conf',"-v7.3");

                clear radar_data_real radar_data_imag joint action conf

                % 保存训练集 / Save train set
                radar_data_real = single(range_data_real_temp(:,:,1:train_num));
                radar_data_imag = single(range_data_imag_temp(:,:,1:train_num));
                joint = single(positionMatrix(:,:,1:train_num));
                action = single(action_temp(:,:,1:train_num));
                conf = single(conf_temp(:,:,1:train_num));

                filename_MAT = fullfile(pathSave_train,[baseName,'_train.mat']);
                save(filename_MAT,'radar_data_real','radar_data_imag','joint','action','conf',"-v7.3");

                clear radar_data_real radar_data_imag joint action conf

            end

        end

    end

end