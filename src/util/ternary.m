% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function out = ternary(cond, a, b)
% TERNARY  a if cond is true, else b - for choosing a value inside an expression.
%
%   Extracted because the settings code had grown four private copies of it,
%   plus one in nestappDoctor; same argument as plural and fieldOr.
%
%   Example
%     set(h, 'Enable', ternary(isOff, 'off', 'on'))

if cond, out = a; else, out = b; end
end
