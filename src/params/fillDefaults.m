% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function s = fillDefaults(s, defaults)
% FILLDEFAULTS  Fill in missing or empty fields of an options struct.
%   s = FILLDEFAULTS(s, defaults) copies every field of defaults that s either
%   lacks or holds empty. Fields s already has a non-empty value for are left
%   alone, and fields not mentioned in defaults are passed through untouched.
%
%   Empty counts as absent deliberately. Callers throughout this codebase build
%   options structs field by field and leave a field as [] to mean "you choose",
%   so treating [] as a real value would make `struct('roi', [])` behave
%   differently from omitting roi entirely.
%
%   This idiom had accumulated five near-identical copies - qualityGate's
%   applyDefaults plus one local helper in each new options-taking function -
%   which is four opportunities for them to drift on the empty-vs-absent
%   question.
%
%   Example
%     opts = fillDefaults(opts, struct('mode', 'TEP', 'level', 0.95));
%
%   See also: struct, isfield

if nargin < 2 || isempty(defaults); return; end
if isempty(s); s = struct(); end

names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(s, names{k}) || isempty(s.(names{k}))
        s.(names{k}) = defaults.(names{k});
    end
end
end
