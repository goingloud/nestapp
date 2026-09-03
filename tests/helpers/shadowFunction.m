% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function shadowFunction(testCase, name, outputs)
% SHADOWFUNCTION  Replace a function with one returning fixed values.
%   SHADOWFUNCTION(testCase, name, outputs)
%
%   name     the function to shadow, e.g. 'uiputfile'
%   outputs  cell array of the values it should return, in order
%
%   Writes a stand-in into a scratch folder and puts that folder at the FRONT
%   of the path for the duration of the test, so the real function is shadowed
%   rather than removed. Undone by the fixture when the test ends.
%
%   THE COMPANION TO hideFromPath, and there for the same reason. hideFromPath
%   makes a function absent, which exercises the "this plugin is missing"
%   branch. This makes a function ANSWER, which is what a modal dialog needs:
%   the interesting behaviour is downstream of what the user chose, and there
%   is no other way to reach it without a person at the keyboard. The old suite
%   handled this class of test by not writing it - ledger row A1.7 (uiputfile's
%   return value being ignored, so a saved pipeline stayed marked unsaved) was
%   pinned by grepping the source for the word 'uiputfile'.
%
%   The stand-in LOADS its return values rather than having them written into
%   its text, so nothing has to serialise arbitrary values into source code -
%   which would break on the first struct or handle.
%
%   Asserts that the shadow is what `name` now resolves to. Without that check
%   a path-order surprise leaves the real dialog in place, and the test either
%   hangs waiting for a human or passes for the wrong reason.
%
%   See also: hideFromPath, scratchDir, isolateRoiPresets

folder  = scratchDir(testCase);
datPath = fullfile(folder, [name '_outputs.mat']);
save(datPath, 'outputs');

src = sprintf([ ...
    'function varargout = %s(varargin)\n' ...
    '%% Test stand-in written by shadowFunction. Returns fixed values.\n' ...
    'd = load(fullfile(fileparts(mfilename(''fullpath'')), ''%s_outputs.mat''));\n' ...
    'varargout = d.outputs(1:max(nargout,1));\n' ...
    'end\n'], name, name);
fid = fopen(fullfile(folder, [name '.m']), 'w');
fprintf(fid, '%s', src);
fclose(fid);

% PathFixture uses addpath, which PREPENDS, so the shadow wins over a toolbox
% function of the same name. It also restores the path itself, which is why it
% is used here rather than a bare addpath.
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
rehash;

testCase.assertEqual(which(name), fullfile(folder, [name '.m']), sprintf( ...
    ['could not shadow %s - it still resolves elsewhere, so this test would ' ...
     'either open the real dialog or pass for the wrong reason'], name));
end
