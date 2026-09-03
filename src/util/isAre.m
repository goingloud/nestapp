% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = isAre(n)
% ISARE  Subject-verb agreement for a count: 'is' when n is 1, else 'are'.
%
%   Companion to plural, extracted for the same reason: it had reached two
%   copies, and a user-facing sentence that disagrees with itself in one place
%   and not another reads as a bug in the app.
%
%   Example
%     sprintf('%d channel%s %s missing', n, plural(n), isAre(n))
%
%   See also: plural

if n == 1; s = 'is'; else; s = 'are'; end
end
