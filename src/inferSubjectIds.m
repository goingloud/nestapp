% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [ids, confident] = inferSubjectIds(paths)
% INFERSUBJECTIDS  Guess a subject identifier for each data file.
%   [ids, confident] = INFERSUBJECTIDS(paths) returns a subject id per path and
%   a logical saying whether the guess is trustworthy enough to use unreviewed.
%
%   Why guess at all: a group comparison needs to know which recordings came
%   from the same person - pre/post is a within-subject contrast, and n for any
%   estimate is subjects, not files. Nothing in a .set records that, but the
%   cohort's filenames do:
%
%       rtmsct001_1_pre_SPL_tesa_pipeline4th.set   ->  rtmsct001
%       S01/S01_pre_TEP.set                        ->  S01
%
%   Two candidates are considered, in order of how much they can be trusted:
%
%     1. The parent folder name, when the basename also starts with it. Agreement
%        between two independent parts of the path is the strongest signal there
%        is, so this is taken as confident.
%     2. The basename's first token (split on _ or -). Confident only when it
%        looks like an identifier - letters and at least one digit - because a
%        bare word like "data" or "pre" is far more likely to be a condition
%        than a person.
%
%   Anything else falls back to the first token with confident=false. The caller
%   is expected to SHOW the unconfident ones for review rather than silently
%   trusting them: a wrong subject id merges two people or splits one, and both
%   corrupt the estimate without ever looking wrong on screen.
%
%   Inputs:
%     paths - cellstr (or a single char) of file paths.
%
%   Outputs:
%     ids       - 1xN cellstr of subject ids.
%     confident - 1xN logical, true where the guess is trustworthy.
%
%   See also: assignGroupByFilter, datasetSummary, selectDataTree

if ischar(paths) || isstring(paths)
    paths = cellstr(paths);
end

n         = numel(paths);
ids       = cell(1, n);
confident = false(1, n);

for i = 1:n
    [folder, base] = fileparts(char(paths{i}));
    parent         = lastFolderName(folder);
    token          = firstToken(base);

    if ~isempty(parent) && startsWithFold(base, parent)
        % Folder and filename agree - two independent sources, so trust it.
        ids{i}       = parent;
        confident(i) = true;
    elseif looksLikeIdentifier(token)
        ids{i}       = token;
        confident(i) = true;
    else
        ids{i}       = token;
        confident(i) = false;
    end
end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function name = lastFolderName(folder)
% The deepest folder in a path, '' when there is none.
name = '';
if isempty(folder); return; end
parts = strsplit(strrep(folder, '\', '/'), '/');
parts = parts(~cellfun(@isempty, parts));
if ~isempty(parts)
    name = parts{end};
end
end

function tok = firstToken(base)
% Leading run of characters before the first _ or -; the whole name if neither.
if isempty(base); tok = ''; return; end
parts = strsplit(base, {'_', '-'});
tok   = parts{1};
end

function tf = startsWithFold(str, prefix)
tf = ~isempty(prefix) && strncmpi(str, prefix, numel(prefix));
end

function tf = looksLikeIdentifier(tok)
% Letters and/or digits including at least one digit: 'rtmsct001', 'S01', 'P7'.
% A digitless word ('data', 'pre', 'sub') is much more likely a condition.
tf = ~isempty(tok) && ~isempty(regexp(tok, '^[A-Za-z]*\d+[A-Za-z0-9]*$', 'once'));
end
