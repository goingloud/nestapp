% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function opts = plotDrawOpts(entry, params)
% PLOTDRAWOPTS  Turn stored plot params into a draw function's options struct.
%   opts = PLOTDRAWOPTS(entry, params) takes a plotRegistry entry and the values
%   the user has set for it, and returns them typed the way the draw function
%   expects. Params that were never set are simply absent, so each draw
%   function's own default still applies.
%
%   The one real conversion is 'logical'. Those params are STORED as 'on'/'off'
%   text, because plots share the step parameter editor and that is the form
%   EEGLAB steps need. Draw functions take genuine logicals - and in MATLAB
%   `if 'off'` is TRUE, every character being non-zero, so handing the text
%   straight through would leave every switch the user turned OFF still on,
%   with no error and nothing in the picture to suggest the setting was read at
%   all. Converting here, at the one boundary between the editor's storage and
%   the drawing API, keeps both sides honest about their own types.
%
%   Keys are otherwise passed through untouched: a registry param key IS the
%   draw function's option name, which is what stops this from becoming a
%   translation table that has to be extended for every new setting.
%
%   See also: plotRegistry, plotOptionsDialog, makeParam, convertParam

opts = struct();
if nargin < 2 || isempty(params) || ~isstruct(params); return; end
opts = params;
if isempty(entry.params); return; end

isLogical = strcmp({entry.params.type}, 'logical');
for k = find(isLogical)
    key = entry.params(k).key;
    if ~isfield(opts, key); continue; end
    v = opts.(key);
    if ischar(v) || isstring(v)
        opts.(key) = strcmpi(strtrim(char(v)), 'on');
    end
end
end
