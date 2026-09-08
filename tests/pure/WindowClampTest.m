% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef WindowClampTest < NestappTestCase
% WINDOWCLAMPTEST  The window must grow back to its minimum without moving.
%
%   The bug: figure Position measures `bottom` from the bottom of the screen,
%   so restoring width and height alone anchors the bottom-LEFT corner and
%   grows the window upward. Dragging the bottom edge up raises `bottom`;
%   restoring the height from there lifts the whole window, and over a stream
%   of resize events it ratchets off the top of the monitor at a constant size.
%   The window crept upward until it left the screen.
%
%   ONE TABLE OF INPUTS, NOT OF EXPECTED POSITIONS. The old version was eight
%   hand-unrolled cases - the single clearest instance of unrolling in the old
%   suite - and the obvious rewrite is a table of {pos, minSize, expectedPos}.
%   That is worse than it looks: an expected Position column restates
%   clampWindowPosition's own formula inside the test, so a slip transcribing
%   it becomes a wrong expectation, and the test then measures my arithmetic
%   rather than the code's. Ledger rows A1.x and the four wrong-number bugs
%   fixed this session were all of that shape.
%
%   So the table supplies only INPUTS, and the rules are asserted as
%   invariants, each stated in the language of the bug rather than of the
%   implementation:
%
%     1. the top edge never moves        <- the regression itself
%     2. left is never touched
%     3. the size is exactly max(pos(3:4), minSize)
%     4. `changed` is true iff the size had to grow
%
%   Together those four pin newPos exactly, so nothing is given up by not
%   writing it out: 1-3 leave one Position possible. And they are not a
%   paraphrase of the code - it computes bottom = top - newHeight, while (1)
%   says the top does not move. Equivalent, but the assertion says why.
%
%   VERIFIED BY REPLAY, NOT BY A SELF-TEST. An earlier version of this file
%   carried a case that reproduced the old buggy clamp inline and checked that
%   the invariants rejected it. It was dropped: it tested its OWN copy of the
%   rules, so deleting rule 1 from the real test above would have left it
%   green - it proved the approach sound without proving this file uses it.
%   The honest version is the plan's 5.2 replay, run against the real source:
%   reintroducing the bug in clampWindowPosition fails exactly the four
%   height-growing rows plus the stream, and nothing else.
%
%   Ledger rows: A3.1-A3.8 (this table), A3.6 (fixed point), A3.7 (the stream).
%   A3.11 was dropped as a guard against a refactor rather than a defect.

    properties (TestParameter)
        % Every distinct situation the eight old cases covered, as inputs only.
        % mustGrow is the one thing not derivable from the row at a glance, and
        % it is what makes rule 4 checkable.
        clampCase = struct( ...
            'alreadyBigEnough',  struct('pos', [100 200 900 600], 'min', [650 420], 'mustGrow', false), ...
            'exactlyAtMinimum',  struct('pos', [ 10  20 650 420], 'min', [650 420], 'mustGrow', false), ...
            'heightTooSmall',    struct('pos', [100 500 900 300], 'min', [650 420], 'mustGrow', true), ...
            'widthTooSmall',     struct('pos', [100 200 400 600], 'min', [650 420], 'mustGrow', true), ...
            'bothTooSmall',      struct('pos', [100 500 300 200], 'min', [650 420], 'mustGrow', true), ...
            'farBelowOnBoth',    struct('pos', [  0   0  10  10], 'min', [200 100], 'mustGrow', true), ...
            'aDifferentMinimum', struct('pos', [ 50  60 300 300], 'min', [800 200], 'mustGrow', true), ...
            'zeroSized',         struct('pos', [  5   5   0   0], 'min', [650 420], 'mustGrow', true))
    end

    methods (Test)

        function theClampObeysAllFourRules(tc, clampCase)
            c = clampCase;
            [newPos, changed] = clampWindowPosition(c.pos, c.min);

            tc.verifyEqual(topEdgeOf(newPos), topEdgeOf(c.pos), ...
                'rule 1: the top edge must not move - this IS the regression');
            tc.verifyEqual(newPos(1), c.pos(1), ...
                'rule 2: left is never touched');
            tc.verifyEqual(newPos(3:4), max(c.pos(3:4), c.min), ...
                'rule 3: the size is the caller''s minimum, not one baked in');
            tc.verifyEqual(changed, c.mustGrow, ...
                ['rule 4: `changed` is what lets the caller write Position only ' ...
                 'when it must, and a needless write re-fires the resize callback']);
        end

        function anUnchangedWindowIsHandedBackByteForByte(tc)
        % Stronger than rule 4 for the rows that need no growth: not merely
        % "changed is false" but the same Position back, so a caller that
        % writes unconditionally still writes nothing new.
        %
        % NOT parameterised, because only two of the eight rows are big enough
        % already. The first version WAS, and opened with "if mustGrow; return;
        % end" - six cases that passed by doing nothing. That is the vacuous
        % test this whole rewrite exists to get rid of, so the rule here is to
        % select the rows that have something to say rather than to run every
        % row and bail out of most of them.
            rows = tc.rowsWhere(false);
            tc.assertNotEmpty(rows, 'no already-big-enough row left to check');
            for k = 1:numel(rows)
                c = rows{k};
                tc.verifyEqual(clampWindowPosition(c.pos, c.min), c.pos);
            end
        end

        function theClampSettlesAfterOneApplication(tc)
        % Ledger A3.6. "Creeping" was precisely this failing: each resize event
        % moved the window a little further. Applying the clamp to its own
        % output must change nothing.
        %
        % ONE CASE OVER EVERY ROW, because idempotence is one rule, not eight
        % facts - the same call this suite makes in SuiteHygieneTest, where one
        % convention over many files is also one case. Three applications, not
        % the old test's fifty: the second proves the first settled and the
        % third proves the second was not luck. Fifty is theatre.
            names = fieldnames(tc.clampCaseTable());
            for k = 1:numel(names)
                c     = tc.clampCaseTable().(names{k});
                first = clampWindowPosition(c.pos, c.min);
                p     = first;
                for again = 1:3
                    [p, changed] = clampWindowPosition(p, c.min);
                    tc.assertFalse(changed, sprintf( ...
                        '%s: still growing on application %d', names{k}, again + 1));
                end
                tc.verifyEqual(p, first, sprintf('%s: drifted', names{k}));
            end
        end

        function aStreamOfShrinksNeverLiftsTheWindow(tc)
        % Ledger A3.7 - the original bug's exact shape, and the only case here
        % that is a sequence rather than a rule, so it stays its own test:
        % drag the bottom edge up repeatedly and let the clamp restore the
        % height each time. Under the old arithmetic the top rose 40px an event
        % and the window walked off the monitor.
            pos  = [100 600 900 600];
            top0 = topEdgeOf(pos);
            for k = 1:25
                pos = [pos(1), pos(2) + 40, pos(3), pos(4) - 40];   % drag bottom up
                pos = clampWindowPosition(pos, [650 420]);
                tc.assertLessThanOrEqual(topEdgeOf(pos), top0, sprintf( ...
                    'the window rose above its starting top edge on event %d', k));
            end
            tc.verifyEqual(topEdgeOf(pos), top0, ...
                'and after 25 events it is exactly where it started');
        end

    end

    methods (Access = private)
        function rows = rowsWhere(tc, mustGrow)
        % The table rows whose mustGrow flag matches, as a cell of structs.
            t     = tc.clampCaseTable();
            names = fieldnames(t);
            keep  = cellfun(@(n) t.(n).mustGrow == mustGrow, names);
            rows  = cellfun(@(n) t.(n), names(keep), 'UniformOutput', false);
        end
    end

    methods (Static, Access = private)
        function s = clampCaseTable()
        % The parameter table, reachable from a non-parameterised test. Reading
        % the property off the class rather than keeping a second copy: a
        % divergent copy is how the old suite ended up with four fake
        % groupCurves results under three signatures.
            s = WindowClampTest.clampCase;
        end
    end
end

% ── local helpers ─────────────────────────────────────────────────────────────

function t = topEdgeOf(pos)
% Position is [left bottom width height], so the top edge is bottom + height.
% Named because every rule in this file is about it.
t = pos(2) + pos(4);
end
