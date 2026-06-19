
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (C) 2023-2026 Aref Pariz and Wesley Dunne.
% Part of nestapp; see the LICENSE file for full terms.
function pol = windowPolarity(window)
% WINDOWPOLARITY  Peak polarity for a window of interest, defaulting to 'auto'.
%   pol = WINDOWPOLARITY(window) returns window.polarity when present and
%   non-empty, otherwise 'auto' (largest absolute deflection). Used wherever a
%   window's peak is measured (computeWindowMeasures, the Analysis table, the
%   per-file results table).
    pol = 'auto';
    if isfield(window, 'polarity') && ~isempty(window.polarity)
        pol = window.polarity;
    end
end
