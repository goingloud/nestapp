
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_renameVarinKeys < matlab.unittest.TestCase
% TEST_RENAMEVARINKEYS  Map nestapp param keys to upstream's exact casing.
%
%   Regression for a silent-wrong-label bug: nestapp declares its Find TMS
%   Pulses keys lowercase (tmslabel, pairlabel), but tesa_findpulse stores
%   options with a case-SENSITIVE dynamic field assignment after a
%   case-INSENSITIVE accept check. So 'pairlabel' was accepted, written to a
%   stray unread field, and the real options.pairLabel stayed at its upstream
%   default 'TMSpair' - meaning paired events were mislabelled and any
%   downstream step keyed on nestapp's 'pp' found zero events.
%
%   Fixing it at the dispatch seam (rather than renaming the registry key)
%   also corrects pipelines that were saved with the lowercase key.

    methods (Test)
        function renames_a_key_and_keeps_its_value(tc)
            in  = {'tmslabel', 'MYLABEL', 'rate', 1e4};
            out = renameVarinKeys(in, {'tmslabel'}, {'tmsLabel'});
            tc.verifyEqual(out, {'tmsLabel', 'MYLABEL', 'rate', 1e4});
        end

        function renames_several_keys_at_once(tc)
            in  = {'tmslabel','TMS','pairlabel',{'pp'},'paired','yes'};
            out = renameVarinKeys(in, {'tmslabel','pairlabel'}, {'tmsLabel','pairLabel'});
            tc.verifyEqual(out{1}, 'tmsLabel');
            tc.verifyEqual(out{3}, 'pairLabel');
            tc.verifyEqual(out{4}, {'pp'}, 'the value beside a renamed key is untouched');
            tc.verifyEqual(out{5}, 'paired', 'unrelated keys are left alone');
        end

        function an_absent_key_is_a_no_op(tc)
            in  = {'rate', 1e4, 'paired', 'no'};
            out = renameVarinKeys(in, {'tmslabel'}, {'tmsLabel'});
            tc.verifyEqual(out, in);
        end

        function values_are_never_matched_as_keys(tc)
            % A value that happens to equal a from-key must not be renamed -
            % only the key positions (odd indices) are eligible.
            in  = {'label', 'tmslabel'};   % 'tmslabel' here is a VALUE
            out = renameVarinKeys(in, {'tmslabel'}, {'tmsLabel'});
            tc.verifyEqual(out, in);
        end

        function order_is_preserved(tc)
            in  = {'a',1,'pairlabel',{'x'},'b',2};
            out = renameVarinKeys(in, {'pairlabel'}, {'pairLabel'});
            tc.verifyEqual(out([1 2 5 6]), {'a',1,'b',2});
            tc.verifyEqual(out{3}, 'pairLabel');
        end
    end
end
