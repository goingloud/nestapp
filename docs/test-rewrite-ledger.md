# nestapp test-suite rewrite — salvage ledger

The old suite is being replaced, not audited. Before any of it is deleted, this file records the
one thing in it that is **not re-derivable from the source**: which defects were real, which test
pinned each, and whether the new suite must pin it too.

A rewrite's characteristic failure is that it tests what its author expects to break rather than
what actually broke. This ledger is the specification that prevents that, and the
**historical-bug replay** in the plan's verification step 5.2 is scored against it: every row marked
**PIN** must be caught by the new suite, demonstrated by reintroducing the defect on a scratch
branch and watching it go red. A PIN row the new suite does not catch is a gap to fill, not a row
to close.

Sources: the 22 cases in `tests/regression/` (each carrying an explicit `BUG:`/`FIX:` comment), and
the 17 numbered findings in `docs/param-audit-findings.md`, all marked DONE with commit SHAs.

**Status values** — `PIN`: the new suite must catch this. `OBSOLETE`: the code it guarded is gone.
`DROP`: judged not worth a test, with the reason stated. `DONE <sha>`: pinned, with the new test named.

---

## Baseline at the moment of writing

| metric | value |
|---|---|
| test cases | **916** — unit 769, integration 96, ui 27, regression 22, characterization 2 |
| exec test lines | **11,201** (non-blank, non-comment) across 116 files |
| exec src lines | 15,488 — test:src ratio **0.72** |
| style | 85 function-based / 29 `classdef`; 0 `TestTags`, 0 `TestParameter`, 0 fixtures |
| `assumeFail` sites | **38** |
| cases run by no automated gate | **125** (13.6%) — all of integration, ui, characterization |
| lint | 0 errors, 23 warnings |
| untracked `.mat` litter in test dirs | 36 |

**Wall-clock, measured** (this machine, EEGLAB present, warm session):

| suite | cases | pass | fail | skip | seconds |
|---|---|---|---|---|---|
| `fast` (unit + regression) | 791 | 791 | 0 | 0 | **57.6** |
| `ui` | 27 | 27 | 0 | 0 | 32.3 |
| `integration` | 96 | 96 | 0 | 0 | 81.3 |
| `characterization` | 2 | 2 | 0 | 0 | 3.3 |
| **total** | **916** | | | | **174.5** |

Two things this table is evidence for. **`fast` skips nothing here** — because EEGLAB is on the
path locally; on the CI runner the same 791 cases include ~21 that skip and never run, which is the
local-vs-CI divergence the rewrite removes by construction. And **`fast` takes 57.6 s**, which is
why the target for `pure` is under 20 s: a suite that costs a minute is not one you run constantly,
and one you do not run constantly is how this suite reached its present state.

---

## A. Regression pins — `tests/regression/` (22 cases)

### A1. `test_regressions.m` (10 cases)

| # | Defect it pins | Kind | Status |
|---|---|---|---|
| A1.1 | `replace(fname,' ','_')` return value discarded, so Save New Set never renamed the file | source | **PIN** — behavioural: run the save step with a spaced name, assert the written filename |
| A1.2 | `input()` in `runPipelineCore` blocked GUI execution | source | **PIN** — belongs in T5 (no step reaches an interactive prompt in batch) |
| A1.3 | `input()` in `nestapp.m` | source | **PIN** — same T5 check, one assertion over both files |
| A1.4 | Methods text said "N/N retained" when channels were removed then interpolated, because `finCh == origCh` after interpolation | functional | **PIN** — T3, and a genuine wrong-number-in-a-report bug |
| A1.5 | `assignin('base', …)` leaking internal pipeline vars into the base workspace (`EEG` is deliberate and exempt) | source | **PIN** — T5, behavioural: snapshot `who('base')` across a run |
| A1.6 | `runPipelineCore` calling `app.updateReportsTab()` — circular dependency back into the class that invoked it | source | **PIN** — T5, but assert the *architecture* (function runs headless with no app) rather than grepping for the name |
| A1.7 | `uisave` does not return the chosen path, so `pipelineDirty` was never cleared | source | **PIN** — T6, behavioural via the real handler |
| A1.8 | Steps must be written to `EEG.history` so `eegh` shows the record | source | **PIN** — T5, behavioural: run a step, read `EEG.history` |
| A1.9 | `buildHistoryEntry` exists | source (`isfile`) | **DROP** — a bare file-existence check. A1.8's behavioural test subsumes it and cannot pass if the function is missing. |
| A1.10 | The provenance entry includes a timestamp | source (`contains 'datetime'`) | **PIN** — fold into A1.8's assertion on the produced string |

### A2. `test_startupStepAvailability.m` (1 case)

| # | Defect | Kind | Status |
|---|---|---|---|
| A2.1 | On a cold MATLAB the picker hid **32 of 54 installed steps**: `populateStepsTree` asks `availableSteps`, which probes `which()`, and nothing EEGLAB provides resolves until `eeglab()` has run its plugin scan — which `startupFcn` did not do. Pinned as `loadPrefs` < `initEeglab` < `populateStepsTree` ordering. | source | **PIN** — high value, and the plan's `eeglab_gui/` folder is where its two halves rejoin (see A3.x note) |

### A3. `test_windowClamp.m` (11 cases)

The window crept upward until it left the screen: `Position` measures `bottom` from the bottom of
the screen, so restoring width and height alone anchors the bottom-left corner and grows the window
*upward*, ratcheting over a stream of resize events.

| # | Defect | Kind | Status |
|---|---|---|---|
| A3.1 | `aWindowAlreadyBigEnoughIsUntouched` — an already-large-enough window must not have `Position` written at all, since a write re-fires the size-changed callback | pure | **PIN** |
| A3.2 | `exactlyAtTheMinimumIsUntouched` — the boundary | pure | **PIN** |
| A3.3 | `clampingHeightPinsTheTopEdge` — clamping height pushes the bottom DOWN, not the window up | pure | **PIN** — the regression itself |
| A3.4 | `clampingWidthDoesNotMoveTheWindow` | pure | **PIN** |
| A3.5 | `clampingBothDimensionsStillPinsTheTop` | pure | **PIN** |
| A3.6 | `repeatedClampingIsAFixedPoint` — applying the clamp to its own output changes nothing | pure | **PIN** — this is precisely what "creeping" was |
| A3.7 | `aStreamOfShrinksNeverLiftsTheWindow` — the original bug's exact shape | pure | **PIN** |
| A3.8 | `minSizeIsRespectedAsGiven` — the minimum is the caller's, not baked into the clamp | pure | **PIN** |
| A3.9 | `resizeHandlerGuardsReentry` — the clamp writes `Position`, which re-fires the callback, and the `drawnow` inside lets the re-entry run | source | **PIN** — behavioural in T6, not a source grep |
| A3.10 | `tabsAreExcludedFromRescaleByTypeNotByName` — a Tab's `Position` is read-only, and the exclusion used to be a hardcoded list of the four tabs that existed, so adding a fifth broke resizing | source | **PIN** — high value: the list-of-names failure mode recurs, and Stage 7 changed the tab set |
| A3.11 | `theAppDelegatesToTheClamp` — the arithmetic is not reinlined into the app | source | **DROP** — a guard against a refactor, not a defect. A3.1–A3.8 keep working wherever the arithmetic lives; if it were reinlined they would stop covering the app, which 5.2 reveals. |

**A3.1–A3.8 collapse to one `TestParameter` table** over `{w, h, minW, minH, expectedPosition}`:
eight cases for one rule on four numbers, and the single clearest instance of hand-unrolling in the
old suite. The two source checks (A3.9, A3.10) stay separate and become behavioural.

---

## B. Param-surface findings — `docs/param-audit-findings.md` (17, all DONE)

These are the "unreachable or wrong option" class. Every one reached a user as a step that silently
did the wrong thing, so they are the highest-value rows in the ledger.

| # | Defect | Fixed in | Status |
|---|---|---|---|
| B0 | **Quality Gate rank always sees full rank** — `rank(double(single_data))` upcasts float32 noise into a spurious dimension, so avg-ref data never fires the gate. *User-found; the audit missed it.* | `9774be4` | **PIN** — T3, and named in 5.2's minimum subset |
| B1 | CleanLine `chanlist` cleans the wrong set / crashes | `7549585` | **PIN** — T2, `cleanlineChanList` is pure |
| B2 | `tmslabel`/`pairlabel` silently ignored on casing | `3e17f7a` | **PIN** — T2, `renameVarinKeys` is pure |
| B3 | TEP Peak Output discards its result | `7640f2a` | **PIN** — T5 |
| B4 | `detrend` offers `polynomial`, which upstream rejects | `37a42ad` | **PIN** — T2, offered-values contract |
| B5 | SSP-SIR `PC` labelled inverse of its behaviour | `03f8188` | **DROP** — a description string. No test can tell a right description from a wrong one; this is review, not test. |
| B6 | `fromASR` always throws; DDWiener threshold 9-vs-20 | `be5320a` | **PIN** — T5 |
| B7 | `interpchan` offers a crashing `on` | `72fbadf` | **PIN** — T2 |
| B8 | `pop_rejcont` offers `sum`/`fill`/`hann`/`blackman`, none real | `974fbed` | **PIN** — T2, offered-values contract (one table with B4) |
| B9 | `pop_chanedit` lookup killed by argument order | `74cabf4` | **PIN** — T5 |
| B10 | `Choose Data Set` default `''` is type-invalid | `72fbadf` | **PIN** — T2 |
| B11 | Manual channel-removal index misalignment | `74cabf4` | **PIN** — T5 |
| B12 | `components` description inverts the behaviour | `03f8188` | **DROP** — description string, as B5 |
| B13 | `maxrej` documented as a fraction, consumed as a percent | `03f8188` | **DROP** — units in a description string, as B5 |
| B14 | Quality Gate QG-1…QG-4 | `90b8bf1` `86f2119` `a607928` | **PIN** — T3, the `qualityGate` threshold table |
| B15 | `Flag ICA` scalar threshold silently disables a class | `74cabf4` | **PIN** — T2, dispatch rejects a non-pair |
| B16 | `'off'` unreachable for 5 `clean_rawdata` criteria | `74cabf4` | **PIN** — T2, `convertParam` table; named in 5.2's minimum subset |
| B17 | Misleading descriptions (overwrite/plotag/state/epoch_len/cutEvent/tablePlot) | `9666095` | **DROP** — description strings, as B5 |

**Also recorded, not pinned:** the `[EXPOSE]` section (5 params de-registered because upstream
ignores them) is covered structurally by T2's offered-values contract — a de-registered param
cannot be offered. The `[UPSTREAM]` section (4 defects in EEGLAB/TESA itself) is explicitly
never-patch and gets no test; a test asserting a dependency's bug is the thing this rewrite is
deleting `test_pipeline_integration.m` for.

---

## C. Defects fixed today, before the rewrite was scoped

Not in either source above, and all four are the wrong-number-on-a-figure class this suite exists
for. Listed because 5.2 names them in its minimum replay subset.

| # | Defect | Fixed in | Status |
|---|---|---|---|
| C1 | Scalp map: unticking a **derived** default left `0 0` in the fields, and `[0 0]` sits inside the epoch, so the map silently averaged the single sample at t=0 with nothing on screen to say so | `3fef194` | **PIN** — T2, `paramForm` unset-stays-unset |
| C2 | `drawWindowBars` kept its own literal `0.95`, independent of `res.info.level`, so it agreed with the reported level only by coincidence | `b98be25` | **PIN** — T1, asserted against a *doctored* `res.info.level` — the only way to tell "reads it" from "agrees with it" |
| C3 | Three drifted copies of one enum comparison: two stripped only spaces, one stripped hyphens too, so `'per-map'` was silently ignored in two of three drawers | `b98be25` | **PIN** — T1, `matchesChoice` |
| C4 | A shared colour bar could be hung over maps that no longer share a scale, stating a voltage that means something else in the map beside it | `40ea5fa` | **PIN** — T1, `topoColourScale` returns empty for per-map |
| C5 | `runPipelineCore` had an `outputRoot` override but not its twin `layout`, so a test that isolated one inherited the user's pref for the other and failed five ways | `2d35206` | **PIN** — T3, `outputPaths` both layouts |

---

## Tally

| | count |
|---|---|
| rows total | **44** — 22 regression cases + 17 param findings + 5 fixed today |
| **PIN** — the new suite must catch these | **37** |
| **DROP** — with a stated reason | **7** — 4 description strings (B5, B12, B13, B17), 2 refactor/existence guards (A1.9, A3.11), 1 wording-only (B5 group) |
| **OBSOLETE** — code since deleted | 0 |

Note the DROP reasons cluster: **four of the seventeen param findings were wrong description
strings**, and no test can tell a right description from a wrong one — that is review, not testing.
Attempting to pin them is how a suite acquires assertions that fail on rewording and catch nothing.

37 pinned defects against a ~180-case target is a healthy ratio: roughly one case in five exists
because something actually broke once, and the rest cover invariants that have not broken yet but
would be silent if they did.

---

## Progress — which rows are now pinned

The new suite as it stands: **pure 151 · gui 17 · eeglab 12+** across 10 files.

| Ledger row | Pinned by |
|---|---|
| A1.1 Save New Set discarded the renamed filename | *not yet* — T5 |
| A1.2/A1.3 `input()` blocking a batch | `DispatchContractTest/noStepFlaggedNonInteractiveOpensADialog` |
| A1.4 methods text claimed full retention | `ReportOutputTest/theMethodsTextDisclosesWhatWasRemovedAndInterpolated` |
| A1.5 `assignin('base',…)` leaking pipeline vars | *not yet* — T5 |
| A1.6 circular dependency back into the app class | *not yet* — T5 |
| A1.7 `uisave` never cleared pipelineDirty | *not yet* — T6 |
| A1.8/A1.10 EEG.history provenance + timestamp | *not yet* — T5 |
| A2.1 cold-start hid 32 of 54 steps | *not yet* — T6 (`eeglab_gui`) |
| A3.1–A3.8 the window clamp, as one table | *not yet* — T6 |
| A3.9 resize re-entrancy guard | *not yet* — T6 |
| A3.10 tabs excluded by TYPE not by name | *not yet* — T6 |
| B0 rank always saw full rank | `QualityGateTest/rankIsComputedAtTheDataOwnPrecision` |
| B1 CleanLine cleaned the wrong channels | `ParamConversionTest/theCleanlineRangeBecomesExplicitIndices…` |
| B2 tmslabel/pairlabel dropped on casing | `ParamConversionTest/aRenamedKeyKeepsItsValueAndItsPlace` |
| B3 TEP Peak Output discarded its result | `StepGoldenTest` (TEP Peak Output golden) |
| B4/B7/B8 steps offering values upstream rejects | `RegistryContractTest`, three negative pins + a positive control |
| B6 fromASR / DDWiener threshold | `StepGoldenTest` + `DispatchContractTest` |
| B9/B11/B15 dispatch argument handling | `DispatchContractTest/everyOfferedStepReachesAnImplementation` |
| B10 numeric param defaulting to empty text | `RegistryContractTest/noStepDeclaresAnEmptyStringAsAScalarDefault` |
| B14 Quality Gate QG-1…QG-4 | `QualityGateTest`, two rule tables |
| B16 `'off'` unreachable for 5 criteria | `ParamConversionTest/offReachesEveryCriterionThatAcceptsIt` |
| C1 derived default reported 0 | `ParamFormTest/unTickingADerivedDefaultStatesNothing` |
| C2 Window bars read a literal level | `IntervalTest` + `CohortCurvesTest/theLevelUsedIsRecordedOnTheResult` |
| C3 three drifted enum comparisons | `ParamConversionTest` (via `matchesChoice`) |
| C4 shared colour bar over unshared scales | `FigureScaleTest/anEmptySharedLimitIsTheContract…` |
| C5 `opts.layout` override | `DispatchContractTest/theLayoutOverrideBeatsTheUserPreference` |

**23 of 37 PIN rows are pinned.** The remainder are T5/T6 — source-check
regressions that become behavioural, and the GUI rows.

### Vacuous tests caught while writing these

Three, all mine, all found by asking whether a passing test *could* fail:

1. `stepOffers` named a step that does not exist (`'Reject Continuous Data'`
   for what is really `'Automatic Continuous Rejection'`), so four B8
   assertions passed while asserting nothing. Fixed by making a missing step an
   assertion failure, plus a positive control.
2. `everyTestClassInheritsTheBase` resolved classes by reflection and silently
   reported every file outside the running folder as non-inheriting.
3. `everyOfferedStepReachesAnImplementation` tested for `nestapp:unknownStep`,
   which `processOneFile` never raises — it rethrows as `nestapp:stepFailed`.
   The coverage check would have passed for a registry in which *every* step
   was unimplemented.

The third is the one worth remembering: it is exactly the failure mode this
rewrite exists to remove, written fresh, and only the habit of asking for a
positive control caught it.

---

## Open item

`docs/param-audit-findings.md` rows B5, B12, B13 and B17 are all "the description string is wrong".
Eight of the 17 findings in that audit were wording, not behaviour — worth knowing when judging
whether the param surface is in good shape, and worth *not* attempting to test.
