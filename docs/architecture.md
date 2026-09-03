# nestapp architecture

For what the app does from a user's side, see the [user guide](user-guide.md);
for setup, the [README](../README.md).

A map of how nestapp is put together and **where to make common changes**.
For the per-function contract of any file, see the generated
[API reference](../site/index.md) (built from the source header comments by
`tools/gen_docs.m`).

## Big picture

nestapp has two halves that share one engine:

```
            ┌─────────────────────────────┐
   GUI ───► │  src/@nestapp/nestapp.m      │   three tabs:
            │  (App Designer class, plain  │   Cleaning · Reports ·
            │   text — edit directly)      │   Explore
            └──────────────┬──────────────┘
                           │ builds a pipeline "spec" (ordered steps + params)
                           ▼
            ┌─────────────────────────────┐
   headless │  src/runPipelineCore.m       │   batch engine (serial / parallel)
   callers  │      └─► src/processOneFile.m│   runs one file through the spec
   (tests,  └──────────────┬──────────────┘
   scripts)                │ switch over step name → EEGLAB / TESA / helpers
                           ▼
                 EEGLAB / TESA / FastICA / vendored AARATEP
```

The same `spec` (a struct array of `{name, params}`) drives both the GUI run
button and headless callers like `runPipelineCore` and the test suite.

## Module map (`src/`)

| Area | Files | Responsibility |
|---|---|---|
| **GUI** | `@nestapp/nestapp.m`, `@nestapp/createComponents.m`, `@nestapp/rescaleComponents.m` | The App Designer class. `nestapp.m` holds all state, callbacks, and tab logic. `createComponents`/`rescaleComponents` build and lay out the UI. **Edit `nestapp.m` directly — never the `.mlapp`.** |
| **Step registry** | `stepRegistry.m`, `makePipelineStep.m`, `checkStepDependencies.m` | The catalogue of pipeline steps: each step's name, default params, UI metadata, and dependency requirements. The single source of truth for "what steps exist." |
| **Execution** | `runPipelineCore.m`, `processOneFile.m`, `paramsToVarin.m`, `varinToStruct.m`, `stripVarinKeys.m`, `stripEmptyVarin.m`, `nestLog.m` | The batch engine and the per-file dispatch `switch`. Each step name maps to an EEGLAB/TESA call or a nestapp helper here. |
| **Templates** | `buildTemplates.m`, `templates/*.mat`, `templateCitation.m`, `specFromSaved.m` | Built-in pipelines. `buildTemplates.m` is the source; the `.mat` files are **generated artifacts** (see gotchas). |
| **Step helpers** | `aaratepMuscleClassifier.m`, `artist*.m`, `ensureAaratepOnPath.m`, `computeICAActivation.m`, `tepPeakFinder.m`, `tepFieldCurve.m`, `tepWindowTable.m`, `computeWindowMeasures.m`, `defaultTEPComponentDefs.m` | Algorithm implementations behind specific steps and analyses. |
| **Quality control** | `qa/*.m` | Quality Gate scoring, batch verdicts, QC images, dashboard, attribute matrices. |
| **Reporting / IO** | `buildReportText.m`, `initPipelineReport.m`, `exportReport.m`, `summarizeReports.m`, `buildHistoryEntry.m`, `io/*.m` | Per-file reports, methods paragraphs, provenance, and output-path layout. |
| **Version** | `nestappVersion.m` | Single source of truth for the app version (SemVer). |
| **Diagnostics** | `nestappDoctor.m`, `describePipeline.m`, `nestDebugLog.m`, `saveErrorBundle.m`, `collectSupportBundle.m` | `nestappDoctor` validates the environment (Help → Copy Diagnostics); `describePipeline` renders the current pipeline (File → Copy Pipeline Description); `nestDebugLog` tees the run trace to a file when the `debugLog` pref is on; `saveErrorBundle` writes a metadata-only bundle on a step failure; `collectSupportBundle` is the on-demand version (Help → Collect Support Bundle). |

## "If you want to change X, edit Y"

| Goal | Where | Notes |
|---|---|---|
| Add a processing step | `stepRegistry.m` (register) + `processOneFile.m` (dispatch `case`) | Recipe in [CONTRIBUTING.md](../.github/CONTRIBUTING.md#adding-a-pipeline-step). |
| Change/add a built-in template | `buildTemplates.m`, then run `buildTemplates()` and commit the regenerated `templates/*.mat` | The `.mat` is generated — never edit it directly. |
| Add a citation for a template | `templateCitation.m` | Logged per run by `runPipelineCore.m`. |
| Change a Quality Gate metric | `qa/qualityGate.m` (+ `qa/finalizeBatchVerdicts.m` for batch mode) | Step params live in `stepRegistry.m`. |
| Change TEP peak detection | `tepPeakFinder.m` (TESA detection) / `computeWindowMeasures.m` (mean, area, fallback peak) | Explore's results table prefers `tepPeakFinder` so it agrees with what an overlay would draw, and falls back to `computeWindowMeasures` when TESA is absent. |
| Change a tab's UI/behaviour | `@nestapp/nestapp.m` (callbacks) + `@nestapp/createComponents.m` (layout) | Plain-text class; diffable. |
| Change report contents | `buildReportText.m`, `initPipelineReport.m` | |
| Bump the version | `nestappVersion.m` + `CHANGELOG.md` (+ git tag) | A CI check keeps the three in sync. |
| Add an environment/diagnostic check | `nestappDoctor.m` (`diagnose` + collectors) | Surfaced via Help → Copy Diagnostics; dependency list derives from `stepRegistry`. |

## Data flow of a run

1. The GUI (or a headless caller) assembles a `spec`: an ordered struct array
   of `{name, params}` (`makePipelineStep` builds each from the registry).
2. `runPipelineCore(spec, files, opts)` sets up output paths, logging,
   citations, and serial/parallel execution.
3. For each file, `processOneFile` walks the spec; its `switch` maps every
   step `name` to its implementation (mostly `pop_*` EEGLAB/TESA calls, plus
   nestapp helpers). EEGLAB state lives in globals reset per worker.
4. Quality Gates score the data at checkpoints; reports and QC images are
   written; provenance is appended to `EEG.history`.

## Gotchas (also in CONTRIBUTING)

- **Generated templates.** `templates/*.mat` come from `buildTemplates()`.
- **Allowlist `.gitignore`.** New files in new dirs are invisible to git until
  allowlisted.
- **`nestapp.m`, not the `.mlapp`.** The `.mlapp` would overwrite hand edits.
- **EEGLAB and `third_party/` are not committed** — external dependencies.
- **`processOneFile` uses EEGLAB globals** (`EEG`, `ALLEEG`, …); headless
  callers should expect shared state to be reset per worker.

## Headless API

The GUI is one caller, not the interface. Everything the Explore tab does is a
pure function it calls, and each is usable from a script or a batch with no
figure on screen - which is what makes the analysis reproducible from code
rather than from a sequence of clicks.

| Function | Takes | Gives back |
|---|---|---|
| `exploreDataset(paths, rules, opts)` | file paths | one entry per file: `.path .subject .group .subjectConfident` |
| `loadReducedSets(paths, opts)` | file paths | per-file cache: `.trialAvg .labels .chanlocs .time .nTrials` - trial averages, not epochs (~800 kB/file) |
| `groupCurves(cache, entries, opts)` | the two above | `res`: group means, per-subject `.curves`, per-file `.files`, intervals, montage report |
| `curveInterval(curvesByGroup, design, level)` | subject x time per group | mean, CI, SEM, n, df - paired (Cousineau-Morey) or unpaired |
| `exploreMeasures(res, windows)` | a `res` | one table row per subject x group x window |
| `exploreResults(res, entries, opts)` | a `res` | the complete saved-analysis struct |
| `computeWindowMeasures(curve, t, t1, t2, polarity)` | one curve | mean, area, peak latency/amplitude for one window |
| `drawTEPOverlay` / `drawTEPTopo` / `drawGroupTopo` / `drawWindowBars` | axes (or a panel) + a `res` | the figure content, into axes the caller mints |

Two conventions make these safe to call without a display:

- **The caller mints the axes.** No drawing function creates a figure, so the
  same code renders into a `uiaxes` on screen and a classic `axes` bound for
  `print`. Every MATLAB export path silently omits UI components, which is why
  the export path passes an `axesFcn` that makes classic axes.
- **`nestapp.loadAnalysis(app, file)`** reopens a saved Results `.mat` without
  a dialog, so a batch can restore groups, subjects, ROI, windows, design and
  plot selection and carry on.

`runPipelineCore(spec, filePaths, opts)` is the equivalent for cleaning: the
same `spec` the GUI builds, driven from a script.

## Tests

`tests/run_tests.m` is the harness. Suites are FOLDERS, encoding the two
things that actually gate a test - EEGLAB and a display - as a cross-product:
`pure/` (neither, ~4 s), `eeglab/` (EEGLAB, includes the step goldens),
`gui/` (a display), `eeglab_gui/` (both). `run_tests('all')` runs the lot in
~40 s.

Three rules: a skip is a failure (there are zero `assumeFail` sites - the
folder already declares what a test needs), an empty or missing suite is a
failure, and the path is restored on exit.

The conventions are executable rather than documented: `tests/pure/SuiteHygieneTest.m`
holds nine of them, including that every test sits in the folder its
dependencies require, that no test rolls its own path setup or temp dir, that
source-scraping is opt-in with a named exception list, and that every helper
in `tests/helpers/` has a caller. `tests/golden/` holds the 10 step
characterization recordings; re-recording one is a decision, not a chore - see
`tests/recordGoldens.m`.
