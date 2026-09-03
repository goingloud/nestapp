% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function root = nestappRoot()
% NESTAPPROOT  The nestapp installation root, whatever the layout.
%   root = NESTAPPROOT()
%
%   The folder that holds run_nestapp.m and src/. In a git checkout that is the
%   repository root; in a toolbox installed from a .mltbx it is the add-on's
%   folder. Both layouts keep run_nestapp.m beside src/, so both resolve.
%
%   FOUND BY WALKING UP TO A LANDMARK, not by counting directory levels. Seven
%   files used to do their own version of
%
%       fileparts(fileparts(mfilename('fullpath')))    % src/ -> repo root
%
%   which is correct only while the caller sits exactly one level below the
%   root. That made the src/ tree effectively unmovable: reorganising 146 files
%   into subfolders would have silently changed what each of those seven
%   resolved to - the AARATEP search path, the templates folder, the git commit
%   in a support bundle, the ROI picker's head image - and none of it would have
%   failed loudly. Asking for a landmark instead means a file can live at any
%   depth.
%
%   run_nestapp.m is the landmark because it is the entry point: it exists in
%   every layout nestapp is used in, it is at the root by definition, and it is
%   shipped inside the .mltbx (tools/package_toolbox.m includes it explicitly).
%   A .git folder would work in a checkout and not in an install; LICENSE is
%   present in both but is a name many trees carry, so a false positive is
%   possible on an unlucky parent.
%
%   Memoised: the answer cannot change within a session, and this is called on
%   paths that run per file in a batch.
%
%   See also: run_nestapp, addNestappPath (the test suite's equivalent)

persistent cached
if ~isempty(cached)
    root = cached;
    return
end

LANDMARK = 'run_nestapp.m';
d = fileparts(mfilename('fullpath'));

while true
    if isfile(fullfile(d, LANDMARK))
        cached = d;
        root   = d;
        return
    end
    parent = fileparts(d);
    if strcmp(parent, d)   % reached the filesystem root
        break
    end
    d = parent;
end

error('nestapp:rootNotFound', ...
    ['Could not locate the nestapp root: no %s found above %s. nestapp ' ...
     'expects run_nestapp.m to sit beside src/, which is true of both a git ' ...
     'checkout and a toolbox installed from a .mltbx.'], ...
    LANDMARK, fileparts(mfilename('fullpath')));
end
