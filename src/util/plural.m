% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = plural(n)
% PLURAL  The 's' for a count: '' when n is 1, 's' otherwise.
%
%   Three lines, but it had three verbatim copies and a fourth spelled out
%   inline. The same argument fillDefaults was extracted for applies: not the
%   lines saved, but that four copies is three chances to disagree.
%
%   Example
%     sprintf('%d file%s', n, plural(n))
%
%   See also: fillDefaults

if n == 1; s = ''; else; s = 's'; end
end
