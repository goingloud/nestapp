% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
classdef RegistryContractTest < NestappTestCase
% REGISTRYCONTRACTTEST  The promises the two registries make about themselves.
%
%   stepRegistry and plotRegistry are plain data that the app trusts: a param
%   key IS the function's option name, a validRange IS the closed set of values
%   a step will accept, and a step name IS what other files switch on. Nothing
%   enforces any of that at runtime - a drifted key produces a setting that
%   silently does nothing, which is the failure a user is least likely to
%   report, because the plot simply looks unchanged.
%
%   THIS FILE READS SOURCE, and is on SuiteHygieneTest's MayReadSource
%   allowlist for it. That is not a loophole: the two scrapes here DERIVE their
%   expected set from the registry and check the code against it. The nineteen
%   scrapes being deleted did the opposite - they hardcoded a fragment of the
%   source and checked the source still contained it, so they failed on
%   rewording and caught nothing. Deriving is the distinction, and it is the
%   reason these two survive the rewrite while the rest do not.
%
%   Ledger rows pinned here: B4, B7, B8, B10 (steps offering values the
%   upstream function rejects).

    methods (Test)

        % ── derived contracts ────────────────────────────────────────────────

        function everyPlotParamKeyIsARealOptionOfItsDrawFunction(tc)
        % The claim that lets edited values be handed to a drawer with no
        % translation table. A key that drifts from what the function reads
        % lands in a field nobody looks at.
            reg = plotRegistry();
            bad = {};
            for k = 1:numel(reg)
                if isempty(reg(k).params); continue; end
                src = tc.drawSourceGraph(reg(k).draw);
                for p = 1:numel(reg(k).params)
                    key = reg(k).params(p).key;
                    if ~contains(src, ['opts.' key])
                        bad{end+1} = sprintf('%s declares "%s" but nothing under %s reads opts.%s', ...
                                             reg(k).name, key, reg(k).draw, key); %#ok<AGROW>
                    end
                end
            end
            tc.verifyEmpty(bad, strjoin(bad, newline));
        end

        function everyMethodsClauseCaseIsARealRegistryStep(tc)
        % methodsClause switches on exact step-name literals, and its otherwise
        % branch returns ''. A registry rename that misses this file therefore
        % drops a step's methods sentence from the report silently.
            src = fileread(which('methodsClause'));
            cut = strfind(src, 'per-step helpers');   % below this the switches
            if ~isempty(cut); src = src(1:cut(1)-1); end   % are not step names

            names = {};
            for line = regexp(src, 'case[^\n]*', 'match')
                toks = regexp(line{1}, '''([^'']+)''', 'tokens');
                for j = 1:numel(toks); names{end+1} = toks{j}{1}; end %#ok<AGROW>
            end
            tc.assertNotEmpty(names, 'expected case literals in methodsClause');

            stray = setdiff(names, {stepRegistry().name});
            tc.verifyEmpty(stray, sprintf( ...
                'methodsClause switches on %d name(s) no step has: %s', ...
                numel(stray), strjoin(stray, ', ')));
        end

        function everyPlotDrawFunctionExists(tc)
        % .draw is stored as a char and resolved with str2func at draw time, so
        % the registry stays plain data - which also means a typo is invisible
        % until someone picks that plot.
            reg  = plotRegistry();
            gone = {reg(cellfun(@(f) isempty(which(f)), {reg.draw})).name};
            tc.verifyEmpty(gone, sprintf('draw function missing for: %s', ...
                                         strjoin(gone, ', ')));
        end

        function everyParamNamesItsDefaultInThePlaceholder(tc)
        % The convention paramForm relies on to show a default as an ordinary
        % control state. A param whose placeholder names nothing falls back to
        % a separate "Default" item - correct, but it means the setting reads
        % worse, so the registry should say what unset does.
            reg = plotRegistry();
            bad = {};
            for k = 1:numel(reg)
                for p = 1:numel(reg(k).params)
                    if isempty(strtrim(reg(k).params(p).placeholder))
                        bad{end+1} = sprintf('%s/%s', reg(k).name, ...
                                             reg(k).params(p).key); %#ok<AGROW>
                    end
                end
            end
            tc.verifyEmpty(bad, sprintf('no default named for: %s', ...
                                        strjoin(bad, ', ')));
        end

        % ── offered values: negative pins on specific past defects ───────────
        %
        % Deliberately NOT "this step offers exactly this list". That shape is
        % a mirror of the source: it breaks whenever anyone adds a legitimate
        % option, and catches nothing a reader would not already see. Each of
        % these instead asserts the ABSENCE of one value that was found to be
        % broken upstream, which is what a regression pin is for.

        function detrendDoesNotOfferAPolynomialUpstreamRejects(tc)
            tc.verifyFalse(tc.stepOffers('De-Trend Epoch', 'polynomial'), ...
                'ledger B4: upstream rejects it, so offering it is a crash');
        end

        function interpolateChannelsDoesNotOfferACrashingOn(tc)
            tc.verifyFalse(tc.stepOffers('Interpolate Channels', 'on'), ...
                'ledger B7');
        end

        function rejcontDoesNotOfferWindowNamesUpstreamNeverHad(tc)
        % Ledger B8: sum/fill/hann/blackman were offered and none existed
        % upstream. The step wrapping pop_rejcont is called 'Automatic
        % Continuous Rejection' - an earlier draft of this test named it
        % 'Reject Continuous Data', which no step has, so stepOffers returned
        % false for every value and all four assertions passed VACUOUSLY. That
        % is why stepOffers now asserts the step exists.
            for v = {'sum', 'fill', 'hann', 'blackman'}
                tc.verifyFalse(tc.stepOffers('Automatic Continuous Rejection', v{1}), ...
                    sprintf('ledger B8: "%s" is not a real upstream value', v{1}));
            end
        end

        function theOfferedValueProbeActuallyFindsOfferedValues(tc)
        % A positive control for stepOffers. Every negative pin above is only
        % worth something if the helper can find a value that IS there - a
        % broken probe would report the whole ledger clean.
            tc.verifyTrue(tc.stepOffers('Automatic Continuous Rejection', 'mean'));
            tc.verifyTrue(tc.stepOffers('Automatic Continuous Rejection', 'blank'));
            tc.verifyTrue(tc.stepOffers('Automatic Continuous Rejection', 'hamming'));
        end

        function noStepDeclaresAnEmptyStringAsAScalarDefault(tc)
        % Ledger B10: 'Choose Data Set' defaulted to '' for a numeric setting,
        % which is type-invalid before it ever reaches upstream. Generalised,
        % because the specific step is less interesting than the shape.
            reg = stepRegistry();
            bad = {};
            for k = 1:numel(reg)
                for p = 1:numel(reg(k).params)
                    par = reg(k).params(p);
                    if ismember(par.type, {'scalar', 'integer'}) && ...
                       ischar(par.placeholder) && strcmp(strtrim(par.placeholder), '''''')
                        bad{end+1} = sprintf('%s/%s', reg(k).name, par.key); %#ok<AGROW>
                    end
                end
            end
            tc.verifyEmpty(bad, sprintf('numeric param defaulting to empty text: %s', ...
                                        strjoin(bad, ', ')));
        end

        function theRegistryIsCachedButHandsOutIndependentCopies(tc)
        % It is called on every repaint, so it is memoised - but a caller that
        % edits what it got must not change what the next caller sees.
            a = plotRegistry();
            a(1).name = 'mutated';
            b = plotRegistry();
            tc.verifyNotEqual(b(1).name, 'mutated');
        end
    end

    methods (Access = private)

        function tf = stepOffers(tc, stepName, value)
        % Does this step's registry entry offer `value` anywhere in a
        % validRange?
        %
        % A MISSING STEP IS AN ERROR, not a false. Returning false for a step
        % that does not exist is how the B8 pin above passed while asserting
        % nothing: the name had drifted and every lookup missed. If a step is
        % ever genuinely de-registered, the pin for it should be deleted from
        % the ledger deliberately, not decay into a test that cannot fail.
            reg = stepRegistry();
            e   = reg(strcmp({reg.name}, stepName));
            tc.assertNotEmpty(e, sprintf( ...
                'no step named "%s" - the pin cannot mean anything', stepName));
            tf = false;
            for p = 1:numel(e.params)
                vr = e.params(p).validRange;
                if ~ischar(vr) || ~contains(vr, '|'); continue; end
                if ismember(value, strtrim(strsplit(vr, '|'))); tf = true; return; end
            end
        end

        function src = drawSourceGraph(~, fn)
        % The named drawer plus every draw*/shade* helper it calls, one level
        % down - as deep as a plot's opts struct is ever forwarded. A composite
        % like TEP-topo hands its whole opts to the curve drawer, so 'xlim' is
        % honoured one call deeper than the file that declares it.
            src     = fileread(which(fn));
            callees = unique(regexp(src, '\<(?:draw|shade)\w+', 'match'));
            for c = 1:numel(callees)
                w = which(callees{c});
                if ~isempty(w) && ~strcmp(callees{c}, fn)
                    src = [src newline fileread(w)]; %#ok<AGROW>
                end
            end
        end
    end
end
