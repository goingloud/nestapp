# Channel tracking, counting, and electrode protection

Investigation notes from the June 2026 review of how nestapp removes, counts,
protects, and reports EEG channels. Written after a report seemed to disagree
with the QC figure on `rtmsct013_3_pre_SPL`.

## TL;DR

- The per-file channel counting is **correct**. On the test file the report's
  `Rejected: 8` is exactly `2` ("Remove un-needed Channels") `+ 6`
  ("Remove Bad Channels"), and all 8 were interpolated back (`final == original`).
- The report total folds **deliberate** "un-needed" removals in with
  **bad-channel** rejections. That conflation — not an undercount — is what made
  "6 vs 8/15" look wrong.
- QC Panel 1 marks **flat/saturated** channels (`var < eps`, `|x| > 250 µV`)
  *still present in the data*, not removed channels. It uses different criteria
  than `pop_rejchan`, so it legitimately differs from the rejected count.
- Reports now **name** rejected/interpolated electrodes, which makes all of the
  above self-evident on the page (see `buildReportText` / `processOneFile`).
- Protected electrodes (`impelec`) are honored correctly by **Remove Bad
  Channels**. They are **not** honored by **Clean Artifacts (ASR)** or
  **Remove Bad Channels (ARTIST)** — but the test pipeline uses neither.

## Where channels are removed and counted

- Counting: `processOneFile.m` post-step block. A fall in `EEG.nbchan` is added
  to `report.channels.nRejected` only for steps in `channelRejectionSteps.m`
  (Remove Bad Channels, Remove Bad Channels (ARTIST), Remove un-needed Channels,
  Automatic Cleaning Data, Clean Artifacts, Automatic Continuous Rejection).
- Names (added June 2026): the same block snapshots `{EEG.chanlocs.labels}`
  before each step and `setdiff`s after, accumulating
  `report.channels.rejectedNames` / `interpolatedNames`. One mechanism gives both
  the count and the labels for every removal step.

## Protected electrodes (`impelec`)

`impelec` is a per-step "do not reject these" list. Enforcement is **per step**,
not global:

- **Remove Bad Channels** (`processOneFile.m`, `case 'Remove Bad Channels'`):
  builds a mask of protected channels and passes only the non-protected indices
  as `pop_rejchan`'s `elec` candidate set, so protected channels cannot be
  removed. Verified: with the 11-channel frontal protected list, all 11 are
  excluded from the candidate set and zero leak through.
- **Clean Artifacts / ASR** (`clean_artifacts`): supports `channels_ignore`
  natively — ignored channels are split off before cleaning and rejoined after,
  so they are never removed. The wrapper already plumbs a `Channels_ignore`
  parameter, but it is **not** wired to `impelec`; the two are separate
  parameters today. Protecting via ASR is therefore achievable natively (no fork
  of EEGLAB) by routing `impelec` into `Channels_ignore`.
- **Remove Bad Channels (ARTIST)** (`artistBadChannelsRansac.m`): in-house RANSAC
  wrapper. It has **no** keep-list — it computes `badChannels` and
  `pop_select`s them. Protecting here would require extending our wrapper to drop
  protected indices from `badChannels` before `pop_select`. That changes our
  removal step, not ARTIST's detection, so it does not deviate from the published
  ARTIST algorithm — but it is an extension we would own.

### Recommendation (deferred — counting/naming was the agreed scope)

If protection is later wanted everywhere:

1. ASR: map `impelec` → `Channels_ignore` in the `Clean Artifacts` case. Native,
   low-risk.
2. ARTIST RANSAC: add an optional protected-label argument and remove those
   indices from `badChannels` before `pop_select`. Small, local extension.

Until then, the new report names make any protected-channel removal **visible**
rather than silent.

## GMFP/GMFA — reuse TESA rather than re-derive

GMFP is identical to TESA's GMFA. `tesa_tepextract.m` computes it as
`EEG.GMFA.tseries = std(mean(EEG.data,3))`. `tepFieldCurve.m` mirrors that exact
one-line formula (default N-1 std across channels of the trial-averaged data),
verified byte-identical to `tesa_tepextract(EEG,'GMFA')` on a real 63-channel
file. We mirror rather than call `tesa_tepextract` to avoid its side effects
(mutates EEG, writes `EEG.GMFA`, prints, no ROI-restricted variant); LMFP applies
the same definition to the ROI subset, which TESA has no built-in function for.
