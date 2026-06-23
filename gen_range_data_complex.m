function [range_data,frame_num] = gen_range_data_complex(file_path)

    % 可修改参数 / Tunable parameters
    load('buchang_tieqiang_8m_wall.mat');
    L = abs(L);

    load("data_info.mat");
    MTDfilter=[5,-1*ones(1,5)];

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

        % FFT处理和通道距离单元补偿 / FFT processing & per-channel range-bin compensation
        PC = fft(PC_ifft,fft_number);
        PC = PC(1:fft_number/2,:);
        % plot(RL,abs(PC(:,1)));

        for i_an = 1:size(an,3)
            PC(1:end-L(i_an),i_an,:) = PC(1+L(i_an):end,i_an,:);
            PC(end-L(i_an)+1:end,i_an,:) = 0;
            PC(:,i_an,:) = PC(:,i_an,:).*P(i_an);
        end

        range_data(:,:,framenum) = PC(560:2:1582,:);

    end

    frame_num = frame_num(1:frame_sd:size(adc_data,3)-length(MTDfilter));
    fprintf('返回脉压数据 / Range-compressed data returned\n');

end
