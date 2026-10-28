function [range_data,frame_num] = gen_range_data_complex(file_path)

    % 可修改参数 / Tunable parameters
    load('buchang_tieqiang_8m_wall.mat');
    L = abs(L);

    load("data_info.mat");
    MTDfilter=[5,-1*ones(1,5)];% 此处未使用MTD滤波器 / MTD filter is NOT used

    %% 读取雷达数据 / Read radar data
    [adc_data,frame_num] = read_NOV(file_path,1000,8,8,3940,1);
    adc_data = permute(adc_data,[1 3 2]);
    fprintf('雷达数据读取成功 / Radar data loaded successfully\n');

    %% 加载系统参数 / Load system parameters
    an = data_info.antenna_posi;
    fft_number = 102400;

    range_data = zeros(512, 64, size(adc_data,3)-length(MTDfilter));
    %% 成像 / Imaging (range-profile generation)
    frame_sd = 1;
    for framenum = 1:frame_sd:size(adc_data,3)-length(MTDfilter)     % data_info.framenum

        PC_ifft = adc_data(:,:,framenum);
        % 此处未使用MTD滤波器 / MTD filter is NOT used

        % FFT处理和通道距离单元补偿 / FFT processing & per-channel range-bin compensation
        PC = fft(PC_ifft,fft_number);
        PC = PC(1:fft_number/2,:);
        % plot(RL,abs(PC(:,1)));

        for i_an = 1:size(an,3)
            PC(1:end-L(i_an),i_an,:) = PC(1+L(i_an):end,i_an,:);
            PC(end-L(i_an)+1:end,i_an,:) = 0;
            PC(:,i_an,:) = PC(:,i_an,:).*P(i_an);
        end

        range_data(:,:,framenum) = PC(401:2:1424,:);
        % range_data(:,:,framenum) = PC(560:2:1582,:);

        % 注意：在处理数据时，依据不同数数据的实际情况，使用了不同的截取范围，
        % 为了便于研究者使用距离单元映射信息，我们预先计算并保存了两种距离单元映射表（均为双程距离，单位为m），
        % 起始频率单元分别为401时的映射表为'range_axis_part1.csv'，
        % 起始频率单元分别为560时的映射表为'range_axis_part2.csv'，
        % 同时提供了一个查找表'file_range_lookup.csv'，用于标注每个mat文件应该对应哪一组距离单元映射表。
        % 这三个文件保存在本仓库的'range_mapping'文件夹中，
        % 使用者可以依据查找表自行组织数据，或者使用'UWB-TWHP_Dataset_Splitter'工具批量将距离信息添加进mat文件中。

        % ATTENTION: when processing the data, different ranges are used for different datasets.
        % For the convenience of researchers, we have pre-calculated and saved two range-bin mapping tables (both are two-way distances, in meters).
        % The mapping table starting from frequency bin 401 is 'range_axis_part1.csv', 
        % and the mapping table starting from frequency bin 560 is 'range_axis_part2.csv'.
        % A lookup table 'file_range_lookup.csv' is also provided to indicate which range-bin mapping table corresponds to each mat file.
        % These three files are saved in the 'range_mapping' folder of this repository.
        % Users can organize the data according to the lookup table or use the 'UWB-TWHP_Dataset_Splitter' tool to batch add range information into the mat files.

    end

    frame_num = frame_num(1:frame_sd:size(adc_data,3)-length(MTDfilter));
    fprintf('返回脉压数据 / Range-compressed data returned\n');

end
