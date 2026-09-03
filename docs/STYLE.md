# nestapp MATLAB style guide

These conventions keep the codebase consistent and reviewable. CI runs
`tools/run_lint.m` (a `checkcode` wrapper) — fix reported errors before merging.

## Naming

- **Functions & variables**: `camelCase` (`signalData`, `runPipelineCore`).
- **Constants**: `UPPER_SNAKE_CASE` (`SMOOTH_WIN_PTS`, `MAX_ITERATIONS`).
- **Booleans**: prefix with `is`/`has`/`should` (`isConverged`, `hasValidInput`).
- **Pipeline step names** are user-facing strings and part of the public API —
  do not rename without a deprecation cycle (see CONTRIBUTING → public surface).

## Files & functions

- One primary function per file; filename matches the function name.
- Every function starts with a header comment block — see the **docstring
  contract** in [CONTRIBUTING.md](../.github/CONTRIBUTING.md). The generated API docs are
  built from these, so keep them accurate.
- Keep functions focused; split helpers out when one grows past ~100 lines.
- Group related code with `%% Section` headers.

## Formatting

- **4-space indentation** (MATLAB default); spaces, not tabs.
- One blank line between logical sections.
- Align `end` with its opening statement.
- No magic numbers — assign to a named constant near the top.

## Readability

- Prefer named intermediate variables over dense one-liners:
  ```matlab
  % Avoid
  result = data(mask & (f > fMin) & (f < fMax), :);
  % Prefer
  inBand  = f > fMin & f < fMax;
  keep    = mask & inBand;
  result  = data(keep, :);
  ```
- Comment the *why*, not the *what*. Mark known gaps with `% TODO:`.
- Prefer vectorised operations; reach for `parfor`/`parfeval` only for
  genuinely independent work, and keep parallel bodies side-effect free.

## Licensing

New source files should carry a short GPL-3.0 header (see
`tools/apply_headers.m` for the canonical block). The repository `LICENSE`
governs the project as a whole.

## Tests

- Write `classdef ... < NestappTestCase`. The base class puts `src/` on the
  path and fails any test that leaks a figure, so no test does either by hand.
- Put the file in the folder its dependencies require: `tests/pure/`,
  `tests/eeglab/`, `tests/gui/`, `tests/eeglab_gui/`. **Never skip** — a skip
  is a failure, because the folder already declares what the test needs.
- Use the shared helpers (`scratchDir`, `charFixture`, `fakeEeg`,
  `fakeReducedCache`, `saveFixtureSet`, `isolatePrefs`, `waitFor`) rather than
  a private copy. The old suite had eleven local fake-EEG builders and five
  temp-dir idioms; `tests/pure/SuiteHygieneTest.m` now fails on both.
- Prefer a table (`TestParameter`) to hand-unrolled cases when one rule covers
  many inputs — but only when the rows genuinely differ. A parameterised test
  that returns early for most rows is worse than no test.
- Test behaviour, not source text. Scraping a file to assert how code is
  *written* survives a reformat and cannot tell a call from a comment.
- Add a regression test with every bug fix, and make it fail before the fix —
  a test that cannot fail is the one failure mode worth hunting for.
