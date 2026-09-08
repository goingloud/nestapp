% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function p = makeParam(key, friendlyName, unit, validRange, description, varargin)
% MAKEPARAM  One parameter's metadata, for any registry that has parameters.
%   p = MAKEPARAM(key, friendlyName, unit, validRange, description, ...)
%
%   Optional name-value pairs:
%     'placeholder' - shown in the table for [] values, e.g. '(all channels)'.
%                     By convention it starts with '(' so styleParamTable greys
%                     it, and it should NAME THE DEFAULT where there is one -
%                     that keeps the default itself in exactly one place (the
%                     function that applies it) while still telling the reader
%                     what leaving the cell alone will do.
%     'type'        - scalar (default) | integer | vector | logical | string |
%                     stringlist | folder | file. folder/file behave exactly as
%                     string; they record that the value is a path.
%     'required'    - true when the owner cannot run until the user supplies a
%                     value. Used to prompt on load rather than letting the run
%                     fail later, and kept as data here so the check is not
%                     hardcoded in the GUI.
%     'choicesFrom' - name of a CONTEXT key supplying this param's choices, for
%                     a list that is not knowable when the registry is written.
%                     "Which windows to map" is the case: the windows are the
%                     ones in the user's table right now, so they cannot be a
%                     validRange. The form is handed a context struct and reads
%                     the named field from it.
%
%   Lifted out of stepRegistry when plotRegistry needed the same shape. The
%   whole param toolchain - buildParamTableData, applyParamEdit, convertParam,
%   disabledParamKeys, styleParamTable - reads these fields and nothing else,
%   so anything built with this constructor gets the editor for free. A second
%   near-identical struct would have meant those five functions quietly
%   supporting two shapes.
%
%   See also: stepRegistry, plotRegistry, buildParamTableData, convertParam

placeholder = ''; type = 'scalar'; required = false; choicesFrom = '';
if mod(numel(varargin), 2) ~= 0
    error('makeParam:oddArgs', 'Name-value arguments must come in pairs.');
end
for i = 1:2:numel(varargin)
    switch lower(varargin{i})
        case 'placeholder'; placeholder = varargin{i+1};
        case 'type';        type = varargin{i+1};
        case 'required';    required = logical(varargin{i+1});
        case 'choicesfrom'; choicesFrom = varargin{i+1};
        otherwise
            error('makeParam:unknownOpt', 'Unknown option "%s".', varargin{i});
    end
end
p = struct('key',key,'friendlyName',friendlyName,'unit',unit, ...
           'validRange',validRange,'description',description, ...
           'placeholder',placeholder,'type',type,'required',required, ...
           'choicesFrom',choicesFrom);
end
