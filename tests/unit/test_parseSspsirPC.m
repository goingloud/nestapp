
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef test_parseSspsirPC < matlab.unittest.TestCase
% TEST_PARSESSPSIRPC  Unit + regression tests for src/parseSspsirPC.m.
%   Regression for: SSP step failing with "For colon operator with char
%   operands, first and last operands must be char." The PC param is stored
%   as a string, so {'data', 90} round-tripped through the app arrived at
%   tesa_sspsir as the CHAR "{'data', 90}", which broke its internal 1:PC.

    methods (TestClassSetup)
        function addSrcPath(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'src'));
            tc.addTeardown(@rmpath, fullfile(root, 'src'));
        end
    end

    methods (Test)
        % --- the actual bug: the char form must become a cell -------------
        function char_data_cell_becomes_cell(tc)
            pc = parseSspsirPC('{''data'', 90}');
            tc.verifyClass(pc, 'cell');
            tc.verifyEqual(pc{1}, 'data');
            tc.verifyEqual(pc{2}, 90);
        end

        function stored_string_object_form(tc)
            pc = parseSspsirPC("{'data', 90}");
            tc.verifyEqual(pc, {'data', 90});
        end

        function relaxed_data_forms(tc)
            tc.verifyEqual(parseSspsirPC('data, 70'),  {'data', 70});
            tc.verifyEqual(parseSspsirPC('data 80'),   {'data', 80});
            tc.verifyEqual(parseSspsirPC('{data,95}'), {'data', 95});
        end

        % --- pass-through of already-valid shapes -------------------------
        function real_cell_passes_through(tc)
            pc = parseSspsirPC({'data', 90});
            tc.verifyEqual(pc, {'data', 90});
        end

        function numeric_count_passes_through(tc)
            tc.verifyEqual(parseSspsirPC(5), 5);
        end

        % --- string variants that map to a fixed count / empty ------------
        function bare_number_string_is_fixed_count(tc)
            tc.verifyEqual(parseSspsirPC('3'), 3);
        end

        function empty_forms_become_empty(tc)
            tc.verifyEqual(parseSspsirPC(''),   []);
            tc.verifyEqual(parseSspsirPC('[]'), []);
        end

        % --- guard rails --------------------------------------------------
        function garbage_throws_helpful_error(tc)
            tc.verifyError(@() parseSspsirPC('not a pc'), 'nestapp:sspsirPC');
        end

        function data_without_number_throws(tc)
            tc.verifyError(@() parseSspsirPC('data'), 'nestapp:sspsirPC');
        end
    end
end
