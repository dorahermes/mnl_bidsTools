% 
%   Generate BIDS ieeg output based on a MEF3 dataset
%
%   genBIDSFromMEF3(inputMef, outputDir)
%
%   inputMef          = MEF3 input. This argument accepts a path to the MEF3 session folder or a MEF3 struct (loaded
%                       using the 'matmef' function 'read_mef_session_metadata'); If left empty, a dialog box will prompt for a directory
%   outputDir         = The folder to which the output should be written; If left empty, a dialog box will prompt for a directory.
%                       The following BIDS files will be generated and stored in the folder:
%                           <datetime>_channels.tsv
%                           <datetime>_ieeg.json
%                           <datetime>_events.tsv
%
%
%   Copyright 2020, Max van den Boom (Multimodal Neuroimaging Lab, Mayo Clinic, Rochester MN)

%   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
%   as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
%   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied 
%   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
%   You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
function genBIDSFromMEF3(inputMef, outputDir)
    if ~exist('inputMef', 'var'),           inputMef = []; end
    if ~exist('outputDir', 'var'),          outputDir = []; end
    
    %
    % check (and/or prompt) the MEF3 input
    %
    if isempty(inputMef)
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
    % build a new channel struct with the BIDS output
    %
    
    channels = [];
    
    % loop through the channels
    counter = 1;
    for iChannel = 1:length(inputMef.time_series_channels)
        
        % include only channels of the TIME_SERIES_CHANNEL_TYPE
        if inputMef.time_series_channels(iChannel).channel_type == 1
            
            % pass to variable for readability below
            section2 = inputMef.time_series_channels(iChannel).metadata(1).section_2;
            
            
            % name and type
            channels(counter).name                  = inputMef.time_series_channels(iChannel).name;
            channels(counter).type                  = 'ieeg';                                           % can be any per channel (e.g. ECOG, SEEG, ECG, EMG, EOG), default to 'ieeg'
            
            % units
            if strcmpi(section2.units_description, 'microvolts')
                channels(counter).units             = 'uV';
            else
                channels(counter).units             = section2.units_description;
            end
            
            % cutoffs
            if ~isempty(section2.low_frequency_filter_setting) &&  section2.low_frequency_filter_setting > 0
                channels(counter).low_cutoff             = section2.low_frequency_filter_setting;
            else
                channels(counter).low_cutoff             = 'n/a';                                       % TODO: n/a instead of 0? (https://github.com/bids-standard/bids-starter-kit/blob/master/matlabCode/createBIDS_ieeg_channels_tsv.m), leave out, Ask dora
            end
            if ~isempty(section2.high_frequency_filter_setting) &&  section2.high_frequency_filter_setting > 0
                channels(counter).high_cutoff             = section2.high_frequency_filter_setting;
            else
                channels(counter).high_cutoff             = 'n/a';                                       % TODO: n/a instead of 0? (https://github.com/bids-standard/bids-starter-kit/blob/master/matlabCode/createBIDS_ieeg_channels_tsv.m), leave out, Ask dora
            end
            
            % reference
            if ~isempty(section2.reference_description)
                channels(counter).reference         = section2.reference_description
            else
                channels(counter).reference         = 'intracranal';                                    % TODO: from example, n/a?, ask dora..
            end
            
            % group and sampling frequency
            channels(counter).group                 = 'n/a';                                            % TODO: from example, leave out?, ask dora
            channels(counter).sampling_frequency    = section2.sampling_frequency;
            
            % description
            if ~isempty(section2.channel_description) && ~strcmpi(section2.channel_description, 'not_entered')
                channels(counter).description       = section2.channel_description;
            else
                
                % TODO: from example, leave out?, ask dora
                channels(counter).description       = 'n/a';
                
            end
            
            % notch
            if ~isempty(section2.notch_filter_frequency_setting) && section2.notch_filter_frequency_setting > 0
                channels(counter).notch                 = section2.notch_filter_frequency_setting;
            else 
                channels(counter).notch                 = 'n/a';                                    % TODO: n/a instead of 0? (https://github.com/bids-standard/bids-starter-kit/blob/master/matlabCode/createBIDS_ieeg_channels_tsv.m), leave out, Ask dora
            end
            
            % status
            channels(counter).status                = 'n/a';                                        % TODO: from example, leave out?, ask dora
            channels(counter).status_description    = 'n/a';                                        % TODO: from example, leave out?, ask dora
            
            
            % next output entry
            counter = counter + 1;
            
        end
        
    end
    
    
    %
    % write the channel struct to a tab-seperated file (.tsv)
    %
    
    writetable( struct2table(channels), ...
                [outputDir, filesep, datestr(now, 'yyyymmdd_HHMMSS_FFF'), '_channels.tsv'], ...
                'FileType', 'text', 'Delimiter', '\t');
    
end
