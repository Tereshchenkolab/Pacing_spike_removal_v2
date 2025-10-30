classdef ECGApp_final < matlab.apps.AppBase

    % Properties corresponding to UI components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        LoadECGButton         matlab.ui.control.Button
        PeakHeightLabel
        PeakDistLabel
        UseCustomAmpSwitch
        AmpField            matlab.ui.control.NumericEditField
        AmpLabel
        ThresholdField        matlab.ui.control.NumericEditField
        DistanceField           matlab.ui.control.NumericEditField
        UseCustomThresholdSwitch   % Switch for enabling custom threshold
        UseCustomThresholdLabel
        AmpThresholdButton  matlab.ui.control.Button
        ECGAxes1              matlab.ui.control.UIAxes
        ECGAxes2              matlab.ui.control.UIAxes
        ECGAxes3              matlab.ui.control.UIAxes
        PCAAxes               matlab.ui.control.UIAxes
        ProcessButton         matlab.ui.control.Button
        MoveToReview
        MoveToError
        NoChangeButton
        UseCustomWidthLabel
        UseCustomWidthSwitch
        WidthField
        ResultButton          matlab.ui.control.Button
        UITable
        RemoveButton
        AddButton      
        ButtonGroup        matlab.ui.container.ButtonGroup
        Option1RadioButton matlab.ui.control.RadioButton
        Option2RadioButton matlab.ui.control.RadioButton
        OutputLabel        matlab.ui.control.Label 
        ecgFigure
    end

    % Private properties (for internal data)
    properties (Access = private)
        ecgData   % ECG data loaded
        pcaData   % PCA result
        patientID % Current patient ID
        ecgFileList   % List of ECG files
        currentFileIndex  % Index of the currently loaded file
        cutoff %filter cutoff
        order %filter order
        threshold 
        distance
        amplitude_threshold
        method
        path
        files
        spike_locs
        min_peaks
        percentage
        corrected_ECG
        axes1_new
        axes2_new
        axes3_new
        interpolation
    end

    % Callbacks for UI components
    methods (Access = private)
        % Button pushed function: NextButton
        function NextButtonPushed(app, event)
            cla(app.ECGAxes1)
            cla(app.ECGAxes2)
            cla(app.ECGAxes3)
            cla(app.PCAAxes)
            % Increment the current file index
            app.currentFileIndex = app.currentFileIndex + 1;
            app.patientID = erase(app.files(app.currentFileIndex),'.mat');
            % If index exceeds the number of files, wrap around to the first file
            if app.currentFileIndex > length(app.ecgFileList)
                app.currentFileIndex = 1;  % Go back to the first file
            end
        
            % Load the next ECG file
            loadNextECGFile(app);
        end

        function LoadECGButtonPushed(app, event)
            % Open a dialog for the user to select multiple ECG files
            cla(app.ECGAxes1)
            cla(app.ECGAxes2)
            cla(app.ECGAxes3)
            cla(app.PCAAxes)
            [files, path] = uigetfile('*.mat', 'Select ECG Files', 'MultiSelect', 'on');
            app.path = path;
            app.files = files;
            % Ensure files were selected
            if iscell(files) || ischar(files) % Handles multiple or single file selection
                % Store the full file paths of the selected files
                if iscell(files) % If multiple files are selected
                    app.ecgFileList = fullfile(path, files);
                else % If only a single file is selected
                    app.ecgFileList = {fullfile(path, files)};
                end
        
                % Initialize file index to 1 (first file)
                app.currentFileIndex = 1;
                if iscell(files)
                    app.patientID = erase(files(app.currentFileIndex),'.mat');
                else
                    app.patientID = erase(files,'.mat');
                end

                % Load the first file
                loadNextECGFile(app);
            else
                disp('No files selected.');
            end
        end

        function clearAxes(app)
            % Clears the 12-lead ECG axes when a new file is loaded
            axesHandles = findall(app.ecgFigure, 'Type', 'axes');
            for i = 1:length(axesHandles)
                cla(axesHandles(i));  % Clear content but keep axes
            end
        end

        function plot12LeadECG(app, signal)
            % signal: 12xN ECG matrix (rows=leads, columns=samples)
            lead_names = {'I','V1','II','V2','III','V3','aVR','V4', 'aVL','V5','aVF','V6'};   
            % Create a new figure for the 12-lead ECG
            % app.ecgFigure = figure('Name', ['12-Lead ECG - ' app.patientID{1}]);
            app.ecgFigure = figure('Name', ['12-Lead ECG']);
            % Set up a 6x2 grid layout for 12 subplots (12-lead ECG)
            for col = 1:2
                for row = 1:6
                    % Correct indexing: Access the correct lead using the row index
                    lead_idx = (row-1)*2 + col;  % This will give values from 1 to 12 for the 12 leads
        
                    % Create a subplot for each lead
                    subplot(6, 2, (row-1)*2 + col);
        
                    if col == 1
                        plot(signal(row, :));
                    else
                        plot(signal(row+6, :));
                    end
        
                    % Set the title, labels, and axis limits for each subplot
                    title(['Lead ' num2str(lead_names{lead_idx})]);
                    set(gca, 'XTickLabel', [])
                    if row == 6
                        xlabel('Sample');
                    end
                end
            end  
        end

        function plot12LeadECG2(app, signal, correctedLeads)
            % signal: 12xN ECG matrix (rows=leads, columns=samples)
            % correctedLeads: 12x1 logical array indicating which leads were corrected
            
            if strcmp(get(app.ecgFigure, 'Visible'),'on')
                figure(app.ecgFigure);
            end
            
            lead_names = {'I','V1','II','V2','III','V3','aVR','V4', 'aVL','V5','aVF','V6'};
            
            % Set up a 6x2 grid layout for 12 subplots (12-lead ECG)
            for col = 1:2
                for row = 1:6
                    % Correct indexing: Access the correct lead using the row index
                    lead_idx = (row-1)*2 + col;  % This will give values from 1 to 12 for the 12 leads
                    
                    % Determine actual lead number in the signal matrix
                    if col == 1
                        actual_lead = row;  % Leads 1-6 (I, II, III, aVR, aVL, aVF)
                    else
                        actual_lead = row + 6;  % Leads 7-12 (V1-V6)
                    end
                    
                    % Only replot if this lead was corrected
                    if nargin < 3 || correctedLeads(actual_lead)
                        % Create/select subplot for this lead
                        subplot(6, 2, (row-1)*2 + col);

                        hold on;
                        plot(signal(actual_lead, :), 'Color', [0.9290 0.6940 0.1250]);
                        
                        % Set the title, labels, and axis limits for each subplot
                        title(['Lead ' num2str(lead_names{lead_idx}) ' (Corrected)'], 'Color', [0.9290 0.6940 0.1250]);
                        set(gca, 'XTickLabel', [])
                        if row == 6
                            xlabel('Sample');
                        end
                        % grid on;
                    else
                        % Just update the subplot if it exists but don't change the plot
                        subplot(6, 2, (row-1)*2 + col);
                        % Keep existing plot, just ensure title is standard
                        if ~isempty(get(gca, 'Children'))
                            title(['Lead ' num2str(lead_names{lead_idx})]);
                        end
                    end
                end
            end
        end

        function loadNextECGFile(app)
            multiplier = 1;
            % Get the file name of the next ECG recording
            filename = app.ecgFileList{app.currentFileIndex};
            
            % Load ECG data from the file
            app.ecgData = load(filename);  % Replace with your actual load function
            
            ECG12Lead_bwr = app.ecgData.ECG12Lead_bwr*multiplier;
            spiked_ECG = ECG12Lead_bwr';
            kors_ecg = kors(spiked_ECG');
            axes1_first = plot(app.ECGAxes1, kors_ecg(:,1));
            hold(app.ECGAxes1, 'on');
            axes2_first = plot(app.ECGAxes2, kors_ecg(:,2));
            hold(app.ECGAxes2, 'on');
            axes3_first = plot(app.ECGAxes3, kors_ecg(:,3));
            hold(app.ECGAxes3, 'on');
            % Check if there is an existing figure for the 12-lead ECG and close it
            if ishandle(app.ecgFigure)
               clearAxes(app);  % Close the previous figure
            end
            plot12LeadECG(app, app.ecgData.ECG12Lead_bwr');
        end
        
        function ProcessButtonPushed(app, event)
            % Default values
            defaultCutoff = 120;  % Default cutoff frequency
            defaultOrder = 2;     % Default filter order
            multiplier = 1;
            % % Check if custom parameters switch is 'On'
            % if strcmp(app.UseCustomParamsSwitch.Value, 'On')
            %     % Get custom values from user input fields
            %     cutoff = app.HighPassCutoffField.Value;
            %     order = app.FilterOrderField.Value;
            %     app.cutoff = app.HighPassCutoffField.Value;
            %     app.order = app.FilterOrderField.Value;
            %     disp(['Using custom cutoff: ', num2str(cutoff), ', order: ', num2str(order)]);
            % else
            % Use default values
            cutoff = defaultCutoff;
            order = defaultOrder;
            app.cutoff = defaultCutoff;
            app.order = defaultOrder;
            % disp(['Using default filter settings. cutoff: ', num2str(cutoff), ', order: ', num2str(order)]);
            % end
        
            % Apply high-pass filtering
            signal = app.ecgData.ECG12Lead_bwr*multiplier;
            Fs = app.ecgData.fs;
            [b, a] = butter(order, cutoff/(Fs/2), 'high');
            filteredSignal = filtfilt(b, a, signal);
            filteredSignal = filteredSignal';
            % Shannon's energy
            for i = 1:size(filteredSignal,1)
                power_signal(i, :) = filteredSignal(i, :).^2 .* log(filteredSignal(i, :).^2 + eps);
            end
        
            % Perform PCA
            [coeff, score, ~] = pca(power_signal');
            app.pcaData = score(:, 1);  % First principal component
            % Plot the first principal component
            plot(app.PCAAxes, app.pcaData);
            title(app.PCAAxes, 'First Principal Component');
            xlabel(app.PCAAxes, 'Sample Index');
            ylabel(app.PCAAxes, 'Amplitude');
            app.method = 'Normal';
            ApplyThreshold(app)
        end

        % Button pushed function: ApplyThresholdButton
        function ApplyThreshold(app, event)
            % Default values
            defaultThreshold = 4000;  % Default cutoff frequency
            defaultDistance = 10;
            % Check if custom parameters switch is 'On'
            if strcmp(app.UseCustomThresholdSwitch.Value, 'On')
                % Get custom values from user input fields
                app.threshold = app.ThresholdField.Value;
                app.distance = app.DistanceField.Value;
                threshold = app.ThresholdField.Value;
                distance = app.DistanceField.Value;
                % disp(['Using custom peak height: ', num2str(threshold), 'Distance: ', num2str(distance)]);
            else
                % Use default values
                app.threshold = defaultThreshold;
                threshold = defaultThreshold;
                app.distance = defaultDistance;
                distance = defaultDistance;
                % disp(['Using default threshold:  ', num2str(threshold), ' ,Distance: ', num2str(distance)]);
            end
            % Detect peaks using the threshold from the slider
            [peaks, locs] = findpeaks(app.pcaData, 'MinPeakHeight', threshold, 'MinPeakDistance',distance);
            app.spike_locs = locs;
            plotPCA(app)
            app.min_peaks = min(peaks);
            listPeaks(app)
        end

        function plotPCA(app)
            peaks = app.pcaData(app.spike_locs);
            cla(app.PCAAxes)
            plot(app.PCAAxes, app.pcaData);
            hold(app.PCAAxes, 'on');
            plot(app.PCAAxes, app.spike_locs, peaks, 'ro');
            for j = 1:length(app.spike_locs)
                text(app.PCAAxes, app.spike_locs(j)-100,1.05*app.pcaData(app.spike_locs(j)),num2str(app.spike_locs(j)))
            end
            hold(app.PCAAxes, 'off');
        end

        function AmpThreshold(app, event)
            if min(app.pcaData) < 0
                pcaData_2 = app.pcaData + abs(min(app.pcaData));
            end
            locs = app.spike_locs;
            window_size = 5;
            for i = 1:length(locs)
                point = locs(i);
                strt_idx = max(1,point-window_size);
                end_idx = min(length(pcaData_2), point + window_size);
                pcaData_2(strt_idx:end_idx) = 0;
            end

            % pcaData_2(pcaData_2 > 5000) = 0;
            pcaData_2 = movmean(pcaData_2,20);
            default_amplitude_threshold = 30;
            % if strcmp(app.UseCustomAmpSwitch.Value, 'On')
            %     % Get custom values from user input fields
            %     amplitude_threshold = app.AmpField.Value;
            %     app.amplitude_threshold = app.AmpField.Value;
            %     disp(['Using custom Amplitude: ', num2str(amplitude_threshold)]);
            % else
            % Use default values
            amplitude_threshold = default_amplitude_threshold;
            app.amplitude_threshold = default_amplitude_threshold;
            % disp(['Using default setting. Amplitude: ', num2str(amplitude_threshold)]);
            % end
            
            % Find indices where the signal exceeds the threshold
            spike_indices = find(abs(pcaData_2) > amplitude_threshold);
            spike_indices = spike_indices';
            diff_indices = diff(spike_indices);
            group_boundaries = find(diff_indices > 1);  % Points where consecutive spikes stop
        
            % Add first and last groups
            group_start = [spike_indices(1), spike_indices(group_boundaries + 1)];
            group_end = [spike_indices(group_boundaries), spike_indices(end)];
            
            % Step 3: Classify based on the number of consecutive spikes (duration)
            small_spikes = [];
            noise = [];
            
            % Define a duration threshold (e.g., 3 consecutive spikes or fewer for small spikes)
            duration_threshold = 50;
            
            for i = 1:length(group_start)
                group_duration = group_end(i) - group_start(i) + 1;
                
                if group_duration <= duration_threshold && group_duration > 5
                    % Classify as small spikes
                    small_spikes = [small_spikes; group_start(i), group_end(i)];
                else
                    % Classify as noise
                    noise = [noise; group_start(i), group_end(i)];
                end
            end
                  
            % Highlight small spikes in green
            for i = 1:size(small_spikes, 1)
                [peaks,small_spike_indices(i)] = max(app.pcaData(small_spikes(i, 1):small_spikes(i, 2)));
                small_spike_indices(i) = small_spikes(i, 1) + small_spike_indices(i) - 1;
            end
            app.spike_locs = [app.spike_locs; small_spike_indices'];
            plotPCA(app)
            % app.min_peaks = min(peaks);
            listPeaks(app)
            app.method = 'Step 2';
        end

        function listPeaks(app)
            % Display peaks in the UITable
            peakData = num2cell(app.spike_locs);  % Convert peaks to a cell array for display
            app.UITable.Data = peakData;  % Display the peaks in the UITable
        end

        % Callback for the Remove button
        function removeSelectedPeak(app, event)
            % Get the selected peak index from the UITable
            selectedRow = app.UITable.Selection; 
            
            if ~isempty(selectedRow)
                % Remove the selected peak from the peaks array
                app.spike_locs(selectedRow(1)) = [];
                % Update the UITable to reflect the removed peak
                listPeaks(app);
                app.UITable.Selection = [];
                % Update the plot to reflect the removed peak
                plotPCA(app);
            else
                % Display a warning if no peak is selected
                uialert(app.UIFigure, 'Please select a peak to remove.', 'No Selection');
            end
            app.method = 'manual';
        end

        % Button pushed function: SaveToExcelButton
        function SaveToExcelButtonPushed(app, event)
            % Save the current threshold and alpha, beta values to Excel
            if iscell(app.patientID)
                patientID = app.patientID{1};
            else
                patientID = app.patientID;
            end
            threshold = app.threshold;
            distance = app.distance;
            cutoff = app.cutoff;
            order = app.order;
            method = app.method;
            min_peaks = app.min_peaks;
            interpolation = app.interpolation;
            percentage = app.percentage;
            amplitude_threshold = app.amplitude_threshold;
            % Log data to Excel
            % filename = 'ECG_Parameters.xlsx';
            % data = {patientID, cutoff, order, threshold, distance, method, min_peaks, interpolation, percentage, amplitude_threshold};
            % writecell(data, filename, 'WriteMode', 'append');
            % app.ecgFileList(app.currentFileIndex)=[];
        end

        function getPointsFromPlot(app)
            % Create input dialog to enter x-coordinate
            prompt = {'Enter X-coordinate for the point:'};
            dlgtitle = 'Input X-Coordinate';
            dims = [1 35];  % Dialog dimensions (rows, columns)
            definput = {'0'};  % Default value for the input field
            answer = inputdlg(prompt, dlgtitle, dims, definput);

            % If the user didn't cancel the dialog, process the input
            if ~isempty(answer)
                % Convert the input string to a number
                xValue = str2double(answer{1});
                if ~isnan(xValue)  % Ensure the input is a valid number
                    % Add the selected x-coordinate to app.spike_locs
                    if isempty(app.spike_locs)
                        app.spike_locs = xValue;  % Initialize if empty
                    else
                        app.spike_locs = [app.spike_locs; xValue];  % Append the new x-coordinate
                        listPeaks(app);
                        plotPCA(app);
                    end
                    disp(['X-Coordinate Added: ', num2str(xValue)]);  % Output to console for debugging
                else
                    % Display a warning if the input was not a valid number
                    warndlg('Invalid input! Please enter a numeric value.');
                end
            else
                % If the dialog is canceled, display a message
                disp('Operation canceled by the user.');
            end
            app.method = 'manual';
        end
        
        % Button pushed function: ConfirmButton
        function [spike_starts, spike_ends] = ConfirmButtonPushed(app, event)
            if app.Option1RadioButton.Value
                app.OutputLabel.Text = 'By Envelope';
                signal = app.pcaData;
                spike_locs = app.spike_locs;
                spiked_ECG = app.ecgData.ECG12Lead_bwr';
                % Compute the envelope
                envelope_signal = envelope(signal);
                % Apply a smoothing filter
                window_length = 5;  % Adjust the window length for desired smoothness
                smoothed_envelope = movmean(envelope_signal, window_length);
                % Set the percentage (30% default)
                default_per = 0.3;
                if strcmp(app.UseCustomWidthSwitch.Value, 'On')
                    % Get custom values from user input fields
                    percentage = app.WidthField.Value;
                    app.percentage = app.WidthField.Value;
                    % disp(['Using custom Percentage: ', num2str(percentage*100), '%']);
                else
                    % Use default values
                    percentage = default_per;
                    app.percentage = default_per;
                    % disp(['Using default percentage: ', num2str(percentage*100), '%']);
                end
                
                % Initialize arrays to store start and end indices
                spike_starts = zeros(size(spike_locs));
                spike_ends = zeros(size(spike_locs));
                
                % Loop through each spike location
                for i = 1:length(spike_locs)
                    loc = spike_locs(i);
                    
                    % Define a window around the spike (adjust as necessary)
                    window_size = 5;  % Example: 5 samples before and after the spike
                    window_start = max(1, loc - window_size);
                    window_end = min(length(signal), loc + window_size);
                    
                    % Extract the envelope in the window
                    envelope_window = smoothed_envelope(window_start:window_end);
                    
                    % Get the local maximum of the envelope in this window
                    local_max = max(envelope_window);
                    
                    % Define the 30% threshold of the local maximum
                    threshold = percentage * local_max;
                    
                    % Find the start and end points in the window where envelope crosses 50%
                    start_idx = find(envelope_window >= threshold, 1, 'first');
                    end_idx = find(envelope_window >= threshold, 1, 'last');
                    
                    % Convert the window indices to global indices
                    spike_starts(i) = window_start + start_idx - 1;
                    spike_ends(i) = window_start + end_idx - 1;
                end
                app.interpolation = 'Envelope';

            elseif app.Option2RadioButton.Value
                app.OutputLabel.Text = 'By Sample';
                signal = app.pcaData;
                spike_locs = app.spike_locs;
                spiked_ECG = app.ecgData.ECG12Lead_bwr';
                default_per = 5;
                if strcmp(app.UseCustomWidthSwitch.Value, 'On')
                    % Get custom values from user input fields
                    percentage = app.WidthField.Value;
                    app.percentage = app.WidthField.Value;
                    % disp(['Using custom Sample: ', num2str(percentage)]);
                else
                    % Use default values
                    percentage = default_per;
                    app.percentage = default_per;
                    % disp(['Using default percentage: ', num2str(percentage), '%']);
                end
                
                % Initialize arrays to store start and end indices
                spike_starts = zeros(size(spike_locs));
                spike_ends = zeros(size(spike_locs));
                
                % Loop through each spike location
                for i = 1:length(spike_locs)
                    loc = spike_locs(i);
                                      
                    % Convert the window indices to global indices
                    spike_starts(i) = max(1, loc - percentage);
                    spike_ends(i) = min(length(signal), loc + percentage);
                end
                app.interpolation = 'Sample';
            end
        end

        function ResultButtonPushed(app, event)
            if isprop(app,'axes1_new') && ~isempty(app.axes1_new) && isgraphics(app.axes1_new)
                delete(app.axes1_new);
            end
            if isprop(app,'axes2_new') && ~isempty(app.axes2_new) && isgraphics(app.axes2_new)
                delete(app.axes2_new);
            end
            if isprop(app,'axes3_new') && ~isempty(app.axes3_new) && isgraphics(app.axes3_new)
                delete(app.axes3_new);
            end
            
            [spike_starts, spike_ends] = ConfirmButtonPushed(app);
            
            % Initialize variables
            leadNames = {'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6'};
            artifactDetected = false(12, 1); % Track which leads have artifacts
            spiked_ECG = app.ecgData.ECG12Lead_bwr';
            
            % First pass: Detect artifacts based on slope threshold
            for ch = 1:12
                originalSignal = spiked_ECG(ch,:);
                hasArtifact = false;
                
                for i = 1:length(spike_ends)
                    startIndex = spike_starts(i);
                    endIndex = spike_ends(i);
                    
                    if startIndex < 1 || endIndex > length(originalSignal)
                        continue;
                    end
                    
                    segment = originalSignal(startIndex:endIndex);
                    slope = max(abs(diff(segment)));
                    
                    if slope > 23 % slope threshold
                        hasArtifact = true;
                        break;
                    end
                end
                
                artifactDetected(ch) = hasArtifact;
            end
            
            % Create dialog for user review
            dlg = uifigure('Name', 'Artifact Detection Review', 'Position', [100 100 600 500]);
            
            % Create table data
            leadsWithArtifact = leadNames(artifactDetected);
            leadsWithoutArtifact = leadNames(~artifactDetected);
            
            % Create UI components
            uilabel(dlg, 'Position', [20 450 560 30], 'Text', ...
                'Review artifact detection. Check/uncheck leads to override algorithm decision:', ...
                'FontWeight', 'bold', 'FontSize', 12);
            
            % Create checklist for all leads
            uilabel(dlg, 'Position', [20 420 300 20], 'Text', ...
                'Select leads WITH pacing artifacts:', 'FontWeight', 'bold');
            
            % Create checkboxes for each lead
            cbHandles = cell(12, 1);
            for i = 1:12
                row = floor((i-1)/4);
                col = mod(i-1, 4);
                xPos = 30 + col * 140;
                yPos = 380 - row * 30;
                
                cbHandles{i} = uicheckbox(dlg, 'Position', [xPos yPos 120 22], ...
                    'Text', ['Lead ' leadNames{i}], ...
                    'Value', artifactDetected(i));
            end
            
            % Summary labels
            summaryPanel = uipanel(dlg, 'Position', [20 150 560 110], 'Title', 'Summary');
            
            artifactListLabel = uilabel(summaryPanel, 'Position', [10 60 520 20], ...
                'Text', ['Leads WITH artifacts: ' strjoin(leadsWithArtifact, ', ')], ...
                'FontColor', [0.8 0 0]);
            
            noArtifactListLabel = uilabel(summaryPanel, 'Position', [10 30 520 20], ...
                'Text', ['Leads WITHOUT artifacts: ' strjoin(leadsWithoutArtifact, ', ')], ...
                'FontColor', [0 0.6 0]);
            
            % Update summary when checkboxes change
            for i = 1:12
                cbHandles{i}.ValueChangedFcn = @(src, event) updateSummary();
            end
            
            function updateSummary()
                withArtifact = {};
                withoutArtifact = {};
                for j = 1:12
                    if cbHandles{j}.Value
                        withArtifact{end+1} = leadNames{j};
                    else
                        withoutArtifact{end+1} = leadNames{j};
                    end
                end
                
                if isempty(withArtifact)
                    artifactListLabel.Text = 'Leads WITH artifacts: None';
                else
                    artifactListLabel.Text = ['Leads WITH artifacts: ' strjoin(withArtifact, ', ')];
                end
                
                if isempty(withoutArtifact)
                    noArtifactListLabel.Text = 'Leads WITHOUT artifacts: None';
                else
                    noArtifactListLabel.Text = ['Leads WITHOUT artifacts: ' strjoin(withoutArtifact, ', ')];
                end
            end
            
            % Buttons
            confirmBtn = uibutton(dlg, 'Position', [350 50 100 40], ...
                'Text', 'Apply Correction', ...
                'ButtonPushedFcn', @(btn, event) applyCorrection());
            
            cancelBtn = uibutton(dlg, 'Position', [470 50 100 40], ...
                'Text', 'Cancel', ...
                'ButtonPushedFcn', @(btn, event) close(dlg));
            
            % Apply correction function
            function applyCorrection()
                % Get user selections
                userArtifactSelection = false(12, 1);
                for j = 1:12
                    userArtifactSelection(j) = cbHandles{j}.Value;
                end
                
                % Perform correction based on user selection
                corrected_ECG = spiked_ECG;
                
                for ch = 1:12
                    if userArtifactSelection(ch) % Only correct if user marked as having artifact
                        originalSignal = spiked_ECG(ch,:);
                        
                        for i = 1:length(spike_ends)
                            startIndex = spike_starts(i);
                            endIndex = spike_ends(i);
                            
                            if startIndex < 1 || endIndex > length(originalSignal)
                                continue;
                            end
                            
                            % Get previous and next sample indices
                            if startIndex == 1
                                prevSampleIndex = startIndex;
                            else
                                prevSampleIndex = startIndex - 1;
                            end
                            
                            if endIndex == length(originalSignal)
                                nextSampleIndex = endIndex;
                            else
                                nextSampleIndex = endIndex + 1;
                            end
                            
                            % Values at the previous and next indices
                            prevValue = originalSignal(prevSampleIndex);
                            nextValue = originalSignal(nextSampleIndex);
                            
                            % Number of points to interpolate
                            numPoints = endIndex - startIndex + 1;
                            
                            % Generate linearly interpolated values
                            interpolatedValues = linspace(prevValue, nextValue, numPoints);
                            
                            % Replace with interpolated line
                            originalSignal(startIndex:endIndex) = interpolatedValues;
                        end
                        
                        corrected_ECG(ch,:) = originalSignal;
                    end
                end
                
                % Store corrected ECG
                app.corrected_ECG = corrected_ECG;
                
                % Update plots
                kors_ecg_corrected = kors(corrected_ECG');
                app.axes1_new = plot(app.ECGAxes1, kors_ecg_corrected(:,1), 'Color', [0.9290 0.6940 0.1250]);
                app.axes2_new = plot(app.ECGAxes2, kors_ecg_corrected(:,2), 'Color', [0.9290 0.6940 0.1250]);
                app.axes3_new = plot(app.ECGAxes3, kors_ecg_corrected(:,3), 'Color', [0.9290 0.6940 0.1250]);
                legend(app.ECGAxes1, 'Before', 'After')
                
                % Plot 12-lead ECG
                plot12LeadECG2(app, app.corrected_ECG, userArtifactSelection);
                
                % Close dialog
                close(dlg);
            end
            
            % Wait for dialog to close
            uiwait(dlg);
        end

        function MoveToErrorButtonPushed(app, event)  
            hold(app.ECGAxes1, 'off');
            hold(app.ECGAxes2, 'off');
            hold(app.ECGAxes3, 'off');
            file = app.ecgFileList(app.currentFileIndex);
            Error_folder = [app.path 'Error' '\'];
            if (exist(Error_folder) == 0)
                mkdir(Error_folder);
            end
            movefile(file{1},Error_folder)
            NextButtonPushed(app);  
        end

        function MoveToReviewButtonPushed(app, event)
            app.ecgData.ECG12Lead_bwr_old = app.ecgData.ECG12Lead_bwr;
            app.ecgData.ECG12Lead_bwr = app.corrected_ECG;
            SaveToExcelButtonPushed(app);
            file = app.ecgFileList(app.currentFileIndex);
            ECG12Lead_bwr_old = app.ecgData.ECG12Lead_bwr_old;
            ECG12Lead_bwr = app.ecgData.ECG12Lead_bwr';
            save(file{1},'ECG12Lead_bwr_old','ECG12Lead_bwr',"-append")
            Reviewed_folder = [app.path 'Reviewed' '\'];
            if (exist(Reviewed_folder) == 0)
                mkdir(Reviewed_folder);
            end
            movefile(file{1},Reviewed_folder)
            NextButtonPushed(app); 
        end

        function NoButtonPushed(app, event)
            hold(app.ECGAxes1, 'off');
            hold(app.ECGAxes2, 'off');
            hold(app.ECGAxes3, 'off');
            file = app.ecgFileList(app.currentFileIndex);
            NoChange_folder = [app.path 'No change' '\'];            
            if (exist(NoChange_folder) == 0)
                mkdir (NoChange_folder);
            end            
            movefile(file{1},NoChange_folder)
            NextButtonPushed(app); 
        end

    end

    % App initialization and construction
    methods (Access = public)

        % Constructor
        function app = ECGApp_final
            % Create UIFigure and components
            createComponents(app);
        end

        
        % Create UI components
        function createComponents(app)
            
            % Create the main figure for the app
            app.UIFigure = uifigure('Position', [100, 100, 800, 600]);
            % Create the first UIAxes (for first ECG plot)
            app.ECGAxes1 = uiaxes(app.UIFigure, 'Position', [80, 500, 300, 200]);
            title(app.ECGAxes1, 'X/Corrected X');

            % Create the second UIAxes (for the first principal component)
            app.ECGAxes2 = uiaxes(app.UIFigure, 'Position', [80, 275, 300, 200]);
            title(app.ECGAxes2, 'Y/Corrected Y');

            % Create the third UIAxes (for the 12-lead ECG after peak replacement)
            app.ECGAxes3 = uiaxes(app.UIFigure, 'Position', [80, 40, 300, 200]);
            title(app.ECGAxes3, 'Z/Corrected Z');

            app.PCAAxes = uiaxes(app.UIFigure, 'Position', [400, 275, 300, 400]);
            title(app.PCAAxes, 'First Principal Component');
            app.RemoveButton = uibutton(app.UIFigure, 'push', 'Position', [600, 210, 60, 22], 'Text', 'Remove', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) removeSelectedPeak(app));
            app.AddButton = uibutton(app.UIFigure, 'push', 'Position', [680, 210, 60, 22], 'Text', 'Add', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) getPointsFromPlot(app));
            app.UITable = uitable(app.UIFigure, 'Position', [600, 50, 100, 150]);
            app.UITable.ColumnName = {'Peak Index'};
            
            % app.ResAxes = uiaxes(app.UIFigure, 'Position', [400, 50, 300, 200]);
            app.LoadECGButton = uibutton(app.UIFigure, 'push', 'Position', [20, 570, 50, 22], 'Text', 'Load ECG', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) LoadECGButtonPushed(app));
            app.UseCustomThresholdLabel = uilabel(app.UIFigure, 'Position', [20, 510, 50, 30], 'Text', 'Custom Threshold');
            app.UseCustomThresholdSwitch = uiswitch(app.UIFigure, 'Position', [20, 500, 50, 22], 'Items', {'Off', 'On'}, 'Value', 'Off');
            app.PeakHeightLabel = uilabel(app.UIFigure, 'Position', [50, 480, 50, 22], 'Text', 'Height');
            app.ThresholdField = uieditfield(app.UIFigure, 'numeric', 'Position', [20, 460, 50, 22]);
            app.PeakDistLabel = uilabel(app.UIFigure, 'Position', [50, 440, 50, 22], 'Text', 'Distance');
            app.DistanceField = uieditfield(app.UIFigure, 'numeric', 'Position', [20, 420, 50, 22]);
            app.ProcessButton = uibutton(app.UIFigure, 'push', 'Position', [20, 390, 50, 22], 'Text', 'PROCESS', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) ProcessButtonPushed(app));
            % app.UseCustomThresholdLabel = uilabel(app.UIFigure, 'Position', [20, 350, 50, 30], 'Text', 'Small spike');
            % app.UseCustomAmpSwitch = uiswitch(app.UIFigure, 'Position', [20, 330, 50, 22], 'Items', {'Off', 'On'}, 'Value', 'Off');    
            % app.AmpLabel = uilabel(app.UIFigure, 'Position', [20, 310, 70, 22], 'Text', 'Amplitude');
            % app.AmpField = uieditfield(app.UIFigure, 'numeric', 'Position', [20, 290, 50, 22]);
            app.AmpThresholdButton = uibutton(app.UIFigure, 'push', 'Position', [20, 220, 50, 22], 'Text', 'Step 2', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) AmpThreshold(app));
            app.UseCustomWidthLabel = uilabel(app.UIFigure, 'Position', [380, 210, 120, 30], 'Text', '%Envelope/Sample');
            app.UseCustomWidthSwitch = uiswitch(app.UIFigure, 'Position', [400, 185, 50, 22], 'Items', {'Off', 'On'}, 'Value', 'Off');
            app.WidthField = uieditfield(app.UIFigure, 'numeric', 'Position', [380, 160, 50, 22]);
            app.ButtonGroup = uibuttongroup(app.UIFigure, 'Position', [380, 50, 100, 60]);
            app.Option1RadioButton = uiradiobutton(app.ButtonGroup, 'Text', 'Envelope', 'Position', [10 25 100 50]);
            app.Option2RadioButton = uiradiobutton(app.ButtonGroup, 'Text', 'Sample', 'Position', [10 1 100 50]);
            app.OutputLabel = uilabel(app.UIFigure, 'Position', [400 140 150 30]);
            app.OutputLabel.Text = '';
            app.ResultButton = uibutton(app.UIFigure, 'push', 'Position', [20, 130, 50, 22], 'Text', 'Plot Result', 'ButtonPushedFcn', @(~,~) ResultButtonPushed(app));
            app.NoChangeButton = uibutton(app.UIFigure, 'push', 'Position', [20, 100, 50, 22], 'Text', 'No transformation', 'ButtonPushedFcn', @(~,~) NoButtonPushed(app));
            app.MoveToError = uibutton(app.UIFigure, 'push', 'Position', [20, 60, 50, 25], 'Text', 'Error', 'ButtonPushedFcn', @(~,~) MoveToErrorButtonPushed(app)); 
            app.MoveToReview = uibutton(app.UIFigure, 'push', 'Position', [20, 30, 50, 22], 'Text', 'Reviewed', 'ButtonPushedFcn', @(~,~) MoveToReviewButtonPushed(app));                   
        end
    end
end

