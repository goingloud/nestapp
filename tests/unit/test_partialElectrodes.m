% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function tests = test_partialElectrodes
% TEST_PARTIALELECTRODES  "In some files" is not "in no files".
%
%   groupCurves computes on the modal montage, so res.channelLabels reports
%   what can be averaged - and an electrode in 30 of 32 files then looks
%   identical to one in none. The ROI picker needs the difference, because
%   including the first makes the ROI mean a different set of channels per
%   file and including the second is impossible.
%
%   Run: runtests('tests/unit/test_partialElectrodes')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
r = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(r);
addpath(genpath(fullfile(r, 'src')));
testCase.assumeNotEmpty(which('partialElectrodes'));
end

function c = cacheOf(varargin)
c = struct('ok', {}, 'labels', {});
for i = 1:numel(varargin)
    c(i).ok = true; c(i).labels = varargin{i};
end
end

function test_namesWhatSomeFilesHaveAndTheMontageDoesNot(testCase)
c = cacheOf({'Cz','Pz','FT9'}, {'Cz','Pz'});
testCase.verifyEqual(partialElectrodes(c, {'Cz','Pz'}), {'FT9'});
end

function test_aUniformCohortHasNoPartialElectrodes(testCase)
c = cacheOf({'Cz','Pz'}, {'Cz','Pz'});
testCase.verifyEmpty(partialElectrodes(c, {'Cz','Pz'}));
end

function test_matchingIsCaseInsensitiveLikeEveryOtherLabelComparison(testCase)
c = cacheOf({'CZ','pz'});
testCase.verifyEmpty(partialElectrodes(c, {'Cz','Pz'}), ...
    'a spelling difference is not a different electrode');
end

function test_failedLoadsDoNotContributeElectrodes(testCase)
% A file that did not load has no labels to offer, and counting it would
% advertise an electrode nothing can average.
c = cacheOf({'Cz','FT9'});
c(2).ok = false; c(2).labels = {'Iz'};
testCase.verifyEqual(partialElectrodes(c, {'Cz'}), {'FT9'});
end

function test_anEmptyCacheIsNotAnError(testCase)
testCase.verifyEmpty(partialElectrodes([], {'Cz'}));
testCase.verifyEmpty(partialElectrodes(struct('ok', {}, 'labels', {}), {'Cz'}));
end
