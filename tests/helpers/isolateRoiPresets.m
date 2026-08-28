function isolateRoiPresets(testCase)
% ISOLATEROIPRESETS  Give a test a clean ROI-preset store, then restore it.
%
%   ISOLATEROIPRESETS(testCase) clears the 'roiPresets' preference for the
%   duration of the test and restores the real value on teardown.
%
%   Presets are a LIVE user preference. Without this a test both reads the
%   developer's own presets - so an assertion like "the dropdown opens on the
%   F3 cluster" is false on any machine where they saved one - and writes to
%   them, which is not something a test suite may do to someone's settings.
%
%   See also: roiPresets, saveRoiPreset
    had   = ispref('nestapp', 'roiPresets');
    saved = getpref('nestapp', 'roiPresets', struct('name', {}, 'labels', {}));
    testCase.addTeardown(@() restore(had, saved));
    if had
        rmpref('nestapp', 'roiPresets');
    end
end

function restore(had, saved)
if had
    setpref('nestapp', 'roiPresets', saved);
elseif ispref('nestapp', 'roiPresets')
    rmpref('nestapp', 'roiPresets');
end
end
