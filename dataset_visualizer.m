function dataset_visualizer()
%DATASET_VISUALIZER Interactive viewer for UWB-TWHP MAT dataset files.
% Run this file, click "Select MAT File", then use the playback controls.

state = struct();
state.filePath = '';
state.matObj = [];
state.currentFrame = 1;
state.numFrames = 0;
state.numRangeBins = 0;
state.numChannels = 0;
state.numPeople = 0;
state.rangeAxis = [];
state.rangeAxisLabel = 'Range Bin';
state.rangeTimeDb = [];
state.dopplerWindowLength = 64;
state.spectrumDynamicRangeDb = 40;
state.timer = [];
state.isPlaying = false;
state.frameMarker = [];
state.actionData = [];
state.confData = [];
state.jointLimits = [];

actionNames = { ...
    'Sitting', 'Squatting', 'Standing', 'Punching', ...
    'Kicking', 'Bending', 'Waving', 'Walking'};

jointNames = { ...
    'Head', 'Neck', 'Spine', 'Spine3', ...
    'LeftArm', 'LeftForeArm', 'LeftHand', ...
    'RightArm', 'RightForeArm', 'RightHand', ...
    'LeftUpLeg', 'LeftLeg', 'LeftFoot', ...
    'RightUpLeg', 'RightLeg', 'RightFoot'};

connections = [
     1,  2;
     2,  4;
     4,  3;
     2,  5;
     5,  6;
     6,  7;
     2,  8;
     8,  9;
     9, 10;
     3, 11;
    11, 12;
    12, 13;
     3, 14;
    14, 15;
    15, 16
];

fig = figure( ...
    'Name', 'UWB-TWHP Dataset Visualizer', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Units', 'normalized', ...
    'Position', [0.04, 0.06, 0.92, 0.86], ...
    'MenuBar', 'none', ...
    'ToolBar', 'figure', ...
    'CloseRequestFcn', @closeFigure);

controlPanel = uipanel( ...
    'Parent', fig, ...
    'Title', 'Controls', ...
    'Units', 'normalized', ...
    'Position', [0.02, 0.92, 0.96, 0.065], ...
    'BackgroundColor', 'w');

selectButton = uicontrol(controlPanel, ...
    'Style', 'pushbutton', ...
    'String', 'Select MAT File', ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.18, 0.12, 0.62], ...
    'Callback', @selectMatFile);

playButton = uicontrol(controlPanel, ...
    'Style', 'togglebutton', ...
    'String', 'Play', ...
    'Units', 'normalized', ...
    'Position', [0.14, 0.18, 0.07, 0.62], ...
    'Enable', 'off', ...
    'Callback', @togglePlay);

prevButton = uicontrol(controlPanel, ...
    'Style', 'pushbutton', ...
    'String', 'Prev Frame', ...
    'Units', 'normalized', ...
    'Position', [0.22, 0.18, 0.08, 0.62], ...
    'Enable', 'off', ...
    'Callback', @previousFrame);

nextButton = uicontrol(controlPanel, ...
    'Style', 'pushbutton', ...
    'String', 'Next Frame', ...
    'Units', 'normalized', ...
    'Position', [0.31, 0.18, 0.08, 0.62], ...
    'Enable', 'off', ...
    'Callback', @nextFrame);

frameSlider = uicontrol(controlPanel, ...
    'Style', 'slider', ...
    'Units', 'normalized', ...
    'Position', [0.41, 0.23, 0.24, 0.50], ...
    'Enable', 'off', ...
    'Callback', @sliderChanged);

frameText = uicontrol(controlPanel, ...
    'Style', 'text', ...
    'String', 'Frame: - / -', ...
    'Units', 'normalized', ...
    'Position', [0.66, 0.20, 0.11, 0.55], ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left');

statusText = uicontrol(controlPanel, ...
    'Style', 'text', ...
    'String', 'Select a MAT file to start.', ...
    'Units', 'normalized', ...
    'Position', [0.78, 0.20, 0.21, 0.55], ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left');

axRangeTime = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.06, 0.67, 0.43, 0.20]);
title(axRangeTime, 'Range-Time Map');
xlabel(axRangeTime, 'Frame Index');
ylabel(axRangeTime, state.rangeAxisLabel);
grid(axRangeTime, 'on');

axReal = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.56, 0.67, 0.18, 0.20]);
title(axReal, 'Current Frame Real');
xlabel(axReal, 'Channel');
ylabel(axReal, 'Range Bin');

axImag = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.79, 0.67, 0.18, 0.20]);
title(axImag, 'Current Frame Imag');
xlabel(axImag, 'Channel');
ylabel(axImag, 'Range Bin');

axRangeSpectrum = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.06, 0.37, 0.43, 0.20]);
title(axRangeSpectrum, 'Range Spectrum');
xlabel(axRangeSpectrum, state.rangeAxisLabel);
ylabel(axRangeSpectrum, 'Relative Power (dB)');
grid(axRangeSpectrum, 'on');

axDopplerSpectrum = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.56, 0.37, 0.41, 0.20]);
title(axDopplerSpectrum, 'Doppler Spectrum');
xlabel(axDopplerSpectrum, 'Doppler Frequency (cycles / saved frame)');
ylabel(axDopplerSpectrum, state.rangeAxisLabel);

axSkeleton = axes('Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.06, 0.07, 0.43, 0.20]);
title(axSkeleton, 'Skeleton');
xlabel(axSkeleton, 'X');
ylabel(axSkeleton, 'Y');
zlabel(axSkeleton, 'Z');
grid(axSkeleton, 'on');
axis(axSkeleton, 'equal');
view(axSkeleton, 3);

actionPanel = uipanel( ...
    'Parent', fig, ...
    'Title', 'Action Labels', ...
    'Units', 'normalized', ...
    'Position', [0.56, 0.07, 0.41, 0.20], ...
    'BackgroundColor', 'w');

actionText = uicontrol(actionPanel, ...
    'Style', 'text', ...
    'String', 'No MAT file loaded.', ...
    'Units', 'normalized', ...
    'Position', [0.04, 0.04, 0.92, 0.90], ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'FontName', 'Consolas');

state.timer = timer( ...
    'ExecutionMode', 'fixedSpacing', ...
    'Period', 0.05, ...
    'TimerFcn', @timerStep);

    function selectMatFile(~, ~)
        [fileName, folderName] = uigetfile('*.mat', 'Select dataset MAT file');
        if isequal(fileName, 0)
            return;
        end

        stopPlayback();
        filePath = fullfile(folderName, fileName);
        set(statusText, 'String', 'Loading MAT file...');
        drawnow;

        try
            loadDataset(filePath);
            enableControls();
            updateFrame(1);
            set(statusText, 'String', ['Loaded: ', fileName]);
        catch ME
            disableControls();
            clearAxes();
            set(statusText, 'String', 'Load failed.');
            errordlg(ME.message, 'MAT Load Error');
        end
    end

    function loadDataset(filePath)
        matInfo = whos('-file', filePath);
        varNames = {matInfo.name};
        requiredVars = {'radar_data_real', 'radar_data_imag', 'joint', 'action'};
        for i = 1:numel(requiredVars)
            if ~ismember(requiredVars{i}, varNames)
                error('MAT file is missing required variable "%s".', requiredVars{i});
            end
        end

        realInfo = matInfo(strcmp(varNames, 'radar_data_real'));
        imagInfo = matInfo(strcmp(varNames, 'radar_data_imag'));
        jointInfo = matInfo(strcmp(varNames, 'joint'));
        actionInfo = matInfo(strcmp(varNames, 'action'));

        if ~isequal(realInfo.size, imagInfo.size)
            error('radar_data_real and radar_data_imag have different sizes.');
        end
        if numel(realInfo.size) ~= 3
            error('radar_data_real should be range_bins x channels x frames.');
        end
        if numel(jointInfo.size) ~= 3 || jointInfo.size(2) < 48
            error('joint should be people x 48 x frames.');
        end

        state.filePath = filePath;
        state.matObj = matfile(filePath);
        state.numRangeBins = realInfo.size(1);
        state.numChannels = realInfo.size(2);
        state.numPeople = jointInfo.size(1);
        state.numFrames = min([realInfo.size(3), jointInfo.size(3), actionInfo.size(end)]);
        state.currentFrame = 1;

        [state.rangeAxis, state.rangeAxisLabel] = loadRangeAxis( ...
            filePath, state.numRangeBins, varNames);
        state.rangeTimeDb = buildRangeTimeMap();
        state.actionData = state.matObj.action(:, :, 1:state.numFrames);
        if ismember('conf', varNames)
            state.confData = state.matObj.conf(:, :, 1:state.numFrames);
        else
            state.confData = [];
        end
        state.jointLimits = estimateJointLimits();

        plotRangeTimeMap();
        configureSlider();
    end

    function rangeTimeDb = buildRangeTimeMap()
        chunkSize = 100;
        dynamicRangeDb = 40;
        rangeTimeResponse = zeros(state.numRangeBins, state.numFrames, 'single');

        for frameStart = 1:chunkSize:state.numFrames
            frameEnd = min(frameStart + chunkSize - 1, state.numFrames);
            set(statusText, 'String', sprintf( ...
                'Computing range-time map: %d-%d / %d', ...
                frameStart, frameEnd, state.numFrames));
            drawnow;

            radarReal = state.matObj.radar_data_real(:, :, frameStart:frameEnd);
            radarImag = state.matObj.radar_data_imag(:, :, frameStart:frameEnd);
            response = mean(hypot(radarReal, radarImag), 2);
            rangeTimeResponse(:, frameStart:frameEnd) = reshape( ...
                response, state.numRangeBins, []);
        end

        background = median(rangeTimeResponse, 2);
        rangeTimeResponse = bsxfun(@minus, rangeTimeResponse, background);
        rangeTimeResponse(rangeTimeResponse < 0) = 0;
        rangeTimeResponse = max(rangeTimeResponse, eps('single'));

        rangeTimeDb = 20 * log10(double(rangeTimeResponse));
        rangeTimeDb = rangeTimeDb - max(rangeTimeDb(:));
        rangeTimeDb(rangeTimeDb < -dynamicRangeDb) = -dynamicRangeDb;
    end

    function plotRangeTimeMap()
        cla(axRangeTime);
        imagesc(axRangeTime, 1:state.numFrames, state.rangeAxis, state.rangeTimeDb);
        set(axRangeTime, 'YDir', 'normal');
        xlabel(axRangeTime, 'Frame Index');
        ylabel(axRangeTime, state.rangeAxisLabel);
        title(axRangeTime, 'Range-Time Map');
        colormap(axRangeTime, selectColormap());
        colorbar(axRangeTime);
        hold(axRangeTime, 'on');
        yLimits = ylim(axRangeTime);
        state.frameMarker = plot(axRangeTime, [1, 1], yLimits, 'w-', 'LineWidth', 1.8);
        hold(axRangeTime, 'off');
        grid(axRangeTime, 'on');
    end

    function updateFrame(frameIndex)
        if state.numFrames == 0
            return;
        end

        frameIndex = max(1, min(state.numFrames, round(frameIndex)));
        state.currentFrame = frameIndex;

        set(frameText, 'String', sprintf('Frame: %d / %d', frameIndex, state.numFrames));
        set(frameSlider, 'Value', frameIndex);

        if isgraphics(state.frameMarker)
            yLimits = ylim(axRangeTime);
            set(state.frameMarker, 'XData', [frameIndex, frameIndex], 'YData', yLimits);
        end

        plotCurrentRadarFrame(frameIndex);
        plotDopplerSpectrum(frameIndex);
        plotCurrentSkeleton(frameIndex);
        updateActionText(frameIndex);
        drawnow limitrate;
    end

    function plotCurrentRadarFrame(frameIndex)
        radarReal = state.matObj.radar_data_real(:, :, frameIndex);
        radarImag = state.matObj.radar_data_imag(:, :, frameIndex);

        imagesc(axReal, 1:state.numChannels, state.rangeAxis, double(radarReal));
        set(axReal, 'YDir', 'normal');
        title(axReal, sprintf('Real, Frame %d', frameIndex));
        xlabel(axReal, 'Channel');
        ylabel(axReal, state.rangeAxisLabel);
        colorbar(axReal);

        imagesc(axImag, 1:state.numChannels, state.rangeAxis, double(radarImag));
        set(axImag, 'YDir', 'normal');
        title(axImag, sprintf('Imag, Frame %d', frameIndex));
        xlabel(axImag, 'Channel');
        ylabel(axImag, state.rangeAxisLabel);
        colorbar(axImag);

        % MAT data are already range-compressed; average channel power without
        % coherently summing channels, which could cancel different phases.
        rangePower = mean(double(radarReal).^2 + double(radarImag).^2, 2);
        plot(axRangeSpectrum, state.rangeAxis, relativePowerDb(rangePower), ...
            'LineWidth', 1.5);
        title(axRangeSpectrum, sprintf('Range Spectrum, Frame %d', frameIndex));
        xlabel(axRangeSpectrum, state.rangeAxisLabel);
        ylabel(axRangeSpectrum, 'Relative Power (dB)');
        ylim(axRangeSpectrum, [-state.spectrumDynamicRangeDb, 0]);
        grid(axRangeSpectrum, 'on');
    end

    function plotDopplerSpectrum(frameIndex)
        windowLength = min(state.dopplerWindowLength, state.numFrames);
        if windowLength < 2
            cla(axDopplerSpectrum);
            title(axDopplerSpectrum, 'Doppler Spectrum: at least 2 frames required');
            return;
        end

        % Keep a full window near the clip boundaries; elsewhere center it on
        % the selected frame. Dimensions are range x channel x slow time.
        frameStart = max(1, min(frameIndex - floor(windowLength / 2), ...
            state.numFrames - windowLength + 1));
        frameEnd = frameStart + windowLength - 1;
        radarReal = state.matObj.radar_data_real(:, :, frameStart:frameEnd);
        radarImag = state.matObj.radar_data_imag(:, :, frameStart:frameEnd);
        radarWindow = complex(double(radarReal), double(radarImag));

        % Remove static clutter, then apply a periodic Hann window along slow
        % time. The explicit formula needs no Signal Processing Toolbox.
        radarWindow = bsxfun(@minus, radarWindow, mean(radarWindow, 3));
        hannWindow = 0.5 - 0.5 * cos(2 * pi * (0:windowLength - 1) / windowLength);
        radarWindow = bsxfun(@times, radarWindow, reshape(hannWindow, 1, 1, []));
        fftLength = 2^nextpow2(windowLength);
        dopplerResponse = fftshift(fft(radarWindow, fftLength, 3), 3);
        dopplerPower = reshape(mean(abs(dopplerResponse).^2, 2), ...
            state.numRangeBins, fftLength);

        % Saved clips omit timestamps and may have dropped frames. Use cycles
        % per saved frame rather than assuming a physical sampling rate in Hz.
        dopplerAxis = (-floor(fftLength / 2):ceil(fftLength / 2) - 1) / fftLength;
        imagesc(axDopplerSpectrum, dopplerAxis, state.rangeAxis, ...
            relativePowerDb(dopplerPower));
        set(axDopplerSpectrum, 'YDir', 'normal');
        title(axDopplerSpectrum, sprintf('Doppler Spectrum, Frames %d-%d', ...
            frameStart, frameEnd));
        xlabel(axDopplerSpectrum, 'Doppler Frequency (cycles / saved frame)');
        ylabel(axDopplerSpectrum, state.rangeAxisLabel);
        colormap(axDopplerSpectrum, selectColormap());
        set(axDopplerSpectrum, 'CLim', [-state.spectrumDynamicRangeDb, 0]);
        colorbar(axDopplerSpectrum);
    end

    function powerDb = relativePowerDb(power)
        % Each spectrum uses its own peak as 0 dB and a fixed display floor.
        % An all-zero signal stays at the floor instead of showing a false peak.
        peakPower = max(power(:));
        if peakPower == 0
            powerDb = -state.spectrumDynamicRangeDb * ones(size(power));
        else
            powerDb = 10 * log10(max(power / peakPower, ...
                10^(-state.spectrumDynamicRangeDb / 10)));
        end
    end

    function plotCurrentSkeleton(frameIndex)
        cla(axSkeleton);
        hold(axSkeleton, 'on');
        colors = lines(max(state.numPeople, 1));
        jointFrame = state.matObj.joint(:, :, frameIndex);

        for personIndex = 1:state.numPeople
            joints = reshapeJoints(jointFrame(personIndex, :));
            validMask = all(isfinite(joints), 2);
            if ~any(validMask)
                continue;
            end

            scatter3(axSkeleton, joints(validMask, 1), joints(validMask, 2), joints(validMask, 3), ...
                28, colors(personIndex, :), 'filled');

            for c = 1:size(connections, 1)
                startIdx = connections(c, 1);
                endIdx = connections(c, 2);
                if all(validMask([startIdx, endIdx]))
                    plot3(axSkeleton, ...
                        joints([startIdx, endIdx], 1), ...
                        joints([startIdx, endIdx], 2), ...
                        joints([startIdx, endIdx], 3), ...
                        '-', 'LineWidth', 2, 'Color', colors(personIndex, :));
                end
            end

            headIdx = find(strcmp(jointNames, 'Head'), 1);
            headPos = joints(headIdx, :);
            if all(isfinite(headPos))
                text(axSkeleton, headPos(1), headPos(2), headPos(3) + 0.15, ...
                    sprintf('P%d', personIndex), ...
                    'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', ...
                    'Color', colors(personIndex, :));
            end
        end

        hold(axSkeleton, 'off');
        title(axSkeleton, sprintf('Skeleton, Frame %d', frameIndex));
        xlabel(axSkeleton, 'X');
        ylabel(axSkeleton, 'Y');
        zlabel(axSkeleton, 'Z');
        grid(axSkeleton, 'on');
        axis(axSkeleton, 'equal');
        view(axSkeleton, 3);
        if ~isempty(state.jointLimits)
            axis(axSkeleton, state.jointLimits);
        end
    end

    function updateActionText(frameIndex)
        linesText = cell(state.numPeople + 3, 1);
        linesText{1} = sprintf('File: %s', getFileName(state.filePath));
        linesText{2} = sprintf('Frame: %d / %d', frameIndex, state.numFrames);
        linesText{3} = ' ';

        for personIndex = 1:state.numPeople
            tag = getActionTag(personIndex, frameIndex);
            actionLabel = actionTagToText(tag);
            confidenceText = '';
            if ~isempty(state.confData)
                confValue = squeeze(state.confData(personIndex, 1, frameIndex));
                confidenceText = sprintf(', conf %.0f', confValue);
            end
            linesText{personIndex + 3} = sprintf( ...
                'Person %d: Action Tag %s, %s%s', ...
                personIndex, formatNumericTag(tag), actionLabel, confidenceText);
        end

        set(actionText, 'String', strjoin(linesText, newline));
    end

    function tag = getActionTag(personIndex, frameIndex)
        tag = squeeze(state.actionData(personIndex, 1, frameIndex));
        if isempty(tag)
            tag = nan;
        end
    end

    function label = actionTagToText(tag)
        if ~isfinite(tag)
            label = 'Unknown';
            return;
        end

        roundedTag = round(double(tag));
        if roundedTag >= 0 && roundedTag <= 7
            label = sprintf('%s (A%d)', actionNames{roundedTag + 1}, roundedTag);
        else
            label = 'Unknown';
        end
    end

    function tagText = formatNumericTag(tag)
        if ~isfinite(tag)
            tagText = 'NaN';
        else
            tagText = sprintf('%d', round(double(tag)));
        end
    end

    function joints = reshapeJoints(flatJoints)
        flatJoints = double(flatJoints(:)).';
        joints = [ ...
            flatJoints(1:16).', ...
            flatJoints(17:32).', ...
            flatJoints(33:48).' ...
        ];
    end

    function limits = estimateJointLimits()
        sampleCount = min(state.numFrames, 80);
        sampleFrames = unique(round(linspace(1, state.numFrames, sampleCount)));
        minValues = [inf, inf, inf];
        maxValues = [-inf, -inf, -inf];

        for i = 1:numel(sampleFrames)
            jointFrame = state.matObj.joint(:, :, sampleFrames(i));
            for personIndex = 1:state.numPeople
                joints = reshapeJoints(jointFrame(personIndex, :));
                validMask = all(isfinite(joints), 2);
                if any(validMask)
                    minValues = min(minValues, min(joints(validMask, :), [], 1));
                    maxValues = max(maxValues, max(joints(validMask, :), [], 1));
                end
            end
        end

        if any(~isfinite(minValues)) || any(~isfinite(maxValues))
            limits = [];
            return;
        end

        padding = max((maxValues - minValues) * 0.10, [0.2, 0.2, 0.2]);
        limits = [ ...
            minValues(1) - padding(1), maxValues(1) + padding(1), ...
            minValues(2) - padding(2), maxValues(2) + padding(2), ...
            minValues(3) - padding(3), maxValues(3) + padding(3)];
    end

    function [rangeAxis, axisLabel] = loadRangeAxis(filePath, numRangeBins, varNames)
        rangeAxis = (1:numRangeBins).';
        axisLabel = 'Range Bin';
        % Prefer the embedded metre-valued range vector. Older files use the
        % public CSV lookup, so the viewer never needs local provenance files.
        if ismember('range_bin', varNames)
            rangeAxis = state.matObj.range_bin;
        else
            mappingDir = fullfile(fileparts(mfilename('fullpath')), 'range_mapping');
            lookupFile = fullfile(mappingDir, 'file_range_lookup.csv');
            if ~isfile(lookupFile)
                return;
            end
            lookup = readtable(lookupFile, 'Delimiter', ',', ...
                'TextType', 'string', 'VariableNamingRule', 'preserve');
            fileName = getFileName(filePath);
            % Match the complete trial identifier, shared by full/train/test files.
            trialKey = regexprep(string(fileName), '(_train|_test)?\.mat$', '');
            rows = find(lookup.file_name == trialKey);
            if isempty(rows)
                return;
            end
            if numel(rows) ~= 1
                error('Range lookup contains duplicate trial identifiers: %s.', trialKey);
            end
            axisFile = lookup.range_axis_file(rows);
            if ismissing(axisFile) || strlength(axisFile) == 0
                return;
            end
            rangeAxis = readmatrix(fullfile(mappingDir, axisFile));
        end
        if ~isvector(rangeAxis) || numel(rangeAxis) ~= numRangeBins || ...
                any(~isfinite(rangeAxis(:))) || any(diff(rangeAxis(:)) <= 0)
            error('Range axis must contain %d increasing finite distances; got %d values.', ...
                numRangeBins, numel(rangeAxis));
        end
        rangeAxis = rangeAxis(:);
        axisLabel = 'Bistatic Range (m)';
    end

    function cmap = selectColormap()
        if exist('turbo', 'file') == 2 || exist('turbo', 'builtin') == 5
            cmap = turbo(256);
        else
            cmap = jet(256);
        end
    end

    function configureSlider()
        if state.numFrames <= 1
            set(frameSlider, ...
                'Min', 1, 'Max', 2, 'Value', 1, ...
                'SliderStep', [1, 1], ...
                'Enable', 'off');
            return;
        end

        step = 1 / (state.numFrames - 1);
        set(frameSlider, ...
            'Min', 1, ...
            'Max', state.numFrames, ...
            'Value', 1, ...
            'SliderStep', [step, min(10 * step, 1)], ...
            'Enable', 'on');
    end

    function enableControls()
        set(playButton, 'Enable', 'on', 'Value', 0, 'String', 'Play');
        set(prevButton, 'Enable', 'on');
        set(nextButton, 'Enable', 'on');
        if state.numFrames > 1
            set(frameSlider, 'Enable', 'on');
        end
    end

    function disableControls()
        set(playButton, 'Enable', 'off', 'Value', 0, 'String', 'Play');
        set(prevButton, 'Enable', 'off');
        set(nextButton, 'Enable', 'off');
        set(frameSlider, 'Enable', 'off');
    end

    function clearAxes()
        cla(axRangeTime);
        cla(axReal);
        cla(axImag);
        cla(axRangeSpectrum);
        cla(axDopplerSpectrum);
        cla(axSkeleton);
        set(actionText, 'String', 'No MAT file loaded.');
        set(frameText, 'String', 'Frame: - / -');
    end

    function togglePlay(src, ~)
        if get(src, 'Value') == 1
            if state.numFrames == 0
                set(src, 'Value', 0);
                return;
            end
            state.isPlaying = true;
            set(playButton, 'String', 'Pause');
            start(state.timer);
        else
            stopPlayback();
        end
    end

    function stopPlayback()
        state.isPlaying = false;
        if ~isempty(state.timer) && isvalid(state.timer) && strcmp(state.timer.Running, 'on')
            stop(state.timer);
        end
        if isgraphics(playButton)
            set(playButton, 'Value', 0, 'String', 'Play');
        end
    end

    function timerStep(~, ~)
        if state.numFrames == 0
            stopPlayback();
            return;
        end

        nextIndex = state.currentFrame + 1;
        if nextIndex > state.numFrames
            nextIndex = 1;
        end
        updateFrame(nextIndex);
    end

    function previousFrame(~, ~)
        stopPlayback();
        updateFrame(state.currentFrame - 1);
    end

    function nextFrame(~, ~)
        stopPlayback();
        updateFrame(state.currentFrame + 1);
    end

    function sliderChanged(src, ~)
        stopPlayback();
        updateFrame(get(src, 'Value'));
    end

    function closeFigure(~, ~)
        stopPlayback();
        if ~isempty(state.timer) && isvalid(state.timer)
            delete(state.timer);
        end
        delete(fig);
    end
end

function fileName = getFileName(filePath)
[~, name, ext] = fileparts(filePath);
fileName = [name, ext];
end
