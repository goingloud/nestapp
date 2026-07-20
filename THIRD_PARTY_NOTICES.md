# Third-Party Notices

nestapp ships built-in templates that wrap or vendor code from external research projects. This file enumerates those dependencies, their licenses, and what was copied.

When you publish results produced with one of nestapp's built-in templates, cite the corresponding paper from the table in [`README.md`](README.md#citing-nestapp). The citation is also printed to the batch log on every run (see `stepCitations.m`).

## Pipeline-defining packages

These external packages each define the algorithm and parameters of a built-in nestapp template. They are treated as first-class citations: every batch run that uses one of these templates logs the citation at the start of the run, and every publication that uses one of these templates must cite the corresponding paper.

### TESA (TMS-EEG Signal Analyser)

- **Templates that use it:** `TMS-EEG / TEP (TESA)`, *plus most steps of* `TMS-EEG / AARATEP`.
- **Upstream:** https://nigelrogasch.github.io/TESA/ — code at https://github.com/nigelrogasch/TESA
- **License:** GPL-3.0
- **Installed via:** EEGLAB Plugin Manager (bundled with nestapp under `eeglab2026.0.0/plugins/`); not vendored under `third_party/`.
- **What nestapp uses:** `pop_tesa_findpulse` (TMS pulse detection), `pop_tesa_removedata` (artifact removal), `pop_tesa_interpdata` (cubic interpolation), `pop_tesa_filtbutter` (zero-phase Butterworth filtering, also used for the 60 Hz notch in the AARATEP template), `pop_tesa_fastica` (FastICA wrapper), `pop_tesa_compselect` (six-detector TMS-EEG IC classifier), `pop_tesa_sound` (SOUND algorithm wrapper, used by AARATEP template), `pop_tesa_sspsir` (SSP-SIR), `pop_tesa_peakanalysis`/`pop_tesa_peakoutput` (TEP peak extraction).
- **Template design provenance:** the `TMS-EEG / TEP (TESA)` template's step order is annotated against specific steps of the TESA User Manual (Rogasch's published preprocessing recipe) — see `src/buildTemplates.m` lines 19–79 for the manual-step cross-references.
- **Cite as:** Rogasch N.C., Sullivan C., Thomson R.H., Rose N.S., Bailey N.W., Fitzgerald P.B., Farzan F., Hernandez-Pavon J.C. (2017). Analysing concurrent transcranial magnetic stimulation and electroencephalographic data: a review and introduction to the open-source TESA software. *NeuroImage* 147:934-951. doi:[10.1016/j.neuroimage.2017.06.014](https://doi.org/10.1016/j.neuroimage.2017.06.014)
- **Additional citation for SOUND:** Mutanen T.P., Metsomaa J., Liljander S., Ilmoniemi R.J. (2018). Automatic and robust noise suppression in EEG and MEG: The SOUND algorithm. *NeuroImage* 166:135-151. doi:[10.1016/j.neuroimage.2017.10.021](https://doi.org/10.1016/j.neuroimage.2017.10.021) — cite this *in addition to* the TESA paper whenever your pipeline includes a SOUND step — `Source-Informed Sensor Cleaning (SOUND)` or `SOUND (AARATEP)` (the latter is used by the `TMS-EEG / AARATEP` template).

## Vendored code (copies under `third_party/`)

### AARATEPPipeline

- **Path in this repo:** `third_party/aaratep/`
- **Upstream:** https://github.com/chriscline/AARATEPPipeline
- **Pinned commit:** `be75262af689d4e8e5053c05aaa4ed3be258350a` (2025-08-29)
- **License:** MIT (see `third_party/aaratep/LICENSE`)
- **Copyright:** © 2021 Chris Cline
- **What was copied:** the entire repository at the pinned commit, including the `Common/` subtree (~280 files). Nothing was modified in place.
- **What invokes it:** dispatch cases in `src/processOneFile.m` call `c_TMSEEG_fitAndRemoveDecayArtifact` and `c_EEG_ReplaceEpochTimeSegment` directly. `src/ensureAaratepOnPath.m` adds the vendored tree to the MATLAB path on first call.
- **Bundled forks kept off the path:** `Common/ThirdParty/FromEEGLab` (forked EEGLAB functions) and `Common/ThirdParty/FastICA` are excluded so they cannot shadow the user's own EEGLAB/FastICA. The bundled FastICA is added back only as a fallback when no other FastICA is present, and a `nestapp:aaratepFastICAMismatch` warning is printed if the user's FastICA version differs from the bundled (tested) one.
- **Derivative work:** `src/aaratepMuscleClassifier.m` ports a 12-line block from `c_TMSEEG_Preprocess_AARATEPPipeline.m` (lines 400-412) under the same MIT license. The header comment in `aaratepMuscleClassifier.m` credits the origin.
- **Cite as:** Cline C.C. et al. (2021). Advanced Artifact Removal for Automated TMS-EEG Data Processing. *IEEE NER*. doi:[10.1109/NER49283.2021.9441147](https://doi.org/10.1109/NER49283.2021.9441147)

## Template fidelity notes

### AARATEP template fidelity gaps

The `TMS-EEG / AARATEP` template is a faithful reproduction of
`c_TMSEEG_Preprocess_AARATEPPipeline.m` (v2.1.1). Only a few dedicated steps
were added (an AR-extrapolation high-pass and two atomic bad-channel detectors);
everything else reuses shared steps, so we avoid steps over-fit to one pipeline.

| Stage | nestapp step | Vendored helper |
|---|---|---|
| Modified high-pass (AR-extrapolation) | **`Modified Bandpass Filter (AARATEP)`** (new) | `c_TMSEEG_applyModifiedBandpassFilter` |
| Bad-channel detection (PREP deviation) | **`Detect Bad Channels (PREP deviation)`** (new) | `c_TMSEEG_detectBadChannels` |
| Bad-channel detection (DDWiener) | **`Detect Bad Channels (DDWiener)`** (new) | `c_TMSEEG_detectBadChannels` |
| SOUND with bad-channel reconstruction | `Source-Informed Sensor Cleaning (SOUND)` (shared, `reconstructBadChannels = on`) | `c_TMSEEG_runSOUND` (`replaceChannels`) |
| Line-noise bandstop + final low-pass | `Frequency Filter (TESA)` (shared) | `pop_tesa_filtbutter` (same zero-phase Butterworth as `c_EEG_filter_butterworth`) |
| AR-Blend interp, decay fit/remove, TMS-muscle IC scorer | `Interpolate Missing Data (AR-Blend)`, `Remove Decay Artifact`, `Flag ICA Components (AARATEP Muscle)` | `c_EEG_ReplaceEpochTimeSegment`, `c_TMSEEG_fitAndRemoveDecayArtifact`, `aaratepMuscleClassifier` |

The two detectors each interpolate flagged channels **in place** (spherical
spline) and accumulate their labels in `EEG.etc.aaratepBadChannels`. Run in
sequence (PREP then DDWiener) they reproduce the upstream ensemble loop exactly:
because each interpolates in place, the second method sees the PREP-cleaned data
— matching `c_TMSEEG_detectBadChannels`'s internal behaviour with
`replaceMethod='interpolate'`. The `SOUND` step (with `reconstructBadChannels =
on`) then reads those labels as `replaceChannels` to lead-field reconstruct
them. When `reconstructBadChannels = off`, the SOUND step is the standard
`pop_tesa_sound`, unchanged for non-AARATEP pipelines.

**Paper-over-code choice:** the 2021 paper's final "reject ICs with peak amplitude
> 15 µV" check is **not** in the maintained v2.1.1 code (verified — code rejection
is ICLabel thresholds + the TMS-muscle *ratio* only). It is **included** here as
the `Flag ICA Components (AARATEP Peak)` step, per an explicit request to follow
the paper for this step — the one place this template follows the 2021 paper
rather than v2.1.1. The threshold (15 µV) and intent are the paper's; the exact
metric — trial-averaged, back-projected to the scalp, peak |amplitude| in µV — is
*our interpretation*, since the paper gives no formula. (`lineNoiseNumHarmonics`
defaults to 1, so the single 58–62 Hz bandstop is the upstream default behaviour.)

**Required MATLAB toolbox for AARATEP:** the `Remove Decay Artifact` step calls MATLAB's `fit()` function (Curve Fitting Toolbox) with constrained nonlinear exponential decay models (see `c_TMSEEG_fitAndRemoveDecayArtifact.m` lines 101 / 107). **Curve Fitting Toolbox must be installed** to run the AARATEP template end-to-end. If it isn't, the pre-flight check (`checkStepDependencies.m`) blocks the run with an install message before the pipeline starts. Workaround: remove `Remove Decay Artifact` from the pipeline (AARATEP will still run but the decay-fit cleanup step is skipped — results will differ from the published pipeline).

**Observed limitation (not a fidelity gap): ICA artifact capture.** On at least
one dataset the faithful AARATEP template left visible TMS-locked eye blinks in
the output. The ICA *settings* match the upstream code (FastICA symmetric / tanh),
and the run report showed the two ICA passes removed only ~1.3% of variance
(round 1: 2 Eye ICs, 0.9%; round 2: 0 Eye ICs plus 34 tiny components, 0.4%) —
i.e. the large blink/muscle artifacts did not concentrate into removable
components and round 2 found no Eye ICs. These are observations about the faithful
pipeline's *output*; they are **not** deviations from the source. Hypotheses for
the cause and any candidate fixes are *Claude's, not from the AARATEP paper/code*,
so they are kept out of this fidelity document — see the pipeline-evaluation
plan's "Tier-3 improvement hypotheses". None are applied to the faithful template.

## Other bundled EEGLAB stack

These packages are not vendored under `third_party/` but are bundled with the nestapp distribution under `eeglab2026.0.0/`. They are installed and updated through EEGLAB's own plugin manager. Cite each according to its own conventions when used. (TESA is documented above under "Pipeline-defining packages" because it defines two of the built-in templates.)

| Package | Upstream | License | Cite as |
|---|---|---|---|
| EEGLAB | https://eeglab.org | BSD | Delorme & Makeig (2004). *J Neurosci Methods* 134(1):9-21. doi:10.1016/j.jneumeth.2003.10.009 |
| ICLabel | https://sccn.ucsd.edu/wiki/ICLabel | BSD | Pion-Tonachini, Kreutz-Delgado, Makeig (2019). *NeuroImage* 198:181-197. doi:10.1016/j.neuroimage.2019.05.026 |
| CleanLine | EEGLAB plugin manager | BSD | Mullen T. (2012). NITRC: CleanLine. |
| firfilt | EEGLAB plugin manager | GPL-2.0 | Widmann A., Schröger E., Maess B. (2015). *J Neurosci Methods* 250:34-46. doi:10.1016/j.jneumeth.2014.08.002 |
| clean_rawdata | EEGLAB plugin manager | BSD | Mullen et al. (2015). *IEEE Trans Biomed Eng* 62(11):2553-2567. doi:10.1109/TBME.2015.2481482 |
| FastICA | http://research.ics.aalto.fi/ica/fastica/ | GPL-2.0 | Hyvärinen & Oja (2000). *Neural Networks* 13(4-5):411-430. doi:10.1016/S0893-6080(00)00026-5 |
