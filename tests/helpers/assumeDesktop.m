function assumeDesktop(testCase)
% ASSUMEDESKTOP  Skip a test that needs a display when there is none.
%
%   ASSUMEDESKTOP(testCase) calls assumeFail with a clear reason unless a Java
%   desktop is available, so GUI tests skip rather than fail on a headless CI
%   runner.
%
%   Named rather than inlined because the previous named version
%   (requireDesktop) was deleted during a file split and re-inlined into four
%   setupOnce blocks - the opposite of the intended direction.
%
%   See also: launchApp
    if ~usejava('desktop')
        testCase.assumeFail('No display - skipping GUI test');
    end
end
