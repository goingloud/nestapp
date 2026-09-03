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
         EEGLAB / TESA / plugins / vendored AARATEP helpers
```

The same `spec` (a struct array of `{name, params}`) drives both the GUI run
button and headless callers like `runPipelineCore` and the test suite.

## Module map (`src/`)

**The folders are the map.** `src/` used to hold 146 loose `.m` files, so this
section was a hand-maintained table of individual filenames - which drifted:
it listed `artist*.m` and `templateCitation.m`, neither of which exists. A
folder is checkable by `ls`, so a new file lands in a documented area by
construction rather than by someone remembering to add a row here.

| Folder | Responsibility |
|---|---|
| `@nestapp/` | The App Designer class. `nestapp.m` holds all state, callbacks and tab logic; `createComponents`/`rescaleComponents` build and lay out the UI. **Edit `nestapp.m` directly — there is no `.mlapp`.** |
| `registry/` | The catalogue: what steps and plots exist, their params and defaults, their dependency requirements, and what is available on this machine. The single source of truth for "what steps exist". |
| `params/` | Turning registry params into what an EEGLAB call wants, and back: type conversion, name/value assembly, key renaming, enable/disable rules, and the parameter form. |
| `plot/` | Everything that draws: the `draw*` functions, colour scales, shared colour bars, publication figure sizing, and the plot-options dialogs. |
| `analysis/` | Explore's arithmetic: group curves, confidence intervals, window measures, TEP peaks, and the cohort/subject bookkeeping behind *n*. |
| `roi/` | Region-of-interest selection, presets, montage layout, and channel/electrode validation. |
| `ica/` | ICA engines, component classification and marking, activation, and rank/variance decisions. |
| `report/` | Per-file reports, methods prose, citations, provenance strings, and failure summaries. |
| `qa/` | Quality Gate scoring, batch verdicts, QC images, attribute matrices. |
| `io/` | Output-path layout and results-root resolution. |
| `env/` | The environment: bringing EEGLAB and plugins up, plugin versions, the AARATEP pin/installer, logging, and `nestappDoctor`. |
| `util/` | Small shared helpers with no domain of their own, plus `buildTemplates`. |
| `aaratep_compat/` | Shims for the vendored AARATEP tree. |
| `templates/` | Built-in pipelines as `.mat` — **generated artifacts** (see gotchas); `util/buildTemplates.m` is the source. |

Four files stay at `src/` root because they are entry points or cross-cutting,
not members of an area:

| File | |
|---|---|
| `runPipelineCore.m` | the batch engine (serial / parallel) |
| `processOneFile.m` | the per-file dispatch `switch` |
| `nestappVersion.m` | single source of truth for the version (SemVer) |
| `nestappRoot.m` | resolves the install root by walking up to `run_nestapp.m`, so nothing else has to know its own depth in the tree |

`src/` and every subfolder go on the path via `genpath` (`run_nestapp.m`,
`addNestappPath` in the tests, and the packaged toolbox all do this), so a
function's folder never affects whether it resolves.

## "If you want to change X, edit Y"

| Goal | Where | Notes |
|---|---|---|
| Add a processing step | `registry/stepRegistry.m` (register) + `processOneFile.m` (dispatch `case`) | Recipe in [CONTRIBUTING.md](../.github/CONTRIBUTING.md#adding-a-pipeline-step). |
| Change/add a built-in template | `util/buildTemplates.m`, then run `buildTemplates()` and commit the regenerated `templates/*.mat` | The `.mat` is generated — never edit it directly. |
| Add a citation for a template | `registry/stepCitations.m` | Logged per run by `runPipelineCore.m`. |
| Change a Quality Gate metric | `qa/qualityGate.m` (+ `qa/aggregateGateVerdicts.m` for batch mode) | Step params live in `registry/stepRegistry.m`. |
| Change TEP peak detection | `analysis/tepPeakFinder.m` (TESA detection) / `analysis/computeWindowMeasures.m` (mean, area, fallback peak) | Explore's results table prefers `tepPeakFinder` so it agrees with what an overlay would draw, and falls back to `computeWindowMeasures` when TESA is absent. |
| Change a tab's UI/behaviour | `@nestapp/nestapp.m` (callbacks) + `@nestapp/createComponents.m` (layout) | Plain-text class; diffable. |
| Change report contents | `report/buildReportText.m`, `report/initPipelineReport.m` | |
| Bump the version | `nestappVersion.m` + `CHANGELOG.md` + `CITATION.cff` (+ git tag) | `tests/pure/VersionTest.m` keeps them in sync, including the README badge. |
| Add an environment/diagnostic check | `env/nestappDoctor.m` (`diagnose` + collectors) | Surfaced via Help → Check My Install; dependency list derives from `registry/stepRegistry`. |

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
