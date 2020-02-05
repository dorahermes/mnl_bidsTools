% 
%   Generate BIDS ieeg output based on a MEF3 dataset
%
%   genBIDSFromMEF3(inputMef, outputDir)
%
%   inputMef        = the MEF3 input. This argument accepts a path to the MEF3 session folder or a MEF3 struct (preloaded using
%                     the 'matmef' function 'read_mef_session_metadata'); If left empty, a dialog box will prompt for a directory
%   outputDir       = the folder to which the output should be written; If left empty, a dialog box will prompt for a directory.
%                     The following files will be created in the folder:
%                         <datetime>_channels.tsv
%                         <datetime>_ieeg.tsv
%                         <datetime>_events.tsv
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
    %
    %
    inputMef
    
end