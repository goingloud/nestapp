# Settings audit log

Oddities found while re-auditing steps for the typed-settings conversion
(see [ui-design-language.md](ui-design-language.md)), recorded so they can be
investigated and fixed properly later rather than chased one at a time.

Rules for this log:

- **Verified against code, not comments.** Upstream and nestapp comments are
  claims; each entry says what the code actually does.
- **Recorded, not fixed**, unless the conversion itself needed the fix (those
  are marked *fixed in conversion* and are in the changelog).
- Status: `open` (needs investigation or a decision), `fixed in conversion`,
  `upstream` (not ours to fix; noted so we do not trip on it).

Earlier findings from the first parameter audit are in
[param-audit-findings.md](param-audit-findings.md).

| # | Step | Finding (what the code does) | Status |
|---|---|---|---|
| 1 | Remove Bad Channels | The spectrum measure's frequency range defaults to **[1 6] Hz** in nestapp; `pop_rejchan`'s own default is `[1 EEG.srate/2]` (finputcheck, line 130). Origin of 1-6 Hz unknown. Only matters with measure = Spectrum. | open - decide default |
| 2 | Remove Bad Channels | `pop_rejchan` accepts measure `'std'` (code, line 128) which its help text does not list; for `std` the threshold is in µV, may be two-sided, and `norm` is ignored (line 156). Not offered by nestapp. | open - consider offering with its own controls |
| 3 | Remove Bad Channels (methods text) | `methodsClause` writes "(> N SD)" even when "Normalize" is off, when the threshold is in the measure's own units. | open |
| 4 | Remove Bad Channels | Channel numbers in "Evaluate channels" were ignored (dispatch fell through to all channels); protected channels replaced the evaluate list instead of being subtracted. | fixed in conversion |
| 5 | Re-Sample | `pop_resample`'s header says it uses the Signal Processing `resample`; the anti-aliasing filter is actually a Kaiser-windowed `firws` built from `fc`/`df` (myresample, lines 315-318 and 346-349). Our labels follow the code. | upstream - comment only |
| 6 | Modified Bandpass Filter (TESA) | With the FIR design (`eegfiltnew`), "Filter type" band-pass / high-pass / low-pass are silently ignored; only band-stop changes anything (`applyFilter`, line 541). | upstream - documented in the choice help |
| 7 | Modified Bandpass Filter (TESA) | The pop function's documented key is `pieceWiseTimeToExtend`; the parser's key is `piecewiseTimeToExtend`. It works only because `inputParser` is case-insensitive by default. | upstream - note |
| 8 | Modified Bandpass Filter (TESA) | "Automatic" pulse window reads `EEG.tmscut` from a previous Remove TMS Artifacts; without one, TESA asserts "Must specify artifact timespan". A cross-step dependency the pre-flight cannot see yet. | open - cross-step check |
| 9 | Modified Bandpass Filter (TESA) | An epoch too short for window ± extrapolation length fails with a bare "Assertion failed." (lines 164-165). nestapp could check `EEG.xmin`/`xmax` at dispatch and say what to change. | open |
| 10 | Modified Bandpass Filter (TESA) | Band-pass / band-stop / low-pass without the cutoff they need were passed through to TESA. | fixed in conversion (refused at pre-flight) |
