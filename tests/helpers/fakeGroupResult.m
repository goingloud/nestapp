% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function res = fakeGroupResult(o)
% FAKEGROUPRESULT  A groupCurves result, produced by groupCurves itself.
%   res = FAKEGROUPRESULT()
%   res = FAKEGROUPRESULT('groups', 2, 'subjects', 4, 'design', 'paired', ...)
%
%   Options:
%     groups    2            number of groups
%     subjects  4            subjects per group
%     design    'unpaired'   'paired' | 'unpaired'
%     level     0.95         confidence level, recorded in res.info.level
%     gain      1            amplitude scaling, so the groups differ
%     repeats   1            extra recordings, so .files out-numbers .subjects
%
%   IT CALLS THE REAL FUNCTION rather than hand-building the struct. An earlier
%   version fabricated .groups, .est and .contrast directly, which meant the
%   fixture encoded a SECOND, independent belief about what groupCurves
%   returns - and a fixture that drifts from the contract keeps every
%   downstream test green while the real thing has changed. That is precisely
%   the failure this rewrite exists to undo; there was no reason to build a
%   fresh instance of it in the helper layer.
%
%   Building the INPUT and letting groupCurves produce the output also deleted
%   about forty lines of struct assembly, and means a new field on the result
%   appears here automatically instead of being missed.
%
%   The trade: a bug in groupCurves now fails its own tests AND everything
%   downstream. That is the right direction - the alternative is drawer tests
%   passing against a shape the app no longer produces.
%
%   groupCurves is pure, so this stays usable from tests/pure. Tests OF
%   groupCurves use fakeReducedCache directly and call it themselves, which is
%   what keeps this from being circular.
%
%   See also: fakeReducedCache, groupCurves, fakeEeg

arguments
    o.groups   (1,1) double {mustBePositive} = 2
    o.subjects (1,1) double {mustBePositive} = 4
    o.design   char {mustBeMember(o.design, {'paired', 'unpaired'})} = 'unpaired'
    o.level    (1,1) double = 0.95
    o.gain     (1,1) double = 1
    o.repeats  (1,1) double {mustBeNonnegative} = 1
end

[cache, entries] = fakeReducedCache('subjects', o.subjects, ...
                                    'sessions', o.groups, ...
                                    'repeats',  o.repeats, ...
                                    'amp',      o.gain);

res = groupCurves(cache, entries, struct( ...
    'roi',    {{'F3', 'FC1'}}, ...
    'mode',   'TEP', ...
    'design', o.design, ...
    'level',  o.level));
end
