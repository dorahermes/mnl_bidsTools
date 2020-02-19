% 
%   Generate a BIDS electrode-specific metadata files based on an input .mat file as created by Dora's electrode positioning script [1]
%
%   createBIDS_electrodeFiles(inputMat, outputDir)
%
%   inputMat          = Mat file containing an 'elecmatrix' or an 'out_els' variable. The columns in this variable represent
%                       the x, y and z coordinates, each row represents an electrode
% 
%   outputDir         = The folder to which the output should be written; If left empty, a dialog box will prompt for a directory.
%                       The following BIDS files will be generated and stored in the folder:
%                           <datetime>_electrodes.tsv
%                           <datetime>_coordsystem.json
%
%
%   Example:
%
%       createBIDS_electrodeFiles('./CTMR/electrodes.mat', './bidsOutputFolder')
%
%
%   [1] Hermes D, Miller KJ, Noordmans HJ, Vansteensel MJ, Ramsey NF, 2010. Automated electrocorticographic
%       electrode localization on individually rendered brain surfaces. J Neurosci Methods 185(2):293-8. https://doi.org/10.1016/j.jneumeth.2009.10.005
%  
%   Copyright 2020, Max van den Boom (Multimodal Neuroimaging Lab, Mayo Clinic, Rochester MN)

%   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
%   as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
%   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied 
%   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
%   You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
function createBIDS_electrodeFiles(inputMat, outputDir)
    if ~exist('inputMat', 'var'),           inputMat = []; end
    if ~exist('outputDir', 'var'),          outputDir = []; end
    
    
    %
    % check (and/or prompt) the input mat file
    %
    if isempty(inputMat)
        disp('- Select the input mat file selection dialog -');
        [file, path] = uigetfile('*.mat', pwd, 'Select the input mat file');
        if isequal(file, 0),   return;     end
        inputMat = fullfile(path,file);
    end
    if ischar(inputMat)
        
        % load the mat file from the given path
        load(inputMat);
        
        % check for elecmatrix and out_els
        inputElectrodes = [];
        if exist('elecmatrix', 'var') && ~isempty(elecmatrix)
            inputElectrodes = elecmatrix;
        end
        if exist('out_els', 'var') && ~isempty(out_els)
            inputElectrodes = out_els;
        end
        
        % check if a electrode input variable was found
        if isempty(inputElectrodes)
            fprintf(2, 'Error: the input map file contains neither an ''elecmatrix'' nor an ''out_els variable''\n');
            return; 
        end

        % check if the input format is correct
        if isnumeric(inputElectrodes) && size(inputElectrodes, 2) ~= 3
            fprintf(2, 'Error: the input electrode matrix should have at least three columns, representing the x, y and z coordinates\n');
            return;
        end
        
    else
        fprintf(2, 'Error: invalid input mat file argument. Pass a mat filepath or leave empty for a folder selection dialog box\n');
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
    % build a events struct with the BIDS output
    %
    
    electrodes = [];
    
    % loop through the records
    counter = 1;
    for iElec = 1:size(inputElectrodes, 1)

        % add electrode
        electrodes(counter).name        = iElec;
        electrodes(counter).x           = inputElectrodes(iElec, 1);
        electrodes(counter).y           = inputElectrodes(iElec, 2);
        electrodes(counter).z           = inputElectrodes(iElec, 3);

        % next output entry
        counter = counter + 1;
            
    end
    
    
    %
    % build a coordsystem struct with the BIDS output
    %
    
    coordsystem = [];
    coordsystem.IntendedFor = '';
    coordsystem.iEEGCoordinateSystem = 'Other';
    coordsystem.iEEGCoordinateUnits = 'mm';
    coordsystem.iEEGCoordinateSystemDescription = 'Scanner Native. The coordinate frame of the scanner at data acquisition of the T1w volume';
    coordsystem.iEEGCoordinateProcessingDescription = '';
    coordsystem.iEEGCoordinateProcessingReference = '';
    
    
    %
    % write the electrodes struct to a tab-seperated file (_electrodes.tsv)
    %
    if ~isempty(electrodes)
        writetable( struct2table(electrodes), ...
                    [outputDir, filesep, datestr(now, 'yyyymmdd_HHMMSS_FFF'), '_electrodes.tsv'], ...
                    'FileType', 'text', 'Delimiter', '\t');
    end
    
    %
    % write the coordsystem struct to a JSON file (_coordsystem.json)
    %
    fileID = fopen([outputDir, filesep, datestr(now, 'yyyymmdd_HHMMSS_FFF'), '_coordsystem.json'], 'w');
    writeElement(fileID, coordsystem, '');
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
