# nestapp parameter-surface audit — consolidated

55 steps / 301 declared params, 10 disjoint batches. **ALL 10 BATCHES IN** — none lost.
Roster: 1(a aebee) 2(a2ebb8) 3(a97d4d) 4(aaaebd) 5(a242e6) 6(a45321) 7(a1623a)
8(a783c9) 9(a90e0e) 10(aad9f0).

Verdicts: **A** dead · **B** conditional-ungated · **C** missing upstream option ·
**D** invented (nestapp-authored) · **E** mismatch.

**[VERIFIED]** = I independently reproduced it (read the cited source line, or triggered
the runtime behaviour). **[reported]** = agent claim, not yet re-checked.

---

# FIX-LOCUS FILTER — only nestapp code is in scope

Policy: **never edit EEGLAB/TESA/AARATEP source.** A fix that lives upstream is out of
scope; patching our local copy would silently fork it from what every other install runs.
Every finding is one of:

- **[NESTAPP]** the fix is in nestapp code (dispatch, registry value, description). Actionable.
- **[EXPOSE]** the underlying bug is UPSTREAM, but nestapp advertises the broken knob. We
  can't fix the bug — the nestapp action is to STOP exposing / relabel it. Actionable, but
  the action is de-register-or-relabel, not repair. De-registering a param needs the same
  saved-pipeline migration care as the Stage-B/D refactor.
- **[UPSTREAM]** bug is upstream and there is no nestapp knob — we silently inherit it.
  NOT actionable without forking. Leave alone; note only.

## [NESTAPP] — code bugs, fix in place

Progress: **DONE** = fixed + regression test + pushed. Others pending.

| # | Finding | Fix locus | Status |
|---|---|---|---|
| 0 | **Quality Gate rank/nbchan always sees 1** (user-found, audit MISSED it) — `rank(double(single_data))` upcasts float32 noise into a spurious dimension, so avg-ref data reports full rank and the gate never fires | `src/qa/qualityGate.m:computeRankRatio` | **DONE** `9774be4` |
| 1 | CleanLine `chanlist` cleans wrong set / crashes | `processOneFile.m` → `cleanlineChanList.m` | **DONE** `7549585` |
| 2 | `tmslabel`/`pairlabel` silently ignored (casing) | dispatch → `renameVarinKeys.m` | **DONE** `3e17f7a` |
| 3 | TEP Peak Output discards its result | `processOneFile.m` → `EEG.etc.nestapp.tepPeakOutput` | **DONE** `7640f2a` |
| 4 | `detrend` offers `polynomial` (upstream rejects) | `stepRegistry.m` + dispatch guard | **DONE** `37a42ad` (offer all 3, guard toolbox deps with clear error) |
| 5 | SSP-SIR `PC` labelled inverse of behaviour | `stepRegistry.m` label/description | **DONE** `03f8188` |
| 6 | `fromASR` always throws; DDWiener thresh 9-vs-20 | dispatch: threshold=[] default, pass only when set, gate off for fromASR | **DONE** `be5320a` (TESA 1.2 now installed & verified) |
| 7 | `interpchan` offers crashing `on` | dispatch: on→[] | **DONE** `72fbadf` |
| 8 | `pop_rejcont` offers `sum`/`fill`/`hann`/`blackman` | `stepRegistry.m` offered lists → real upstream values | **DONE** `974fbed` |

| 9 | `pop_chanedit` lookup killed by arg order | dispatch: load before lookup | **DONE** `74cabf4` |
| 10 | `Choose Data Set` default `''` type-invalid | default []→guard | **DONE** `72fbadf` |
| 11 | Manual channel removal index misalignment | tighten coord guard (require all) | **DONE** `74cabf4` |
| 12 | `components` description inverts behaviour | `stepRegistry.m:893` description | **DONE** `03f8188` |
| 13 | `maxrej` documented fraction, consumed percent | `stepRegistry.m` description/units | **DONE** `03f8188` |
| 14 | Quality Gate QG-1…QG-4 | `src/qa/*` (batch/slack removed per user) | **DONE** `90b8bf1`,`86f2119`,`a607928` |
| 15 | `Flag ICA` scalar threshold silently disables class | dispatch rejects non-pair | **DONE** `74cabf4` |
| 16 | `'off'` unreachable for 5 clean_rawdata criteria | `convertParam` preserves 'off' | **DONE** `74cabf4` |
| 17 | Misleading descriptions (overwrite/plotag/state/epoch_len/cutEvent/tablePlot) | `stepRegistry.m` | **DONE** `9666095` |

## [EXPOSE] — DONE `8098af5`: stopped advertising (per user)

| Finding | Upstream deadness | action taken |
|---|---|---|
| `Remove Bad Epoch / threshold` | `pop_autorej.m:155-161` commented out | **de-registered** |
| `Interpolate Channels / trange` | `pop_interp.m:61` clobbers on entry | **de-registered** (dispatch → 3-arg pop_interp) |
| `Frequency Filter / usefft` | `pop_eegfiltnew` errors on non-zero | **de-registered** (usefftfilt kept) |
| `Epoching / epochinfo` | `pop_epoch.m:223` never read | **de-registered** |
| `Remove ICA Components / plotFreqX` mislabel | functional (analysis grid), not dead | **relabelled**, not removed |

## [UPSTREAM] — inherited, NOT actionable (note only, never patch)

- `pop_autorej` reads wrong kurtosis field (`icarejkurt` vs `rejkurt`)
- `pop_runica` re-adds PCA when "off"; rank on first 3000 samples (60-vs-61 drift)
- `pop_subcomp` wipes `EEG.reject` wholesale
- `tesa_medfilt` even-order hardcoded-30 bug; `tesa_findpulse` strcmpi-accept/case-assign
- `maximizePlotsToMonitor` `@isschar` typo (already correctly omitted)

## [D — INVENTED] — user judges case-by-case, nothing auto-removed
Listed in Tier 5 below. Not bugs; nestapp knobs over upstream constants, all defaulting to
the upstream value. Only `aaratepMuscleClassifier.m` is genuinely nestapp-authored logic
(a byte-for-byte transcription of an upstream inline block).

## [C — MISSING] — nestapp incompleteness, not bugs
Exposing an upstream option we omit is a nestapp registry addition. Separate decision from
bug-fixing; ranked in Tier 4 below.

---

# TIER 1 — silent wrong results / guaranteed breakage

### 1. CleanLine cleans the wrong channel set — or crashes  [VERIFIED, runtime]
`processOneFile.m:561-566`, default `chanlist=[1 64]` (`stepRegistry.m:451`).
```matlab
if vars{ind+1}(2) > EEG.nbchan
    vars{ind+1} = 1:EEG.nbchan-1;   % drops the LAST channel
else
    vars{ind+1} = 1:vars{1,ind+1};  % 1:[1 64]
end
```
Reproduced on R2026a across montage sizes:

| Montage | Outcome |
|---|---|
| 19 / 32 / 63 ch | **silently cleans all but the last channel** |
| 64 / 65 / 128 ch | **hard error**: `Colon operands must be real scalars` |

Note the agent predicted "silently cleans 1 channel" from older MATLAB colon semantics;
on R2026a the `else` branch errors instead. Both branches are wrong. `1:EEG.nbchan-1`
should be `1:EEG.nbchan`; the `else` should be `1:EEG.nbchan` too (or just pass `[]`,
which upstream already reads as all-channels, `cleanline.m:156`).

### 2. TEP Peak Output throws its entire result away  [VERIFIED]
`processOneFile.m` `case 'TEP Peak Output'` calls
`pop_tesa_peakoutput( EEG, vars{:} );` — **no output captured**. Upstream is
`function output = tesa_peakoutput(...)` and contains **zero `assignin`** calls
(grep count 0), so the "returned to workspace" message in its own source is only true
when a human types it at the prompt. All 6 params compute a table that is discarded.
Same defect class as the old `TESA De-Trend` no-op. Registry claims
(`stepRegistry.m:1403`) results are "exported to the MATLAB workspace as a table".
**This — not "no peaks found" — is why `averageWin` looked inert in my first sweep.**

### 3. `Interpolate Channels / trange` is dead three times over  [VERIFIED]
`pop_interp.m:61` is `t_range = '';` — unconditional, 2 lines into the body, before any
use. Caller's 4th arg destroyed on entry. Underneath that: nestapp declares **ms**,
`eeg_interp.m:322` does `floor(t_start*srate)` = **seconds**; and `eeg_interp.m:321`
guards with `length(size(tmpdata))==2` = **continuous only**.

### 4. `TESA De-Trend / detrend` offers a value that hard-errors  [VERIFIED, runtime]
nestapp offers `linear|polynomial` (`stepRegistry.m:392`); upstream accepts
`linear|exponential|double` (`tesa_detrend.m:63-65`). Reproduced:
`polynomial` → `error: The type of detrend to apply is incorrect`.
So 1 of 2 offered values fails, and both genuinely-valid alternatives are unreachable.
(`exponential`/`double` also need the Curve Fitting Toolbox — `ensureCurveFittingFit.m`
exists but is wired only to the AARATEP decay step.)

### 5. SSP-SIR `PC` is labelled the inverse of what it does  [VERIFIED]
nestapp: `'Variance kept'`, `%` (`stepRegistry.m:1274`).
Upstream: *"The number of artifact PCs to be **removed**"* (`tesa_sspsir.m:62`), and
mechanically `P = eye - U(:,1:PC)*U(:,1:PC)'` (`:484`) — the first `PC` components are
**projected out**. So `{'data',90}` **removes** 90% and keeps ~10%.
**This is a mechanical candidate explanation for the "SSP-SIR over-cleans, halves
N100/P200" finding already recorded in project memory.**

### 6. `Detect Bad Channels (TESA)` — `fromASR` always throws  [reported, TESA 1.2 not installed]
`tesa_detectbadchannels.m:240` asserts `isempty(s.threshold)` for `fromASR`;
nestapp's dispatch **unconditionally** passes `threshold` [VERIFIED locally:
`processOneFile.m` passes `'threshold', o.threshold` with no branch].
Also: `threshold` default hardcoded 9 (`stepRegistry.m:602`) [VERIFIED], but upstream
resolves it per method — 9 for PREP_deviation, **20 for the DDWiener family**. The
registry's own `s.info` documents the 9-vs-20 split it cannot express, so DDWiener
methods run ~2x more aggressive than intended, silently.

### 7. `Re-Reference / interpchan` — offered value crashes, working value unreachable  [VERIFIED, runtime]
GUI offers `on|off`. Upstream has no `'on'` branch: `isempty`→`isstruct`→`isreal`
(`pop_reref.m:265,268,325,330`). `isreal('on')` is **true**, `double('on')=[111 110]`,
so it indexes `EEG.urchanlocs([111 110])`. Reproduced: `Index exceeds array bounds`.
The working enable value is `[]`, which `stripEmptyVarin` strips.

### 8. `Frequency Filter / usefft` — dead, and aborts if changed  [VERIFIED, runtime]
`pop_eegfiltnew.m:22` header: *"ignored (backward compatibility only)"*; then
`if g.usefft; error('FFT filtering not supported...')`. Reproduced. Sits directly above
`usefftfilt`, the real option, with a near-identical label.

### 9. Three `pop_rejcont` value sets abort the run  [reported]
`mode='sum'`, `correct='fill'`, `taper='hann'|'blackman'` do not exist upstream
(`pop_rejcont.m:158,159,168` allow `mean|max`, `remove|blank`, `none|hamming`).
Two have descriptions documenting behaviour never implemented.

### 10. `pop_chanedit` argument order kills the standard_1005 lookup  [reported]
`processOneFile.m:178-179` passes `'lookup'` before `'load'`; `pop_chanedit.m:470`
processes args in order and the `'load'` case (`:752-763`) replaces `chans` wholesale
and resets `chaninfo`. The lookup is pure waste — and the step's info text advertises it.
Also loses `chaninfo.nosedir`, which silently rotates every topography.

### 11. `Choose Data Set` default is type-invalid  [reported]
`s.defaults.dataSetInd = ''` with `'type','integer'`; no `stripEmptyVarin` on this
branch, so `''` reaches `finputcheck` → `'must be numeric'` → bare `error`.
Clearing the cell yields `NaN` → different opaque failure deeper in `eeg_retrieve`.

### 12. Manual channel removal can remove the WRONG channels  [reported]
`pop_topochansel` returns indices into the **coordinate-bearing subset**; nestapp treats
them as indices into full `chanlocs` (`processOneFile.m:376`). The guard at `:342-343`
only rejects the all-empty case, not partial coordinates. Silent, with a plausible log line.

### 13. `Remove Flagged ICA Components / components` DISCARDS the ICLabel flags  [VERIFIED]
`pop_subcomp.m:159-171`: `EEG.reject.gcompreject` is consulted **only when `components`
is empty**; supplying a list takes the `else` branch, which never looks at the flags.
nestapp's description (`stepRegistry.m:893`) says "Extra component indices to remove **in
addition to** flagged ones" — the exact inverse. A user who adds two extra ICs gets a
dataset where those two are gone and **every ICLabel-flagged artifact component remains**,
reported as success. Most damaging finding for ICLabel-based pipelines. The call is
correct; the description is the bug.

### 14. `Find TMS Pulses / tmslabel` + `pairlabel` silently ignored (casing)  [VERIFIED, runtime]
`tesa_findpulse.m` accepts option names case-**insensitively** (`strcmpi`, :114) but
assigns using the caller's spelling (`options.(inpName)`, :115). nestapp's registry keys
are lowercase `tmslabel`/`pairlabel`; upstream fields are `tmsLabel`/`pairLabel`. Replayed
in MATLAB: passing them creates stray unread fields and leaves the real ones at default.
- `tmslabel` — masked: both default to `'TMS'`.
- **`pairlabel` — live bug:** nestapp default `{'pp'}`, upstream `{'TMSpair'}`. Paired
  events get labelled `'TMSpair'`; any downstream step keyed on `'pp'` finds **zero
  events**. One-character fix each: `tmsLabel`, `pairLabel`.

### 15. `Remove Bad Epoch / maxrej` — documented as fraction, consumed as percent  [reported]
`pop_autorej.m:19-20,172,196` treats it as a **percent** (`opt.maxrej/100`);
`stepRegistry.m:1019,1027` documents "fraction" with range `[0 1]`. A user entering `0.05`
for 5% requests 0.05%, which no realistic trial count can satisfy → step becomes a no-op,
silently. Masked today only because the default `[]` is stripped to upstream's `5`.

### 16. `Remove Bad Epoch / threshold` is inert upstream  [reported — overturns earlier triage]
`pop_autorej.m:155-161` — the block that would act on the amplitude marks is **commented
out**; `numrej` is overwritten at :167 and the marks discarded at :237. So `threshold`
has no effect at any value on any data. **This corrects my first-sweep triage**, which
attributed its inertness to the synthetic fixture. Registry text
(`stepRegistry.m:1016-1017`) invites tuning it. The genuinely-wired amplitude rejection in
this code path is `pop_epoch`'s `valuelim` — which `Epoching` does not expose.

### 17. `Epoching / epochinfo` is dead  [reported]
`pop_epoch.m:223` is its only appearance — parsed, never branched on. Setting `'no'` does
nothing.

---

# TIER 2 — conditional params with no greying rule (category B)

The `interpWin` / `refract` / `ISI` pattern, unfixed elsewhere. **~30 instances.**

- **`Remove ICA Components (TESA)`: 10 of 18 params** — every threshold/window/electrode
  setting is gated on its detector toggle (`tmsMuscle`, `blink`, `move`, `muscle`,
  `elecNoise`) with **zero** rules. [reported]
- **AARATEP Pipeline: `plotChans`, `plotTPOIs`, `plotXLim`** — `plotChans` is fully inert
  unless `doDebug='on'`, which is off by default. [reported]
- **`Clean Artifacts`: 6** (2 data-controlled, so not expressible as rules). [reported]
- **SSP-SIR `timeRange`** — inert at the shipped `artScale='automatic'`; the most
  load-bearing-looking knob on the step does nothing by default. [reported]
- **Quality Gate: all 13 `*WarnAt`** + `thresholdMode` ungating 30 others. [reported]
- **`TEP Peak Output` `calcType='area'`** — requires a preceding GMFA extraction;
  cross-step, so needs `checkStepDependencies`, not `paramEnableWhen`. [reported]

---

# TIER 3 — Quality Gate (nestapp-authored; 32 params)

- **QG-1 `maxRejected*Pct` silently PASS when context is missing** — `rejectionPct`
  returns NaN on 5 paths, `checkMax` early-returns on NaN with no reason recorded and
  no metric flagged. Reachable whenever the gate precedes `Epoching`/`Load Data`.
  There is no verdict tier meaning "not evaluated". [reported]
- **QG-2 batch mode silently drops 9 of 15 thresholds** — `FIELD_TO_PARAM` covers 6.
  Includes both `maxRejected*Pct`. [reported]
- **QG-3 all 6 batch-mode `*WarnAt` overrides are dead code** — `enabledThresholds`
  never persists `*WarnAt` keys, so the lookup always misses and falls back to slack. [reported]
- **QG-4 the GMFA peak check is fully implemented and unreachable** — `maxGmfaPeak`,
  `gmfaWindowMs`, `maxGmfaPeakWarnAt` are wired end-to-end in `qualityGate.m` but
  **declared nowhere** in `stepRegistry.m`. Directly relevant to the blown-GMFA failure
  mode in the nestTEP batch. [reported]

---

# TIER 4 — missing upstream options (category C), ranked

1. **`NumSamples`** (RANSAC sample count) — missing from **both** clean_rawdata steps.
   Directly controls the RANSAC bad-channel detector this project relies on.
2. **`Remove Decay Artifact`: `maxTau`, `blendedRemovalTauSpan`** — the decay-fit bounds
   the registry blurb advertises but does not expose. `maxTau` is already a known live
   tuning axis in project memory.
3. **`Re-Reference / refica`** — `'on'|'off'|'backwardcomp'|'remove'`. This pipeline
   re-references *after* ICA and upstream's own docs recommend `'remove'`; we take the
   default `'on'` that upstream warns against.
4. **SOUND `replaceChans`, `leadfieldInFile`** — the atomic SOUND step cannot use a custom
   leadfield while the orchestrator step can. `replaceChans` is TESA's native
   bad-channel reconstruction, which a registry comment describes as lost.
5. **SSP-SIR `EEG_control` + `artScale='control'`** — the Biabani 2019 sensory-confound
   subtraction. Relevant to the N100 sensory-confound finding in project memory.
   Also `manualConstant`, TESA's documented mode for bounding signal attenuation.
6. **`Extract TEP / fileName`** — required for `pairCorrect='on'`; without it that switch
   can never succeed [VERIFIED: `tesa_tepextract.m:205-207` errors; `fileName` appears
   once in stepRegistry, not as a param].
7. **`Frequency Filter / channels`, `chantype`** — without them every channel is filtered,
   including EMG/EOG/ECG auxiliaries.
8. **`pop_topochansel 'labels','on'`** — the manual channel picker currently shows
   **unlabelled dots**. One string makes it usable.

---

# TIER 5 — invented params (category D). **User judges; nothing removed.**

Verified: **no vendored TESA code in the repo** — `src/` contains only `tesaVersion.m`
and a template `.mat`. The stale entries in the opening git status are gone. [VERIFIED]

Batch 9 found the AARATEP suspicions **not borne out** — AR-Blend, Remove Decay and
Modified Bandpass all call vendored `c_*` functions, with call shapes matching the
orchestrator's own almost argument-for-argument.

| Param | Step | Upstream constant it exposes | Default matches upstream? |
|---|---|---|---|
| `winStartMs`/`winEndMs` | AARATEP Muscle | `tmsMuscleWinTimespan=[11 30]*1e-3` hardcoded | yes (11, 30) |
| `artifactMultiplier` | Modified Bandpass (AARATEP) | literal `*3` | yes (3) |
| `protect` | Remove Bad Channels (manual) | none — nestapp logic | n/a |
| `impelec` | Remove Bad Channels | none — nestapp logic | n/a |
| channel selection | Interpolate Channels | upstream takes `bad_elec` as an arg | n/a |
| `includeFileName` | Save New Set | none — path plumbing, correctly stripped | n/a |
| `coordCheck`, `needchanloc`, `eachFilediffPath` | Load Channel Location | none — GUI plumbing | n/a |

**One genuinely nestapp-authored algorithm**: `aaratepMuscleClassifier.m`. Upstream has
no callable function — the algorithm is inline at
`c_TMSEEG_Preprocess_AARATEPPipeline.m:400-412`. Batch 9 diffed it line by line and
found the arithmetic **byte-for-byte identical**. Extraction was the only way to offer it
as a standalone step. Divergence: no over-rejection guard, plus a `markICClass` reporting
side effect with no upstream analogue.

---

# Cross-cutting structural findings

1. **`paramEnableWhen` is display-only.** `disabledParamKeys` feeds only the UITable
   greying and the edit-refusal alert. Nothing strips a disabled param, and
   `paramsToVarin` serialises every field. All 4 existing gates are safe **by luck** —
   upstream ignores the stale value, or the dispatch strips it separately. A future gate
   on a param upstream reads unconditionally would grey a control that still takes effect.
2. **`s.defaults` vs `s.params` split creates HIDDEN params** — keys in `defaults` with no
   `makeParam` entry are passed upstream at a hardcoded value, invisible and uneditable.
   Found: 3 (Save New Set), 9 (Remove un-needed Channels), 5 (compselect feedback flags),
   2 (EDM), 3 (Automatic Continuous Rejection), 7 (CleanLine) = **29 hidden params**.
   CleanLine's hidden `newversion=0` is the controller that makes `taperbandwidth` dead.
   Nothing documents whether this split is convention or drift.
3. **`convertParam` flattens every `'vector'` param to a row** — any Nx2 matrix param is
   destroyed on first GUI edit. `Find TEP Peaks / peakWin` ships correct as a 3x2 default
   and breaks the moment it is tuned.
4. **`'off'` is unreachable for 5 clean_rawdata criteria** — scalar-typed, so
   `convertParam` turns `off` into `NaN`. The two clean_rawdata steps then diverge:
   `Clean Artifacts` passes NaN through (stage runs with a NaN threshold);
   `Automatic Cleaning Data` strips it (upstream's default silently applies). Two steps,
   two wrong answers, neither disabled.
5. **`Clean Artifacts` and `Automatic Cleaning Data` call the same function** with
   complementary, incomplete surfaces and 3 conflicting defaults.

---
# Additional TIER-2 / structural items from batches 6 & 7

- **`pca = -1` collides with upstream meaning** — nestapp: full numerical rank; EEGLAB
  (`runica.m:290`, `pop_runica.m:559`): nbchan−1. They coincide on average-referenced data,
  so divergence appears only on some files — the intermittent component-count drift class.
- **`pca = 0` ("off") does not disable PCA for Infomax** — `pop_runica.m:518-520` re-adds
  `'pca', tmprank` on rank-deficient data, rank computed on the **first 3000 samples only**
  (`:475`). Plausible source of the 60-vs-61 component drift in project memory.
- **`Flag ICA Components` bounds are STRICT, documented inclusive** — `pop_icflag.m:82`
  uses `>` and `<`; `stepRegistry.m:860` says ">= 90%". A component scoring exactly 1.000
  is never flagged. Also: a scalar threshold entry scalar-expands to `[x x]` → `p>x & p<x`
  → silently disables that class. **ICLabel class ORDER verified correct** (7 classes,
  matches `iclabel.m:64-66`) — no transposition bug.
- **`Remove Flagged ICA / keepcomp` inert at default** — read only inside the `components`
  non-empty branch (`pop_subcomp.m:167`); with default `components=[]` it never executes.
  No `paramEnableWhen`.
- **`plotag != 0` blocks the batch** — `pop_subcomp.m:180-204` opens a modal questdlg;
  Cancel returns unchanged (silent no-op logged as success). Under parfor: invisible hang.
- **Iteration caps asymmetric** — Picard exposes `maxiter`; FastICA (`maxNumIterations`)
  and Infomax (`maxsteps`) expose nothing. Non-convergence unrecoverable from the GUI.
- **`Run ICA (FastICA)` vs `Run TESA ICA`** — near-duplicate FastICA entry points, silently
  different `g` default (`tanh` vs `gauss`), only one can do PCA reduction.
- **CLEAN STEPS (nothing to fix):** `Label ICA Components` (29), `Remove TMS Artifacts`
  (37), `Interpolate Missing Data (TESA)` (40), `Fit Artifact Model` (21), `Re-Sample` (14),
  `Robust Detrend/Demean` (17/18), `Run TESA ICA` params — faithful wrappers.
- **Not-a-bug confirmations:** `Find TMS Pulses / refract` correctly UNgated (upstream reads
  it unconditionally, `tesa_findpulse.m:173`); `Fix TMS Pulse / rate` correctly ungated
  (both branches). Do not "fix" these by analogy to their gated siblings.

# Category-B tally is smaller than predicted
Batches 4, 6, 7 all reported **zero** new category-B gaps needing a rule — the four
existing gates plus the two I added (ISI/refract on Extract TEP & Fix TMS Pulse) cover the
TMS-pulse family completely. The real B cluster is concentrated in ONE step:
**`Remove ICA Components (TESA)` — 10 of 18 params** gated on detector toggles with no rules.
