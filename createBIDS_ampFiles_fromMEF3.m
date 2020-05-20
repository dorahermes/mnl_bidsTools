% 
%   Generate BIDS iEEG amplifier metadata files based on a MEF3 dataset
%
%   createBIDS_ampFiles_fromMEF3(inputMef, outputDir)
%
%   inputMef          = MEF3 input, either as a path to the MEF3 session folder or a MEF3 struct (see 'matmef' function 'read_mef_session_metadata');
%                       If left empty, a dialog box will prompt for a directory
%   outputDir         = The folder to which the output should be written; If left empty, a dialog box will prompt for a directory.
%                       The following BIDS files will be generated and stored in the folder:
%                           <datetime>_channels.tsv
%                           <datetime>_ieeg.json
%
%
%   Example:
%
%       createBIDS_ampFiles_fromMEF3('./mefSessionFolder/', './bidsOutputFolder')
%
%
%   Copyright 2020, Dora Hermes & Max van den Boom (Multimodal Neuroimaging Lab, Mayo Clinic, Rochester MN)

%   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
%   as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
%   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied 
%   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
%   You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
function createBIDS_ampFiles_fromMEF3(inputMef, outputDir)
    if ~exist('inputMef', 'var'),           inputMef = []; end
    if ~exist('outputDir', 'var'),          outputDir = []; end
    
    %
    % check (and/or prompt) the MEF3 input
    %
    if isempty(inputMef)
        disp('- Select the input MEF3 session directory in the folder selection dialog -');
        inputMef = uigetdir(pwd, 'Select the input MEF3 session directory');
        if inputMef == 0,   return;     end
    end
    if isstruct(inputMef)        
        % TODO: additional checks?
        
    elseif ischar(inputMef)
        
        % load the MEF3 session from the given path
        inputMef = readMef3(inputMef);
        if isempty(inputMef)
           return; 
        end
        
    else
        fprintf(2, 'Error: invalid MEF3 input argument. Pass a MEF3 session directory, a MEF3 struct or leave empty for a folder selection dialog box\n');
        return;
    end
    
    
    %
    % check the output folder
    %
    if isempty(outputDir)
        disp('- Select an output directory in the folder selection dialog -');
        outputDir = uigetdir(pwd, 'Select an output directory');
        if outputDir == 0,   return;     end
    end
    if ischar(outputDir)
        if ~exist(outputDir, 'dir')
            fprintf(2, ['Error: output directory ''', outputDir, ''' could not be found\n']);
            return;
        end
    else
        fprintf(2, 'Error: invalid output argument. Pass a directory or leave empty for a folder selection dialog box\n');
        return;
    end

    
    % 
    % order the channels using the channel metadata (if possible)
    % using channel->metadata->section_2->acquisition_channel_number
    % 

    % list the acquisition channel numbers
    acqChNum = [];
    for ii = 1:inputMef.number_of_time_series_channels
        acqChNum(ii) = inputMef.time_series_channels(ii).metadata.section_2.acquisition_channel_number;
    end

    % sort the channels
    [ordAcqChNum, prevIndex] = sort(acqChNum);

    % check if channel numbers start at one
    if min(acqChNum) ~= 1
        warning('on'); warning('backtrace', 'off');
        warning('The acquisition channel count does not start at 1, check the (metadata) output to see if ordered correctly');
    end

    % check if not consecutive
    if ~isempty(setdiff(min(acqChNum):max(acqChNum), acqChNum))
        warning('on'); warning('backtrace', 'off');
        warning('The acquisition channel count is not consecutive, check the (metadata) output to see if ordered correctly');
    end

    % re-order the channels in the metadata
    for ii = 1:length(ordAcqChNum)
        tmpStruct(ii) = inputMef.time_series_channels(prevIndex(ii));
    end
    inputMef.time_series_channels = tmpStruct;
    
    
    
    %
    % build a channels structure for the BIDS _channel.tsv table
    %
    
    channels = [];
    
    % loop through the channels
    counter = 1;
    for iChannel = 1:length(inputMef.time_series_channels)
        
        % include only channels of the TIME_SERIES_CHANNEL_TYPE
        if inputMef.time_series_channels(iChannel).channel_type == 1
            
            % pass to variable for readability below
            section2 = inputMef.time_series_channels(iChannel).metadata(1).section_2;
                        
            % name, type and units (must be present)
            channels(counter).name                  = inputMef.time_series_channels(iChannel).name;
            channels(counter).type                  = 'n/a';                                           % can be any per channel (e.g. ECOG, SEEG, ECG, EMG, EOG), default to 'ieeg'
            if strcmpi(section2.units_description, 'microvolts')
                channels(counter).units             = [native2unicode([194, 181],'UTF-8') 'V'];
            else
                channels(counter).units             = section2.units_description;
            end
            
            % cutoffs
            if ~isempty(section2.low_frequency_filter_setting) &&  section2.low_frequency_filter_setting > 0
                channels(counter).low_cutoff        = section2.low_frequency_filter_setting;
            else
                channels(counter).low_cutoff        = 'n/a';                                       % TODO: n/a instead of 0? (https://github.com/bids-standard/bids-starter-kit/blob/master/matlabCode/createBIDS_ieeg_channels_tsv.m), leave out, Ask dora
            end
            if ~isempty(section2.high_frequency_filter_setting) &&  section2.high_frequency_filter_setting > 0
                channels(counter).high_cutoff       = section2.high_frequency_filter_setting;
            else
                channels(counter).high_cutoff       = 'n/a';                                       % TODO: n/a instead of 0? (https://github.com/bids-standard/bids-starter-kit/blob/master/matlabCode/createBIDS_ieeg_channels_tsv.m), leave out, Ask dora
            end
            
            % reference
            if ~isempty(section2.reference_description)
                channels(counter).reference         = section2.reference_description;
            else
                channels(counter).reference         = 'intracranial';                                    % TODO: from example, n/a?, ask dora..
            end
            
            % group and sampling frequency
            channels(counter).group                 = 'n/a';                                            % TODO: from example, leave out?, ask dora
            channels(counter).sampling_frequency    = section2.sampling_frequency;
            
            % notch
            if ~isempty(section2.notch_filter_frequency_setting) && section2.notch_filter_frequency_setting > 0
                channels(counter).notch             = section2.notch_filter_frequency_setting;
            else 
                channels(counter).notch             = 'n/a';                                    % TODO: n/a instead of 0? (https://github.com/bids-standard/bids-starter-kit/blob/master/matlabCode/createBIDS_ieeg_channels_tsv.m), leave out, Ask dora
            end
            
            % status
            channels(counter).status                = 'n/a';                                        % TODO: from example, leave out?, ask dora
            channels(counter).status_description    = 'n/a';                                        % TODO: from example, leave out?, ask dora
            
            
            % next output entry
            counter = counter + 1;
            
        end
        
    end
    
    
    %
    % build a ieeg struct for the BIDS _ieeg.json output
    %
    
    ieeg = [];
    ieeg.TaskName = '';
    ieeg.SamplingFrequency = inputMef.time_series_metadata.section_2.sampling_frequency;
    ieeg.PowerLineFrequency = '';
    ieeg.SoftwareFilters = '';
    ieeg.DCOffsetCorrection = '';
    ieeg.HardwareFilters = [];
    ieeg.HardwareFilters.HighpassFilter = [];
    ieeg.HardwareFilters.HighpassFilter.CutoffFrequency = inputMef.time_series_metadata.section_2.high_frequency_filter_setting;
    ieeg.HardwareFilters.LowpassFilter = [];
    ieeg.HardwareFilters.LowpassFilter.CutoffFrequency = inputMef.time_series_metadata.section_2.low_frequency_filter_setting;
    ieeg.Manufacturer = '';
    ieeg.ManufacturersModelName = '';
    ieeg.TaskDescription = '';
    ieeg.Instructions = '';
    ieeg.CogAtlasID = '';
    ieeg.CogPOID = '';
    ieeg.InstitutionName = '';
    ieeg.InstitutionAddress = '';
    ieeg.DeviceSerialNumber = '';
    ieeg.ECOGChannelCount = 0;
    ieeg.SEEGChannelCount = 0;
    ieeg.EEGChannelCount = 0;
    ieeg.EOGChannelCount = 0;
    ieeg.ECGChannelCount = 0;
    ieeg.EMGChannelCount = 0;
    ieeg.MiscChannelCount = 0;
    ieeg.TriggerChannelCount = 0;
    ieeg.RecordingDuration = ((double(inputMef.latest_end_time)-double(inputMef.earliest_start_time))./1000000);                   
    ieeg.RecordingType = 'continuous';
    ieeg.EpochLength = 0;
    ieeg.SubjectArtefactDescription = '';
    ieeg.SoftwareVersions = '';
    ieeg.iEEGReference = '';
    ieeg.ElectrodeManufacturer = '';
    ieeg.ElectrodeManufacturersModelName = '';
    ieeg.iEEGGround = '';
    ieeg.iEEGPlacementScheme = '';
    ieeg.iEEGElectrodeGroups = '';
    ieeg.ElectricalStimulation = '';
    ieeg.ElectricalStimulationParameters = '';
    
    %
    % write the channel struct to a tab-seperated file (_channels.tsv)
    %
    if ~isempty(channels)
        writetable( struct2table(channels), ...
                    [outputDir, filesep, datestr(now, 'yyyymmdd_HHMMSS_FFF'), '_channels.tsv'], ...
                    'FileType', 'text', 'Delimiter', '\t', 'Encoding', 'UTF-8');
    end
    
    %
    % write the ieeg struct to a JSON file (_ieeg.json)
    %
    fileID = fopen([outputDir, filesep, datestr(now, 'yyyymmdd_HHMMSS_FFF'), '_ieeg.json'], 'w', 'native', 'UTF-8');
    writeElement(fileID, ieeg, '');
    fprintf(fileID,'\n');
    fclose(fileID);

end


%%%
%
% Simple JSON write functions
% 
% Needed since matlab's jsonencode function does not provide any indentation or linebreaks to make it 
% human readable (which is exactly one of the advantages of using JSON)
% 
% Code adapted from:
% Lior Kirsch (2020). Structure to JSON (https://www.mathworks.com/matlabcentral/fileexchange/50965-structure-to-json), MATLAB Central File Exchange. Retrieved February 6, 2020.
% 
%%%

function writeElement(fid, data, tabs)
    namesOfFields = fieldnames(data);
    numFields = length(namesOfFields);
    tabs = sprintf('%s\t', tabs);
    fprintf(fid,'{\n%s', tabs);
   
    for i = 1:numFields - 1
        currentField = namesOfFields{i};
        currentElementValue = data.(currentField);
        writeSingleElement(fid, currentField, currentElementValue, tabs);
        fprintf(fid,',\n%s', tabs);
    end
    if isempty(i)
        i = 1;
    else
        i = i + 1;
    end
    
    currentField = namesOfFields{i};
    currentElementValue = data.(currentField);
    writeSingleElement(fid, currentField, currentElementValue,tabs);
    
    if ~isempty(tabs),    tabs = tabs(1:end-1);   end
    fprintf(fid,'\n%s}',tabs);
end

function writeSingleElement(fid, currentField,currentElementValue,tabs)
    if length(currentElementValue) > 1 && ~ischar(currentElementValue)
        fprintf(fid,'"%s": %s' , currentField, jsonencode(currentElementValue));
    elseif isstruct(currentElementValue)
        fprintf(fid,'"%s": ',currentField);
        writeElement(fid, currentElementValue,tabs);
    elseif isnumeric(currentElementValue)
        fprintf(fid,'"%s": %g' , currentField, currentElementValue);
    elseif ischar(currentElementValue)
        fprintf(fid,'"%s": "%s"' , currentField, currentElementValue);
    elseif isempty(currentElementValue)
        fprintf(fid,'"%s": ""' , currentField);
    else
        fprintf(fid,'"%s": "%s"' , currentField, currentElementValue);
    end
end
