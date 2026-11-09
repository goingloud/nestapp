% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function c = nestColours(name)
% NESTCOLOURS  The interface colours, taken from the lab logo, in one place.
%   c = NESTCOLOURS(name) returns an RGB triple:
%     'navy'      headings, step names, section titles (the logo's ink)
%     'mint'      thin accents: the bar under a step name (the logo's green)
%     'mintTint'  the selected pipeline step's highlight
%     'mintLine'  section dividers
%     'page'      the Cleaning tab background, so white panels stand out
%     'run'       the Run button (a plain green; mint is too bright that large)
%     'problem'   a step or setting with a problem
%     'muted', 'disabled', 'added', 'moved'   secondary text, a setting that
%                 does not apply, and Edit pipeline's added / moved steps
%
%   See also: settingsForm, editPipelineDialog

switch name
    case 'navy',     c = [0.12 0.16 0.23];
    case 'mint',     c = [0.12 0.90 0.60];
    case 'mintTint', c = [0.86 0.98 0.93];
    case 'mintLine', c = [0.70 0.93 0.83];
    case 'page',     c = [0.965 0.97 0.975];
    case 'run',      c = [0.20 0.55 0.20];
    case 'problem',  c = [0.80 0.15 0.15];
    case 'muted',    c = [0.45 0.45 0.45];   % secondary text (provider line, notes)
    case 'disabled', c = [0.55 0.55 0.55];   % a setting that does not apply
    case 'added',    c = [0.00 0.50 0.15];   % Edit pipeline: a step added
    case 'moved',    c = [0.10 0.35 0.75];   % Edit pipeline: a step moved
    otherwise
        error('nestColours:unknown', 'No interface colour "%s".', name);
end
end
