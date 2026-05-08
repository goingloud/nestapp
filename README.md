# nestapp

**nestapp** is a MATLAB GUI for cleaning and analysing TMS-EEG recordings. It wraps [EEGLAB](https://eeglab.org/), [TESA](https://nigelrogasch.gitbook.io/tesa-user-manual/), and [FastICA](http://research.ics.aalto.fi/ica/fastica/) into a point-and-click pipeline builder that lets researchers process data without writing code.

---

## Requirements

| Dependency | Version |
|---|---|
| MATLAB | R2023b or later (developed on R2025b) |
| EEGLAB | 2025.0.0 |
| TESA | 1.1.1 |
| FastICA | 2.5 |
| Signal Processing Toolbox | any recent |
| Statistics and Machine Learning Toolbox | any recent |

FastICA must be on your MATLAB path before running the app.

---

## Getting started

1. Clone or download this repository.
2. Open MATLAB and navigate to the project root.
3. Run the entry point:
   ```matlab
   run_nestapp
   ```
4. The first time you run, open **Settings → Preferences** and point the app to your EEGLAB installation folder.

---

## Cleaning tab

### Building a pipeline

- The left panel lists all available processing steps. Click a step to see a description and parameter details in the **Info** panel.
- Use **Add** (or double-click a step) to append it to the **Selected Steps** list.
- Use **Remove**, **Move Up**, and **Move Down** to edit the order.
- Click any step in **Selected Steps** to view and edit its parameters in the table below. **Default Value** resets parameters for that step.
- **Re/Start Steps** clears the pipeline after a confirmation prompt.

### Pipeline templates

**File → Load Template** provides three ready-to-use starting points:

| Template | Description |
|---|---|
| TMS-EEG (TESA) | Full TESA artifact-removal workflow for single-pulse TMS |
| Resting-State EEG | Standard resting-state cleaning with ICA |
| Minimal (HPF + bad channels) | High-pass filter and bad channel removal only |

### Saving and loading pipelines

- **File → Save Pipeline** saves the current step list and parameters as a `.mat` file.
- **File → Load Pipeline** restores a previously saved pipeline.
- Recent pipelines are listed under **File → Recent Pipelines**.

### Running the pipeline

1. Select the data files to process (`.set`, `.vhdr`, `.cnt`, `.cdt`).
2. Press **Run Analysis**. A progress dialog shows the current file and step; processing can be cancelled between steps.

After the run, the **Reports tab** opens automatically with a per-file summary including channel counts, trial retention, and ICA statistics.

### Pipeline provenance in EEG.history

Every processed file has the pipeline steps and parameters written into `EEG.history`, so the full processing record is visible when a researcher types `EEG` at the MATLAB prompt and is preserved inside the saved `.set` file.

---

## Visualizing tab

- Select one or more processed `.set` files.
- Click electrode buttons to define the region of interest (ROI).
- **PLOT TEP** plots the trial-averaged waveform with a shaded SEM band. Multiple files can be overlaid on the same axes.
- **Show Components** detects and overlays the six canonical TEP components (N15, P30, N45, P60, N100, P180) with latency and amplitude labels.
- **TOPOPLOT** plots the scalp topography at a selected time point and window.
- **Export TEP Figure** saves the current plot as PNG, PDF, or `.fig`.
- The **TEP Window** slider sets the time range shown in the plot.

---

## Reports tab

After each pipeline run, a summary report is added to the **Reports** tab. Reports can be browsed, copied as methods text, and exported as CSV for multi-subject summaries.

---

## Preferences

Open **Settings → Preferences** to configure:

- EEGLAB installation path
- Default data and pipeline folders
- Whether to show the Reports tab automatically after each run
- Whether to require confirmation before clearing a pipeline

---

## Running the test suite

```matlab
% Unit and regression tests (no EEGLAB required, < 1 minute):
run_nestapp       % ensures src/ is on the path
runtests('tests/unit')
runtests('tests/regression')

% Or use the bundled runner:
run_tests         % unit + regression
run_tests('all')  % includes integration tests (requires EEGLAB)
```

---

## Contributors

**Aref Pariz** — original application (v1.0, 2023), developed at the Royal Institute for Mental Health in Dr. Sara Tremblay's lab ([NESTLAB](https://www.nest-lab.ca/)) and Dr. Jeremie Lefebvre's Lab, University of Ottawa.

**Wesley Dunne** — v2.0 enhancements: pipeline architecture, progress reporting, ICA tracking, pipeline reports, TEP visualisation improvements, pipeline templates, UI improvements, test suite.
