
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function [isAvailable, reason] = ensureCurveFittingFit()
% ENSURECURVEFITTINGFIT  Put the Curve Fitting Toolbox on the path so fit() works.
%   [isAvailable, reason] = ENSURECURVEFITTINGFIT() idempotently adds the whole
%   Curve Fitting Toolbox tree to the MATLAB path, then reports whether fit() is
%   usable. isAvailable is false with a human-readable reason when it is not.
%
%   The AARATEP decay-artifact step calls fit(x, y, ...) on plain doubles. If
%   the toolbox is not on the path, fit() breaks with a confusing message -
%   either "Undefined function 'fit' for input arguments of type 'double'"
%   (fit.m off the path, so dispatch falls to the stats @gmdistribution/fit
%   method) or "Undefined function 'lscftsh' ..." (fit.m present but the shared
%   optimisation library its solver needs is off the path). Note that lscftsh
%   lives in toolbox/shared/optimlib - OUTSIDE the toolbox folder - so simply
%   adding toolbox/curvefit is not enough; the shared lib must be added too.
%
%   Adding the folders (rather than calling restoredefaultpath) leaves the
%   user's EEGLAB / nestapp paths untouched. A missing install or license
%   cannot be fixed from here and is reported instead.

    curvefitTree = fullfile(matlabroot, 'toolbox', 'curvefit');
    optimlibDir  = fullfile(matlabroot, 'toolbox', 'shared', 'optimlib');

    if isfolder(curvefitTree)
        addpath(genpath(curvefitTree));   % whole toolbox tree (fit.m + siblings)
    end
    if isfolder(optimlibDir)
        addpath(optimlibDir);             % shared solver lib (lscftsh)
    end

    % fit() is usable when it resolves to the toolbox (not @gmdistribution) and
    % the toolbox is licensed. Since we just forced both folders onto the path,
    % a still-unresolved fit() means it is genuinely not installed/licensed.
    w         = which('fit');
    isLicensed = license('test', 'Curve_Fitting_Toolbox') == 1;
    isAvailable = ~isempty(w) && contains(lower(w), 'curvefit') && isLicensed;

    if isAvailable
        reason = '';
    elseif ~isfolder(curvefitTree)
        reason = 'Curve Fitting Toolbox does not appear to be installed.';
    elseif ~isLicensed
        reason = 'Curve Fitting Toolbox is installed but not licensed for this user.';
    else
        reason = ['Curve Fitting Toolbox is installed but fit() still will not resolve - ' ...
                  'your MATLAB path may be corrupted. Repair it from the Command Window ' ...
                  'with:  restoredefaultpath; rehash toolboxcache; savepath  then re-add ' ...
                  'EEGLAB/nestapp and restart.'];
    end
end
