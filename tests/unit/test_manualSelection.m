
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_manualSelection < matlab.unittest.TestCase
% TEST_MANUALSELECTION  A manual step must hand back what the user chose.
%
%   The behaviour under test: a selection made in the GUI reaches the
%   pipeline. It did not. Remove Bad Trials used pop_rejmenu, which has no
%   output and reports through the BASE workspace - a different variable from
%   the `global EEG` a pipeline runs with - so every manual mark was silently
%   discarded and only the automatic rejections applied.
%
%   These exercise harvestMarkedTrials with the region arrays eegplot really
%   produces, rather than checking that the dispatch mentions the right
%   function names. The conversion is the part that was wrong and the part
%   that can be wrong again; it can be tested without opening a window.

    methods (TestClassSetup)
        function setup(tc)
            if ~exist('eegplot2trial', 'file')
                tc.assumeFail('EEGLAB not on path - eegplot2trial unavailable');
            end
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(genpath(fullfile(root, 'src')));
        end
    end

    methods (Test)
        function marks_become_the_trials_the_user_marked(tc)
            % Mark trials 2 and 5 of 8, in eegplot's own region format, and
            % expect exactly those back.
            pnts = 100; trials = 8;
            tmprej = regionsFor([2 5], pnts, trials);
            tc.verifyEqual(harvestMarkedTrials(tmprej, pnts, trials), [2 5]);
        end

        function marking_nothing_rejects_nothing(tc)
            % Confirming without marking is a real answer - "reject nothing" -
            % not a missing one. It must not fall back to some other set.
            tc.verifyEmpty(harvestMarkedTrials([], 100, 8));
        end

        function every_trial_can_be_marked(tc)
            pnts = 100; trials = 4;
            tmprej = regionsFor(1:4, pnts, trials);
            tc.verifyEqual(harvestMarkedTrials(tmprej, pnts, trials), 1:4);
        end

        function first_and_last_trials_are_not_off_by_one(tc)
            % Boundary trials are where an index conversion goes wrong.
            pnts = 100; trials = 6;
            tc.verifyEqual(harvestMarkedTrials(regionsFor(1, pnts, trials), pnts, trials), 1);
            tc.verifyEqual(harvestMarkedTrials(regionsFor(6, pnts, trials), pnts, trials), 6);
        end

        function result_is_a_row_of_indices_ready_for_pop_rejepoch(tc)
            % pop_rejepoch takes a row vector of trial indices; handing it a
            % logical mask or a column would reject the wrong trials.
            out = harvestMarkedTrials(regionsFor([3 4], 100, 8), 100, 8);
            tc.verifySize(out, [1 2]);
            tc.verifyTrue(isnumeric(out) && ~islogical(out), ...
                'Must be indices, not a logical mask');
            tc.verifyEqual(out, [3 4]);
        end

        function harvest_survives_unsorted_and_duplicate_regions(tc)
            % A user can mark a trial twice, or out of order, by dragging over
            % it again. The result must still be each trial once, ascending.
            pnts = 100; trials = 8;
            tmprej = [regionsFor(5, pnts, trials); ...
                      regionsFor(2, pnts, trials); ...
                      regionsFor(5, pnts, trials)];
            tc.verifyEqual(harvestMarkedTrials(tmprej, pnts, trials), [2 5]);
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────
function tmprej = regionsFor(trialIdx, pnts, trials)
% Build the region array eegplot hands to its 'command' callback for a given
% set of marked trials, using EEGLAB's own trial->region converter so these
% tests exercise the real format rather than a guess at it.
rej  = false(1, trials);
rej(trialIdx) = true;
tmprej = trial2eegplot(rej, zeros(1, trials), pnts, [1 0 0]);
end
