% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef FigureScaleTest < NestappTestCase
% FIGURESCALETEST  Colour limits and figure dimensions - the arithmetic behind a figure.
%
%   Both subjects here decide their numbers BEFORE anything is drawn, yet used
%   to be reachable only through a full render. The old suite spent roughly 100
%   topoplot calls and nine composed figures to read those numbers back, which
%   also stranded the assertions in a suite that needed EEGLAB and a display.
%   Nothing in this file draws.
%
%   Ledger rows: C4 (a shared colour bar over maps that no longer share a
%   scale), and the T1 topoColourScale set.

    properties (TestParameter)
        % The three ways a caller names a width, and what each must resolve to.
        width = struct( ...
            'single',      struct('in', 'single', 'mm', 89), ...
            'double',      struct('in', 'double', 'mm', 183), ...
            'numeric',     struct('in', 120,      'mm', 120), ...
            'numericText', struct('in', '400',    'mm', 400))

        badWidth = struct('zero', 0, 'negative', -10, 'nonFinite', Inf, ...
                          'nonsense', 'wide', 'empty2', [1 2])
    end

    methods (Test)

        % ── topoColourScale ──────────────────────────────────────────────────

        function sharedIsOneSymmetricLimitAcrossEveryMap(tc)
            vals = {[1 -2 3]', [10 -4 0]'};
            [perCol, shared] = topoColourScale(vals);
            tc.verifyEqual(shared, [-10 10]);
            tc.verifyEqual(perCol, {[-10 10], [-10 10]}, ...
                'every column reports the scale it actually uses');
        end

        function theLimitsAreAlwaysSymmetricAboutZero(tc)
        % Not a preference: drawScalpTopo pairs them with a diverging colormap
        % whose neutral midpoint is white, so an off-centre zero puts white
        % somewhere other than no-deflection and the polarity misreads.
            [~, shared] = topoColourScale({[0.5 -9 2]'});
            tc.verifyEqual(shared(1), -shared(2));
        end

        function perColumnGivesEachColumnItsOwnLimit(tc)
        % Two groups (rows) x two windows (columns). The groups within a window
        % must still share, because that is the comparison the rows exist for.
            vals = {[1 -1]', [10 -10]'; [2 -2]', [8 -8]'};
            [perCol, shared] = topoColourScale(vals, true);
            tc.verifyEqual(perCol{1}, [-2 2]);
            tc.verifyEqual(perCol{2}, [-10 10]);
            tc.verifyEmpty(shared, ...
                'columns no longer share a scale, so there is none to report');
        end

        function anEmptySharedLimitIsTheContractThatStopsAWrongColourBar(tc)
        % Ledger C4. A caller hanging one bar over per-column maps would state a
        % voltage that means something else in the map beside it - a wrong
        % number on a published figure, and one nothing on screen contradicts.
            [~, shared] = topoColourScale({[1 2]', [3 4]'}, true);
            tc.verifyEmpty(shared);
            [~, stillShared] = topoColourScale({[1 2]', [3 4]'}, false);
            tc.verifyNotEmpty(stillShared);
        end

        function oneMapPerGroupIsJustAOneRowGrid(tc)
        % drawGroupTopo's "per map" and drawTEPTopo's "per window" were the
        % same rule written twice; per-map over a single row IS per-column.
            vals = {[1 -1]', [5 -5]'};
            perCol = topoColourScale(vals, true);
            tc.verifyEqual(perCol, {[-1 1], [-5 5]});
        end

        function aPinnedMagnitudeOverridesTheMode(tc)
        % What makes two figures from different runs comparable: a derived scale
        % moves with the data, so the same colour means a different voltage.
            [perCol, shared] = topoColourScale({[1 2]', [3 4]'}, true, 7);
            tc.verifyEqual(shared, [-7 7]);
            tc.verifyEqual(perCol{1}, [-7 7]);
            tc.verifyEqual(perCol{2}, [-7 7]);
        end

        function aNegativePinIsReadAsAMagnitude(tc)
        % -6 and 6 name the same symmetric scale; the alternative is an
        % inverted CLim that renders every map in reverse polarity.
            [~, shared] = topoColourScale({[1 2]'}, false, -6);
            tc.verifyEqual(shared, [-6 6]);
        end

        function aZeroPinMeansDeriveOneRatherThanClipEverything(tc)
        % Ledger C1's sibling. Unticking the form's Default checkbox without
        % typing a number leaves 0 behind; honouring it would pin every map to
        % +/-1 uV and hide all of the data.
            [~, pinned]  = topoColourScale({[3 -3]'}, false, 0);
            [~, derived] = topoColourScale({[3 -3]'}, false);
            tc.verifyEqual(pinned, derived);
            tc.verifyNotEqual(pinned, [-1 1]);
        end

        function aZeroPinDoesNotSuppressPerColumn(tc)
        % The override only wins when it states something.
            [~, shared] = topoColourScale({[1 1]', [9 9]'}, true, 0);
            tc.verifyEmpty(shared);
        end

        function anExplicitPairWinsOutright(tc)
            [perCol, shared] = topoColourScale({[1 2]', [3 4]'}, true, [-9 9]);
            tc.verifyEqual(shared, [-9 9]);
            tc.verifyEqual(perCol{2}, [-9 9]);
        end

        function anAllZeroMapStillGetsAUsableRange(tc)
        % A zero-width CLim gives the colormap no extent at all.
            [~, shared] = topoColourScale({[0 0 0]'});
            tc.verifyEqual(shared, [-1 1]);
        end

        function nonFiniteValuesDoNotProduceANonFiniteScale(tc)
            [~, shared] = topoColourScale({[Inf NaN]'});
            tc.verifyTrue(all(isfinite(shared)));
        end

        % ── publicationFigureSize ────────────────────────────────────────────

        function theWidthResolvesFromEveryFormTheDialogCanStore(tc, width)
        % 'single'/'double' force the setting to be stored as TEXT, so a
        % millimetre value typed into the same box arrives as '400'. Rejecting
        % that made the millimetre option unreachable from the only interface
        % that sets it.
            sz = publicationFigureSize(struct('width', width.in));
            tc.verifyEqual(sz.widthMm, width.mm);
        end

        function theHeightDefaultsToAratioOfTheWidth(tc)
            sz = publicationFigureSize(struct('width', 'double'));
            tc.verifyEqual(sz.heightMm, 183 * 0.62, 'AbsTol', 1e-9);
        end

        function anExplicitHeightIsKept(tc)
            sz = publicationFigureSize(struct('width', 100, 'height', 40));
            tc.verifyEqual(sz.heightMm, 40);
        end

        function theTypeShrinksWithThePageButNotBelowLegibility(tc)
        % 8 pt reads well across 183 mm and overlaps six column titles at 89.
        % Journals floor at 5 to 7 pt, hence a clamp rather than a proportion.
            wide   = publicationFigureSize(struct('width', 'double')).fontSize;
            narrow = publicationFigureSize(struct('width', 'single')).fontSize;
            tiny   = publicationFigureSize(struct('width', 20)).fontSize;
            tc.verifyLessThan(narrow, wide);
            tc.verifyGreaterThanOrEqual(tiny, 5, 'the floor is what keeps it legible');
            tc.verifyLessThanOrEqual(wide, 9);
        end

        function anExplicitFontSizeIsKept(tc)
            sz = publicationFigureSize(struct('width', 'single', 'fontSize', 12));
            tc.verifyEqual(sz.fontSize, 12);
        end

        function anImpossibleWidthIsRefusedWithTheValueInTheMessage(tc, badWidth)
            tc.verifyError(@() publicationFigureSize(struct('width', badWidth)), ...
                           'nestapp:badFigureWidth');
        end
    end
end
