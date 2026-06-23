function [adc_data_real,frame_num] = read_NOV(fileName,packet_num,T_num,R_num,adc_num,ds_coe)

    fid = fopen(fileName, 'r+');

    if (fid == -1)
        uiwait(msgbox('文档打开失败！/ File open failed!'))
        return
    end

    offset = 0;                 % 指针偏移量为0 / File pointer offset = 0
    fseek(fid,offset,'bof');    % 从文件开头定位 / Seek to beginning of file

    adc_data = zeros(adc_num,2*packet_num/ds_coe,T_num*R_num);

    solving_num = packet_num*2/ds_coe;
    solved_num = 0;

    frame_num = [];

    for ii = 1:solving_num
        try
            % 文件指针自动前移；60为每个chirp附带的帧头字节数
            % File pointer advances automatically; 60 = frame header bytes per chirp
            frame_data = fread(fid,R_num*(adc_num+60)*T_num*ds_coe,'int16');

            % frame1:TX1_8:RX1_8:chirp_adc_num;
            frame_data_r = reshape(frame_data,R_num,(adc_num+60),T_num,ds_coe); % 接收通道1-8 × 采样点adc_num × 发射1-8 × 降采样帧数 / RX 1-8 × adc samples × TX 1-8 × ds_coe frames

            % 去掉帧头，重组数据维度为：adc_num - R_num - T_num - ds_coe
            % Strip frame header, reshape to: adc_num - R_num - T_num - ds_coe
            A_permuted = permute(frame_data_r(:,1:adc_num,:,:), [1 3 2,4]);
            A_permuted = permute(A_permuted,[3,1,2,4]);

            % 记录帧号 / Record frame number
            frame_num_all = squeeze(frame_data_r(:,end,:,:));           % R_num - T_num - ds_coe
            frame_num = [frame_num;floor(frame_num_all(1,1)/T_num)+1];

            % 重组数据维度为：adc_num - R_num * T_num - ds_coe
            % Reshape to: adc_num - R_num * T_num - ds_coe
            adc_data_r = reshape(A_permuted, [adc_num,R_num*T_num,ds_coe]);
            % 取 adc_data_r 的首帧，存储为: adc_num - ii - R_num * T_num
            % Take first frame of adc_data_r, store as: adc_num - ii - R_num * T_num
            adc_data(:,ii,:) = reshape(adc_data_r(:,:,1),[adc_num,1,R_num*T_num]);

            fprintf('Solving data %d/%d\n', ii, solving_num);
            solved_num = ii;
        catch
            disp('跳过 / Skipped');
            break
        end
    end

    fclose(fid);

    adc_data_real = adc_data(:,1:solved_num,:);

end