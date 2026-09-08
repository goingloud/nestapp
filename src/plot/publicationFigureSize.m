% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function size = publicationFigureSize(opts)
% PUBLICATIONFIGURESIZE  Resolve a figure's physical size and type size.
%   size = PUBLICATIONFIGURESIZE(opts)
%
%   opts (all optional):
%     .width     'single' (89 mm) | 'double' (183 mm) | a number of mm, or the
%                same number as TEXT - see below
%     .height    mm; default 0.62 x width
%     .fontSize  points; default derived from the width
%
%   Returns .widthMm .heightMm .fontSize.
%
%   THE WIDTH ACCEPTS TEXT THAT LOOKS LIKE A NUMBER, deliberately. The setting
%   has to offer the words 'single' and 'double', so the dialog stores it as
%   text - which means a millimetre value typed there arrives as '400', not
%   400. Erroring on that made the millimetre option this function advertises
%   unreachable from the only interface that sets it.
%
%   THE TYPE SHRINKS WITH THE PAGE. The same 8 pt that reads well across 183 mm
%   overlaps six column titles at 89 mm, and journals generally floor at 5 to
%   7 pt - hence the clamp rather than a bare proportion.
%
%   Extracted from publicationFigure because this is a millimetre lookup and a
%   clamp, and testing it used to mean composing NINE FIGURES to read numbers
%   back out - the fixture's own comment said so ("Compose an empty figure just
%   to read back the size that was resolved").
%
%   See also: publicationFigure

SINGLE_MM = 89;    % typical journal single column
DOUBLE_MM = 183;   % typical journal double column / full width

if nargin < 1; opts = struct(); end
opts = fillDefaults(opts, struct('width', 'double', 'height', [], ...
                                 'fontSize', []));

widthMm = opts.width;
if ischar(widthMm) || isstring(widthMm)
    switch lower(strtrim(char(widthMm)))
        case 'single', widthMm = SINGLE_MM;
        case 'double', widthMm = DOUBLE_MM;
        otherwise,     widthMm = str2double(widthMm);
    end
end
if ~isnumeric(widthMm) || ~isscalar(widthMm) || ~isfinite(widthMm) || widthMm <= 0
    error('nestapp:badFigureWidth', ...
          ['Width must be ''single'' (89 mm), ''double'' (183 mm), or a ' ...
           'positive number of millimetres; got ''%s''.'], ...
          char(string(opts.width)));
end

heightMm = opts.height;
if isempty(heightMm); heightMm = widthMm * 0.62; end

fontSize = opts.fontSize;
if isempty(fontSize)
    fontSize = max(5, min(9, round(8 * widthMm / DOUBLE_MM)));
end

size = struct('widthMm', widthMm, 'heightMm', heightMm, 'fontSize', fontSize);
end
