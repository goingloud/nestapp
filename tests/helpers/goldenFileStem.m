% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function stem = goldenFileStem(stepName)
% GOLDENFILESTEM  The filename a step's recorded behaviour is stored under.
%   stem = GOLDENFILESTEM('Remove TMS Artifacts (TESA)')
%       -> 'Remove_TMS_Artifacts_TESA'
%
%   ONE definition, used by the recorder and the checker. It had been written
%   twice - recordGoldens wrote files with one regex and StepGoldenTest looked
%   for them with another - and the test's own comment documented the risk
%   rather than removing it: "if the two ever disagree, every golden looks
%   missing at once".
%
%   They already differed. `[^\w]+` leaves underscores alone where
%   `[^A-Za-z0-9]+` collapses them, so any step name containing an underscore
%   would have been written to one path and looked for at another. No current
%   step name has one, which is exactly how a latent difference survives:
%   verified all ten produce identical stems under both, and that all ten
%   files on disk match, before consolidating.
%
%   \w is the kept form, so an underscore in a future step name stays put
%   rather than being folded into its neighbours.
%
%   See also: recordGoldens, StepGoldenTest, eegDigest

stem = regexprep(char(stepName), '[^\w]+', '_');
stem = regexprep(stem, '_+$', '');
end
