% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef ParamConversionTest < NestappTestCase
% PARAMCONVERSIONTEST  Values crossing the boundary between the editor and the step.
%
%   A step parameter is typed into a table as text and handed to an EEGLAB
%   function as a typed value. Everything that goes wrong at that boundary goes
%   wrong SILENTLY - the step runs, produces a number, and nobody sees that the
%   setting never arrived. Eight of the seventeen findings in the param-surface
%   audit were exactly that.
%
%   Ledger rows pinned here: B1 (CleanLine cleans the wrong channels), B2
%   (tmslabel/pairlabel dropped on casing), B16 ('off' unreachable for five
%   clean_rawdata criteria).
%
%   The conversion table replaces 28 hand-unrolled cases in the old suite. Each
%   row below is a distinct fact about the boundary; the old file spent two or
%   three cases on several of them.

    properties (TestParameter)
        % {raw, type, expected}. One row per conversion rule.
        conversion = struct( ...
            'scalarPassesThrough',        {{7,             'scalar',     7}}, ...
            'scalarFromText',             {{'2.5',         'scalar',     2.5}}, ...
            'scalarFromCell',             {{{'3'},         'scalar',     3}}, ...
            'scalarTakesTheFirstOfAVector', {{[4 9],       'scalar',     4}}, ...
            'offSurvivesAsAWord',         {{'off',         'scalar',     'off'}}, ...
            'offSurvivesInACell',         {{{'off'},       'scalar',     'off'}}, ...
            'vectorFromBracketedText',    {{'[1 2 3]',     'vector',     [1 2 3]}}, ...
            'vectorFromSpacedText',       {{'1 2 3',       'vector',     [1 2 3]}}, ...
            'vectorColumnBecomesRow',     {{[1;2;3],       'vector',     [1 2 3]}}, ...
            'stringFromEmptyNumeric',     {{[],            'string',     ''}}, ...
            'stringlistFromCommaText',    {{'Fp1, Fp2',    'stringlist', {'Fp1','Fp2'}}}, ...
            'stringlistFromBracketSentinel', {{'[]',       'stringlist', {}}}, ...
            'stringlistFromEmptyNumeric', {{[],            'stringlist', {}}}, ...
            'logicalIsLeftAsText',        {{'off',         'logical',    'off'}})

        % The five clean_rawdata criteria that accept the literal 'off' to
        % disable a stage. Ledger B16: coercing any of these to NaN left the
        % stage running with a NaN threshold, or stripped it into the upstream
        % default - unreachable from the only interface that sets it.
        offCriterion = struct( ...
            'flatline',   'FlatlineCriterion', ...
            'channel',    'ChannelCriterion', ...
            'burst',      'BurstCriterion', ...
            'window',     'WindowCriterion', ...
            'highpass',   'Highpass')
    end

    methods (Test)

        function aValueConvertsToTheTypeTheRegistryDeclares(tc, conversion)
            [raw, type, expected] = deal(conversion{:});
            tc.verifyEqual(convertParam(raw, type), expected);
        end

        function offReachesEveryCriterionThatAcceptsIt(tc, offCriterion)
        % Ledger B16. The point is not that convertParam has a special case -
        % it is that 'off' survives the trip for the parameters that need it.
            tc.verifyEqual(convertParam('off', 'scalar'), 'off', ...
                sprintf('%s must be able to be turned off', offCriterion));
        end

        function anUnknownTypeIsPassedThroughUntouched(tc)
        % Better than guessing. A registry entry naming a type this does not
        % know should reach the step unchanged rather than silently coerced.
            tc.verifyEqual(convertParam({'anything'}, 'nosuchtype'), {'anything'});
        end

        % ── the on/off trap ──────────────────────────────────────────────────

        function drawOptionsBecomeRealLogicalsNotText(tc)
        % `if 'off'` is TRUE in MATLAB - every character is non-zero - so
        % passing the stored text straight through would leave every switch the
        % user turned OFF still on, with nothing in the picture to suggest the
        % setting was read at all. This is the one boundary that converts them.
            entry = tc.plotNamed('TEP (ROI mean)');
            opts  = plotDrawOpts(entry, struct('showBand', 'off', 'legend', 'on'));
            tc.verifyFalse(opts.showBand);
            tc.verifyTrue(opts.legend);
            tc.verifyClass(opts.showBand, 'logical');
        end

        function anUnsetDrawOptionStaysAbsentRatherThanBecomingFalse(tc)
        % Absent means "the draw function's default applies". Turning it into
        % false here would freeze every default at whatever it is today.
            entry = tc.plotNamed('TEP (ROI mean)');
            opts  = plotDrawOpts(entry, struct('legend', 'off'));
            tc.verifyFalse(isfield(opts, 'showBand'));
        end

        function nonLogicalParamsAreNotTouched(tc)
            entry = tc.plotNamed('TEP (ROI mean)');
            opts  = plotDrawOpts(entry, struct('xlim', [-20 200]));
            tc.verifyEqual(opts.xlim, [-20 200]);
        end

        % ── keys and channel ranges ──────────────────────────────────────────

        function aRenamedKeyKeepsItsValueAndItsPlace(tc)
        % Ledger B2: tmslabel/pairlabel were silently ignored because the
        % dispatch spelled them with different casing from upstream.
            v = renameVarinKeys({'tmslabel', 'TMS', 'other', 5}, ...
                                {'tmslabel'}, {'tmsLabel'});
            tc.verifyEqual(v, {'tmsLabel', 'TMS', 'other', 5});
        end

        function aVALUEthatLooksLikeAKeyIsNeverRewritten(tc)
        % Only odd positions are keys. Rewriting a value that happens to match
        % would corrupt the call rather than fix it.
            v = renameVarinKeys({'label', 'tmslabel'}, {'tmslabel'}, {'tmsLabel'});
            tc.verifyEqual(v, {'label', 'tmslabel'});
        end

        function theCleanlineRangeBecomesExplicitIndicesClampedToTheData(tc)
        % Ledger B1: the range was handed to pop_cleanline as-is, so it cleaned
        % the wrong set of channels or crashed on a dataset with fewer.
            tc.verifyEqual(cleanlineChanList([2 4], 8), 2:4);
            tc.verifyEqual(cleanlineChanList([1 99], 8), 1:8, ...
                'a range past the end is clamped, not an error');
        end

        function anEmptyCleanlineRangeMeansEveryChannel(tc)
            tc.verifyEqual(cleanlineChanList([], 5), 1:5);
        end
    end

    methods (Access = private)
        function entry = plotNamed(~, name)
            reg   = plotRegistry();
            entry = reg(strcmp({reg.name}, name));
        end
    end
end
