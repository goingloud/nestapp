function driveModalDialog(testCase, findFcn, actFcn, timeoutSec)
% DRIVEMODALDIALOG  Act on a modal dialog and guarantee it closes.
%
%   DRIVEMODALDIALOG(testCase, findFcn, actFcn) arms a timer that waits for the
%   dialog to be ready, runs actFcn() once, and then releases it whether actFcn
%   succeeded, did nothing, or threw.
%
%   DRIVEMODALDIALOG(..., timeoutSec) gives up after timeoutSec (default 10)
%   and force-closes anything modal that is standing.
%
%   Why this exists: a modal dialog blocks on uiwait, so the only thing that can
%   close it is a callback. If that callback errors, or fires at the wrong
%   moment, uiwait never returns and MATLAB is wedged behind a window the user
%   has to close by hand. That happened. A test suite must not be able to do
%   that to the machine it runs on. Three things make it safe:
%
%   1. WAITING FOR READINESS, not for existence. The figure handle exists as
%      soon as the dialog starts building, but uiwait is only called at the end
%      - roughly 400 ms later for a 69-button montage. A uiresume issued in that
%      window is silently a no-op, and the dialog then blocks forever. So this
%      waits for the 'nestappModalReady' appdata flag the dialog sets
%      immediately before uiwait. A fixed sleep only ever hid this race.
%
%   2. RETRYING THE RELEASE. Even with the flag, release is re-issued on every
%      tick until the window is actually gone. State set by actFcn (an accept
%      flag, say) persists, so a repeated uiresume yields the same answer - it
%      is idempotent, and it cannot leave the dialog up because it stopped
%      early.
%
%   3. EVERYTHING INSIDE TRY/CATCH, findFcn included. A helper that raises while
%      looking for the window would hang the session as surely as one that
%      raises while driving it. Errors are captured into
%      testCase.TestData.dialogError for the test to surface.
%
%   See also: assumeDesktop, launchApp

    if nargin < 4 || isempty(timeoutSec); timeoutSec = 10; end

    testCase.TestData.dialogError = [];
    started = tic;
    acted   = false;

    t = timer('StartDelay', 0.05, 'Period', 0.05, ...
              'ExecutionMode', 'fixedSpacing', 'BusyMode', 'drop', ...
              'TimerFcn', @(src, ~) step(src));
    testCase.addTeardown(@() sweep(t));
    start(t);

    function step(src)
        try
            if toc(started) > timeoutSec
                stop(src);
                releaseModals();
                return
            end

            fig = findFcn();
            if isempty(fig) || ~isvalid(fig(1))
                return                      % not up yet
            end
            fig = fig(1);

            if ~acted
                if ~isequal(getappdata(fig, 'nestappModalReady'), true)
                    return                  % built, but not blocking yet
                end
                acted = true;
                try
                    actFcn();
                catch ME
                    testCase.TestData.dialogError = ME;
                end
            end

            % Keep releasing until it is really gone; do not stop early.
            if isvalid(fig)
                try, uiresume(fig); catch, end %#ok<CTCH>
            else
                stop(src);
            end
        catch ME
            stop(src);
            if isempty(testCase.TestData.dialogError)
                testCase.TestData.dialogError = ME;
            end
            releaseModals();
        end
    end
end

% ── helpers ─────────────────────────────────────────────────────────────────

function releaseModals()
% Last resort: nothing modal may be left blocking the session.
figs = findall(0, 'Type', 'figure');
for k = 1:numel(figs)
    if ~isvalid(figs(k)); continue; end
    try
        if strcmp(figs(k).WindowStyle, 'modal')
            uiresume(figs(k));
            delete(figs(k));
        end
    catch
        % A figure without WindowStyle, or already gone.
    end
end
end

function sweep(t)
if isvalid(t); stop(t); delete(t); end
releaseModals();
end
