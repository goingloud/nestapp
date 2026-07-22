
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_cleanlineChanList < matlab.unittest.TestCase
% TEST_CLEANLINECHANLIST  The CleanLine channel range expands to real indices.
%
%   Regression for a dispatch bug: the CleanLine step declares its channels as
%   a [first last] range (default [1 64]) and the old dispatch expanded it two
%   wrong ways -
%     * when the top of the range was above nbchan it used 1:nbchan-1, which
%       silently dropped the LAST channel from cleaning;
%     * otherwise it evaluated 1:[1 64] - a colon with a vector bound - which
%       cleaned only channel 1 on old MATLAB and HARD-ERRORS on R2026a.
%   So on a 64-channel montage the shipped default aborted the step, and on a
%   32-channel montage it cleaned all but the last channel.
%
%   The expansion now lives in cleanlineChanList so the logic is testable
%   without running pop_cleanline.

    methods (Test)
        function shipped_default_on_64ch_cleans_all_64(tc)
            % The exact configuration that used to hard-error.
            tc.verifyEqual(cleanlineChanList([1 64], 64), 1:64);
        end

        function the_last_channel_is_never_dropped(tc)
            % The -1 bug: on any montage the top channel must be included.
            for nb = [19 32 63 64 128]
                out = cleanlineChanList([1 nb+100], nb);   % range over the top
                tc.verifyEqual(out(end), nb, sprintf( ...
                    'nbchan=%d: last channel must be cleaned', nb));
            end
        end

        function a_range_over_the_top_is_clamped_not_errored(tc)
            % [1 64] on a 32-channel file means "all of them", not a crash.
            tc.verifyEqual(cleanlineChanList([1 64], 32), 1:32);
        end

        function a_genuine_subrange_is_honoured(tc)
            tc.verifyEqual(cleanlineChanList([5 10], 64), 5:10);
        end

        function empty_means_all_channels(tc)
            % Upstream reads [] as all channels; the sibling param documents
            % '[] = all', so an empty range must resolve the same way.
            tc.verifyEqual(cleanlineChanList([], 40), 1:40);
        end

        function low_edge_is_floored_to_one(tc)
            tc.verifyEqual(cleanlineChanList([0 10], 64), 1:10);
        end

        function a_single_scalar_is_treated_as_that_one_channel(tc)
            % Defensive: a scalar shouldn't collapse to 1:scalar the way the
            % old code did - it names one channel.
            tc.verifyEqual(cleanlineChanList(7, 64), 7);
        end
    end
end
