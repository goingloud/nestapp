
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_offeredParamValues < matlab.unittest.TestCase
% TEST_OFFEREDPARAMVALUES  Every value the GUI offers must actually work.
%
%   Found by the dead-parameter audit: "Interpolate Missing Data (TESA)"
%   advertised its Method as linear|cubic|pchip, but tesa_interpdata rejects
%   anything that is not linear or cubic (tesa_interpdata.m:61). Choosing the
%   third option from a list the app itself offered always failed the run.
%
%   And a parameter that cannot affect anything must be declared as such:
%   interpWin is read only inside the cubic branch, so under linear it is a
%   control that does nothing. The registry has paramEnableWhen for exactly
%   this - a knob with no effect and no explanation is the GUI-level version
%   of a silent no-op.

    properties
        registry
    end

    methods (TestClassSetup)
        function setup(tc)
            if ~exist('eeglab', 'file')
                tc.assumeFail('EEGLAB not on path');
            end
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
            tc.registry = stepRegistry();
        end
    end

    methods (Test)
        function interpolation_offers_only_methods_tesa_accepts(tc)
            p = paramFor(tc, 'Interpolate Missing Data (TESA)', 'interpolation');
            offered = strsplit(p.validRange, '|');
            tc.verifyEqual(sort(offered), {'cubic', 'linear'}, ...
                ['tesa_interpdata accepts only linear or cubic; anything else ' ...
                 'errors the run. Do not offer it in the picker.']);
        end

        function interpWin_is_greyed_out_when_it_cannot_apply(tc)
            % Not "is it documented" - is the rule actually declared, so the
            % GUI acts on it.
            step = stepFor(tc, 'Interpolate Missing Data (TESA)');
            rules = step.paramEnableWhen;
            tc.assertNotEmpty(rules, ...
                'interpWin does nothing under linear; that must be declared');
            k = find(strcmp({rules.param}, 'interpWin'), 1);
            tc.assertNotEmpty(k, 'No enable rule declared for interpWin');
            tc.verifyEqual(rules(k).controller, 'interpolation');
            tc.verifyEqual(rules(k).values, {'cubic'});
        end

        function disabledParamKeys_actually_greys_interpWin_under_linear(tc)
            % End of the chain: the helper the GUI calls must return interpWin
            % as disabled for a linear step, and not for a cubic one.
            regEntry = stepFor(tc, 'Interpolate Missing Data (TESA)');

            p = struct('interpolation', 'linear', 'interpWin', [20 20]);
            [keys, reasons] = disabledParamKeys(regEntry, p);
            tc.verifyTrue(ismember('interpWin', keys), ...
                'Under linear, interpWin must be greyed out');
            tc.verifyTrue(isfield(reasons, 'interpWin') && ...
                contains(reasons.interpWin, 'cubic'), ...
                'The user must be told which setting makes it apply');

            p.interpolation = 'cubic';
            tc.verifyFalse(ismember('interpWin', disabledParamKeys(regEntry, p)), ...
                'Under cubic, interpWin is live and must be editable');
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function s = stepFor(tc, name)
k = find(strcmp({tc.registry.name}, name), 1);
tc.assertNotEmpty(k, sprintf('%s missing from registry', name));
s = tc.registry(k);
end

function p = paramFor(tc, stepName, key)
s = stepFor(tc, stepName);
k = find(strcmp({s.params.key}, key), 1);
tc.assertNotEmpty(k, sprintf('%s has no param %s', stepName, key));
p = s.params(k);
end
