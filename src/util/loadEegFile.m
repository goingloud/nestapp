% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function EEG = loadEegFile(filePath)
% LOADEEGFILE  Read one recording, choosing the reader from its extension.
%   EEG = LOADEEGFILE(filePath)
%
%   filePath   full path to a .set, .cnt, .cdt or .vhdr recording
%
%   Returns an EEGLAB EEG struct with .filename set to the basename, matching
%   what the Load Data step has always produced.
%
%   THE FORMAT DISPATCH LIVES HERE, once. It was previously inlined in
%   processOneFile's 'Load Data' case, which made it unreachable from anything
%   that is not a pipeline run - so the raw-data browser could only ever open
%   the .set files the Visualizing tab had already loaded, never the raw
%   recording the user actually selected on the Cleaning tab.
%
%   Errors with identifier 'nestapp:unknownFormat' on an extension it cannot
%   read, so a caller can distinguish "wrong kind of file" from a reader
%   blowing up on a file it accepted.
%
%   Requires EEGLAB (and bva-io for .vhdr); the caller is responsible for
%   ensureEeglabReady, because the reason for wanting it differs by caller.
%
%   See also: processOneFile, ensureEeglabReady, stepRegistry

[pathDir, base, ext] = fileparts(char(filePath));
fileName = [base, ext];
pathName = [pathDir, filesep];

switch lower(ext)
    case '.set'
        EEG = pop_loadset([pathName fileName]);
    case '.cnt'
        EEG = pop_loadcnt([pathName fileName], 'dataformat', 'int32');
    case '.cdt'
        EEG = loadcurry([pathName fileName], 'CurryLocations', 'False');
    case '.vhdr'
        % pop_loadbv takes the folder and name separately, unlike the others.
        EEG = pop_loadbv(pathName, fileName);
    otherwise
        error('nestapp:unknownFormat', ...
            ['Load Data: unrecognized file extension in "%s". ' ...
             'Supported: .set, .cnt, .cdt, .vhdr'], fileName);
end

EEG.filename = fileName;
end
