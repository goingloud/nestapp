
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [EEG, invalidLabels] = validateChannelCoords(EEG, policy)
% VALIDATECHANNELCOORDS  Flag/handle channels with invalid 3-D coordinates.
%   [EEG, invalidLabels] = VALIDATECHANNELCOORDS(EEG, policy) inspects every
%   channel's [X Y Z] and applies POLICY to any whose coordinates are missing,
%   non-finite (NaN/Inf), or degenerate (a zero-norm 0,0,0 "centre of head"
%   point).
%
%   Why this matters: spatial bad-channel detection and interpolation normalise
%   each electrode to the unit sphere (clean_channels / sphericalSplineInterpolate:
%   src = src ./ sqrt(sum(src.^2))). A 0,0,0 channel divides by zero and becomes
%   NaN; when it lands in a RANSAC source subset it turns the ENTIRE
%   spherical-spline reconstruction matrix to NaN, so it silently poisons every
%   subset it appears in while itself never being flagged (its own reconstruction
%   is always NaN). An empty/NaN coord is dropped from the spatial model and
%   becomes an un-checked blind spot. Either way the channel escapes the RANSAC
%   quality screen. See clean_rawdata/clean_channels.
%
%   POLICY (case-insensitive):
%     'off'    no check (default; preserves legacy behaviour)
%     'warn'   log the offending channels and continue (they are KEPT)
%     'remove' log and drop the offending channels (protects spatial RANSAC)
%     'error'  log and raise an error, halting the file (strict validation)
%
%   The offending channel labels are always recorded in
%   EEG.etc.invalidCoordChannels for the run report.

    arguments
        EEG    struct
        policy       = 'off'
    end
    policy = char(policy);
    invalidLabels = {};

    if strcmpi(policy, 'off')
        return
    end
    if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
        nestLog('COORDS', 'Coordinate check (%s): no chanlocs present; skipped.', policy);
        return
    end

    tol = 1e-6;                       % a norm below this is the origin (0,0,0)
    cl  = EEG.chanlocs;
    n   = numel(cl);
    isBad  = false(1, n);
    reason = strings(1, n);
    for c = 1:n
        xyz = {getCoord(cl(c),'X'), getCoord(cl(c),'Y'), getCoord(cl(c),'Z')};
        if any(cellfun(@isempty, xyz))
            isBad(c) = true; reason(c) = "missing"; continue
        end
        v = [xyz{:}];
        if any(~isfinite(v))
            isBad(c) = true; reason(c) = "non-finite"; continue
        end
        if sqrt(sum(v.^2)) < tol
            isBad(c) = true; reason(c) = "zero (0,0,0)"; continue
        end
    end

    invalidLabels = {cl(isBad).labels};
    EEG.etc.invalidCoordChannels = invalidLabels;

    if ~any(isBad)
        nestLog('COORDS', 'Coordinate check (%s): all %d channels have valid 3-D coordinates.', ...
            policy, n);
        return
    end

    % Per-channel detail so the offending electrodes and their (bad) values are
    % on the record before any action is taken.
    idx = find(isBad);
    for k = 1:numel(idx)
        c = idx(k);
        nestLog('COORDS', '  invalid coords: %-8s [%s] (%s)', ...
            cl(c).labels, coordStr(cl(c)), reason(c));
    end
    reasons = strjoin(unique(cellstr(reason(idx)), 'stable'), ', ');

    switch lower(policy)
        case 'warn'
            nestLog('COORDS', ['Coordinate check (warn): %d/%d channel(s) have invalid ' ...
                'coordinates (%s) and were KEPT: %s. These are RANSAC blind spots that ' ...
                'poison spatial reconstruction - fix the montage or use remove/error.'], ...
                numel(idx), n, reasons, strjoin(invalidLabels, ', '));

        case 'remove'
            nestLog('COORDS', ['Coordinate check (remove): dropping %d/%d channel(s) with ' ...
                'invalid coordinates (%s): %s.'], numel(idx), n, reasons, ...
                strjoin(invalidLabels, ', '));
            EEG = pop_select(EEG, 'nochannel', idx);
            EEG = eeg_checkset(EEG);

        case 'error'
            nestLog('COORDS', ['Coordinate check (error): %d/%d channel(s) have invalid ' ...
                'coordinates (%s): %s.'], numel(idx), n, reasons, strjoin(invalidLabels, ', '));
            error('nestapp:invalidChannelCoords', ...
                ['%d channel(s) have invalid 3-D coordinates (%s): %s. These break spatial ' ...
                 'RANSAC bad-channel detection and interpolation. Load channel locations to ' ...
                 'fix the montage, or set the coordinate check to remove/warn.'], ...
                numel(idx), reasons, strjoin(invalidLabels, ', '));

        otherwise
            error('nestapp:badCoordPolicy', ...
                'validateChannelCoords: unknown policy "%s" (off|warn|remove|error).', policy);
    end
end

% ── local helpers ─────────────────────────────────────────────────────────────

function v = getCoord(ch, f)
% Coordinate value, or [] when the field is absent or empty.
    if isfield(ch, f)
        v = ch.(f);
    else
        v = [];
    end
end

function s = coordStr(ch)
% Human-readable "X Y Z" with [] for empty fields, for the log line.
    fields = {'X','Y','Z'};
    parts  = cell(1, 3);
    for i = 1:3
        v = getCoord(ch, fields{i});
        if isempty(v)
            parts{i} = '[]';
        else
            parts{i} = num2str(v, '%.3g');
        end
    end
    s = strjoin(parts, ' ');
end
