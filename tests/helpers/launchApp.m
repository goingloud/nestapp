function app = launchApp(testCase)
% LAUNCHAPP  Construct nestapp for a GUI test and register its teardown.
%
%   app = LAUNCHAPP(testCase) creates the app, schedules delete(app) as a
%   teardown on testCase, and drawnow's so the window is realised before the
%   caller inspects it.
%
%   Three files in tests/ui had this same three-line preamble. It is worth
%   sharing not for the lines but because forgetting the teardown leaves a
%   modal-ish app window on screen for the rest of the run, which is how a UI
%   suite ends up unusable.
%
%   See also: assumeDesktop
    app = nestapp;
    testCase.addTeardown(@() delete(app));
    drawnow;
end
