function EEG = recordBadChannels(EEG, labelsBefore)
% RECORDBADCHANNELS Note which channels a bad-channel step just removed.
%   EEG = RECORDBADCHANNELS(EEG, labelsBefore) compares the channel labels
%   present before a bad-channel rejection step (labelsBefore, a cell array
%   of labels captured just before the step ran) against the labels still in
%   EEG now, and appends any that disappeared to EEG.etc.nestapp.badChannels.
%
%   This list is the source of truth for the "Interpolate Channels" step:
%   only channels rejected *as bad* are interpolated back. Channels removed
%   on purpose - e.g. by "Remove un-needed Channels" or a keep-list - also
%   land in EEG.chaninfo.removedchans (pop_select records everything it
%   removes), so without this list the interpolation step cannot tell an
%   intentionally-dropped channel from a genuinely bad one and would
%   resurrect both. Call this after every step that removes bad channels.

    labelsAfter = {EEG.chanlocs.labels};
    removed = setdiff(labelsBefore, labelsAfter);
    if isempty(removed)
        return;
    end

    % Defensive: EEG.etc may be missing or a non-struct on some datasets.
    if ~isfield(EEG, 'etc') || ~isstruct(EEG.etc)
        EEG.etc = struct();
    end
    if ~isfield(EEG.etc, 'nestapp') || ~isstruct(EEG.etc.nestapp)
        EEG.etc.nestapp = struct();
    end
    if ~isfield(EEG.etc.nestapp, 'badChannels')
        EEG.etc.nestapp.badChannels = {};
    end

    % union() also de-duplicates, so a channel removed across two steps
    % (or a re-run) is only listed once.
    EEG.etc.nestapp.badChannels = union(EEG.etc.nestapp.badChannels, removed);
end
