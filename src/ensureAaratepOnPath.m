function ensureAaratepOnPath(action)
% ENSUREAARATEPONPATH  Idempotent addpath for the vendored AARATEP tree.
%   Adds third_party/aaratep and its Common subtree to the MATLAB path on
%   first call. Subsequent calls are cheap no-ops, but re-add the tree if
%   something has removed it from the path since.
%
%   Two bundled-fork subtrees are kept OFF the path so they cannot shadow
%   the user's own installs:
%     - Common/ThirdParty/FromEEGLab  forked EEGLAB functions (topoplot,
%       epoch, pop_loadbv, pop_resample_mod, ...).
%     - Common/ThirdParty/FastICA     a bundled FastICA copy. The user
%       should run the FastICA they think they have (normally EEGLAB's).
%       If NO other fastica is on the path, the bundled copy is added back
%       as a fallback so the AARATEP pipeline still runs. When the user's
%       FastICA differs from the bundled (tested) one, a one-time warning is
%       printed - the pipeline was validated against the bundled version.
%
%   Vendored from chriscline/AARATEPPipeline @ be75262 under MIT license.
%   See THIRD_PARTY_NOTICES.md.

% addpath here is all-or-nothing, so one sentinel stands for the whole tree.
% pathMemo owns the invalidation: anything that rmpaths part of the tree - a
% test using hideFromPath, a restoredefaultpath - stops the sentinel resolving
% and the addpath below runs again, rather than a remembered flag claiming the
% tree is still there while every AARATEP step fails with a bare "Undefined
% function".
%
% ENSUREAARATEPONPATH('reset') drops the memo, which is how a test forces the
% FastICA resolution below to run again. The sentinel's NAME stays in here:
% a caller naming it would silently no-op if this function ever changed which
% entry point it probes, and the tests would keep passing while inheriting a
% warm memo from each other.
SENTINEL = 'c_TMSEEG_Preprocess_AARATEPPipeline';
if nargin > 0 && strcmpi(action, 'reset')
    pathMemo(SENTINEL, []);
    return
end
pathMemo(SENTINEL, @addTree);
end

% ── helpers ───────────────────────────────────────────────────────────────────

function ok = addTree()
ok = true;   % pathMemo memoises a value; the work here is the side effect
repoRoot   = nestappRoot();

% The search order lives in aaratepRelease so the installer and the loader
% cannot disagree about where a tree may be - the same reason goldenFileStem
% and goldenDir are each one definition. This previously composed
% third_party/aaratep itself, which is the only location a developer checkout
% has and the wrong one for an installed toolbox, where writing into the
% toolbox's own folder would be erased by the next upgrade.
rel        = aaratepRelease();
aaratepDir = '';
for k = 1:numel(rel.searchDirs)
    if isfile(fullfile(rel.searchDirs{k}, [rel.sentinel '.m']))
        aaratepDir = rel.searchDirs{k};
        break
    end
end

if isempty(aaratepDir)
    error('ensureAaratepOnPath:Missing', ...
        ['The AARATEP helper functions are not installed.\n\n' ...
         'Install them from the app with  Help > Install AARATEP Helpers...\n' ...
         'or at the MATLAB prompt with:\n\n    installAaratep\n\n' ...
         'Looked in:\n  %s'], ...
        strjoin(rel.searchDirs, sprintf('\n  ')));
end

% Drop the bundled-fork subtrees from genpath so they do not shadow the
% user's EEGLAB / FastICA installs.
thirdParty = fullfile(aaratepDir, 'Common', 'ThirdParty');
shadowDirs = {fullfile(thirdParty, 'FromEEGLab'), fullfile(thirdParty, 'FastICA')};
allPaths   = strsplit(genpath(aaratepDir), pathsep);
allPaths   = allPaths(~cellfun(@isempty, allPaths));
keep       = true(1, numel(allPaths));
for i = 1:numel(shadowDirs)
    keep = keep & ~startsWith(allPaths, shadowDirs{i});
end
addpath(strjoin(allPaths(keep), pathsep));

% LAST, so it prepends ahead of everything above: nestapp's replacement for
% AARATEP's figure-export helper. AARATEP writes seven QC images through
% c_FigurePrinter, and the vendored one aborts the whole pipeline when an image
% cannot be written - after the cleaning step it belongs to has already
% succeeded - because it lets the failure escape and never reaches the close()
% that follows. It also clears globals and persistents mid-run via javaaddpath,
% and re-prepends its own export_fig at call time, which is why excluding that
% directory above would not have been enough. See src/aaratep_compat.
addpath(fullfile(repoRoot, 'src', 'aaratep_compat'));

resolveFastICA(fullfile(thirdParty, 'FastICA'));
end

function resolveFastICA(bundledFasticaDir)
% Prefer the user's fastica; fall back to the bundled copy only if none
% exists; warn once when the user's version differs from the bundled one.
bundledFile = fullfile(bundledFasticaDir, 'fastica.m');
userFile    = which('fastica');

if isempty(userFile)
    % No FastICA anywhere - add the bundled copy so AARATEP can still run.
    if isfile(bundledFile)
        addpath(bundledFasticaDir);
        warning('nestapp:aaratepFastICAFallback', ...
            ['No FastICA found on the path; using the FastICA bundled with ' ...
             'AARATEP. Install FastICA (or EEGLAB''s) for your expected version.']);
    end
    return
end

if ~isfile(bundledFile)
    return   % nothing to compare against
end

vUser    = fasticaVersion(userFile);
vBundled = fasticaVersion(bundledFile);
if fasticaDiffers(userFile, bundledFile, vUser, vBundled)
    warning('nestapp:aaratepFastICAMismatch', ...
        ['Using FastICA %s (%s), but AARATEP was tested with the bundled ' ...
         'FastICA %s. Results may differ slightly from the published pipeline.'], ...
        verLabel(vUser), userFile, verLabel(vBundled));
end
end

function tf = fasticaDiffers(userFile, bundledFile, vUser, vBundled)
% Prefer a version-string comparison; fall back to byte comparison.
if ~isempty(vUser) && ~isempty(vBundled)
    tf = ~strcmp(vUser, vBundled);
else
    tf = ~isequal(fileread(userFile), fileread(bundledFile));
end
end

function v = fasticaVersion(file)
% Extract a version token (e.g. '2.5') from a fastica.m, '' if not found.
v = '';
try
    txt = fileread(file);
catch
    return
end
tok = regexp(txt, 'version\s*[:=]?\s*v?(\d+\.\d+)', 'tokens', 'once', 'ignorecase');
if ~isempty(tok)
    v = tok{1};
end
end

function s = verLabel(v)
if isempty(v); s = '(unknown version)'; else; s = ['v' v]; end
end
