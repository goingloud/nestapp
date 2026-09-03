# nestapp

![version](https://img.shields.io/badge/version-1.0.0-blue)
![MATLAB](https://img.shields.io/badge/MATLAB-R2023b%2B-orange)
![license](https://img.shields.io/badge/license-GPL--3.0-green)

**nestapp** is a MATLAB app for cleaning and analysing TMS-EEG recordings. It wraps [EEGLAB](https://eeglab.org/), [TESA](https://nigelrogasch.gitbook.io/tesa-user-manual/) and the surrounding plugin stack in a point-and-click pipeline builder, so a researcher can preprocess a cohort, check what happened to every file, and get publication-ready TEP figures and peak measurements without writing code.

Three tabs, in the order you use them:

- **Cleaning** — build a preprocessing pipeline (or load a published one as a template) and run it over a batch of files.
- **Reports** — see what the run did to each file: channels dropped, trials kept, ICA components removed, and a methods paragraph you can paste into a manuscript.
- **Explore** — the comparison most TMS-EEG studies are designed around: pre versus post, or one cohort against another, with TEP waveforms, topographies, and per-window measures exported to CSV.

Every processed file carries its full pipeline — steps, parameters, timestamp — inside `EEG.history` in the saved `.set`, so a result can always be traced back to how it was made.

---

## Requirements

| | Version | How you get it |
|---|---|---|
| MATLAB | R2023b or later | — |
| Signal Processing Toolbox | any recent | MATLAB installer |
| Statistics and Machine Learning Toolbox | any recent | MATLAB installer |
| EEGLAB | 2026.0.0 (2025.x works) | [eeglab.org](https://eeglab.org/) — unzip anywhere |
| TESA | 1.2 or later | EEGLAB → **File → Manage EEGLAB extensions** |
| FastICA, ICLabel, PICARD, CleanLine, clean_rawdata, firfilt | any recent | same extension manager |

**Only needed for specific steps:**

| | Needed for |
|---|---|
| Curve Fitting Toolbox | the `Remove Decay Artifact` step (AARATEP template) |
| `bva-io`, `loadcnt`, `curry` | reading BrainVision `.vhdr`, Neuroscan `.cnt`, Curry `.cdt` |
| [AARATEP helpers](https://github.com/chriscline/AARATEPPipeline) | the AARATEP template — see [installing AARATEP](#installing-the-aaratep-helpers) |

nestapp only ever *offers* a step whose dependencies are actually installed, and the pre-flight check blocks a run that references a missing one and tells you what to install. You do not have to get this list right up front.

---

## Installation

1. **Install EEGLAB** — download from [eeglab.org](https://eeglab.org/) and unzip anywhere on your machine.
2. **Install the plugins** — launch EEGLAB (`eeglab` at the MATLAB prompt), open **File → Manage EEGLAB extensions**, and install TESA, FastICA, ICLabel, PICARD, CleanLine, clean_rawdata and firfilt. They install into EEGLAB's own `plugins/` folder; nothing else needs adding to your path.
3. **Download nestapp** — clone this repository, or use **Code → Download ZIP** on GitHub and unzip it.
4. **Launch it** — open MATLAB, `cd` to the nestapp folder, and run:
   ```matlab
   run_nestapp
   ```
5. **Point nestapp at EEGLAB** — open **Settings → Preferences** and set the EEGLAB installation folder. nestapp adds EEGLAB and its plugins to the MATLAB path on every launch from then on.

That is the whole setup. If a step you want is greyed out, or the app reports something missing, run:

```matlab
nestappDoctor
```

which reports your MATLAB version, which plugins it can find, their versions, and what any unavailable step is waiting for.

### Installing the AARATEP helpers

The AARATEP pipeline's helper functions are not redistributable with this repository. From the nestapp folder:

```bash
cd third_party
git clone --depth 1 https://github.com/chriscline/AARATEPPipeline.git aaratep
```

nestapp puts this tree on the path automatically when an AARATEP step runs. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the pinned commit and licensing.

---

## First run

1. **File → Load Template** and pick a published pipeline, or build one in the **Cleaning** tab.
2. **File → Open Data...** to choose files (`.set`, `.vhdr`, `.cnt`, `.cdt`).
3. **Run Analysis**. A progress dialog names the current file and step, and the run can be cancelled between steps.
4. The **Reports** tab opens with a per-file summary. Copy the methods paragraph, or export the batch as CSV.
5. Load the cleaned files in the **Explore** tab to compare conditions, then export a figure or the per-subject measures.

| Template | Pipeline | Cite |
|---|---|---|
| TMS-EEG / TEP (TESA) | TESA two-round ICA for single-pulse TMS | Rogasch et al. 2017, *NeuroImage* 147:934-951 |
| TMS-EEG / AARATEP | SOUND + decay-fit removal + AR-blend interpolation + TMS-aware muscle classifier | Cline et al. 2021, *IEEE NER* |
| Resting-State EEG | PREP + Delorme cleaning with ICLabel | Delorme 2023, *Sci Rep* 13:2372 |
| Minimal ERP | High-pass + bad channels + ICA, minimum-handling | Delorme 2023 |

Each template logs its own citation and DOI at the start of every batch run, so the reference lands in the run log beside the data.

---

## Documentation

| | |
|---|---|
| [**User guide**](docs/user-guide.md) | Every tab, control and export route in detail |
| [Architecture](docs/architecture.md) | How the code is laid out and where to change things |
| [Contributing](.github/CONTRIBUTING.md) | Development setup, the test suite, adding a pipeline step |
| [Style guide](docs/STYLE.md) | Code and test conventions |
| [Changelog](CHANGELOG.md) | What changed, and when |
| [Third-party notices](THIRD_PARTY_NOTICES.md) | Attribution for every bundled and vendored dependency |

---

## Citing

If you use nestapp in published work, cite it with the metadata in [`CITATION.cff`](CITATION.cff) — GitHub's **Cite this repository** button generates APA and BibTeX for you.

**Also cite the pipeline paper for whichever template you ran**, from the table above. nestapp writes these into the run log so the reference is recorded with the data rather than reconstructed later.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](.github/CONTRIBUTING.md). New to the codebase? [`docs/architecture.md`](docs/architecture.md) is the map.

## Authors

**Aref Pariz** — original application (2023), developed at the Royal Institute for Mental Health in Dr. Sara Tremblay's lab ([NESTLAB](https://www.nest-lab.ca/)) and Dr. Jeremie Lefebvre's lab, University of Ottawa.

**Wesley Dunne** — pipeline engine, progress reporting and provenance, automated reports with ICA tracking, TEP visualisation and batch peak extraction, pipeline templates, quality-control gates, and test suite. Led the 1.0.0 open-source release.

## License

GPL-3.0-or-later. See [`LICENSE`](LICENSE).
