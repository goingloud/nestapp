# nestapp settings design language

How a setting is shown, edited, checked and passed upstream. Every pipeline step
and plot option follows these rules, so a user who has learned one form has
learned them all. New steps are written to this from the start; existing steps
are converted to it stage by stage (a step is converted when its registry entry
says `s.schema = 2`).

## What the user sees

| Setting kind | Control | Rules |
|---|---|---|
| Binary | checkbox | The label states the "on" meaning ("Normalize the measure"). Never yes/no or on/off text. |
| One of a closed list | dropdown | Human labels ("Butterworth (IIR)"); the stored value is the upstream token; each choice has a help line. |
| Several of a closed list | multi-select list | The heading shows the count ("3 selected"). |
| Number | numeric field | Unit as a suffix; limits enforced; whole numbers for integers. |
| Small integer (order, count) | spinner | The step comes from the spec (2 for even-only orders). |
| Range | "from [ ] to [ ]" pair | Low must be below high. |
| Named states + a value | mode dropdown + value field | "Off", "Automatic", "All channels" are choices; the field is enabled only for the value state. Never a magic number (0 = off, -1 = rank) or the text `[]`. |
| Channels / events | picker fed from the data | Labels read from the first selected file; with no data, the standard 10-05 labels; "Other..." for anything else. |
| Free text (labels, suffixes) | text field | Character rules where they matter (file-safe suffixes). |
| File / folder | field + Browse | |
| Manual Command | code area | The only place raw MATLAB is accepted. |

State rules:

- **A control always shows the real value.** A default looks like any other value.
- **Changed** from the default: bold label, a marker, and a reset button on the row.
- **Grey means disabled**, never "default". A disabled row says why in the help
  pane ("Only used when Measure is Spectrum"). Nothing is hidden for being
  inapplicable.
- **Invalid input is prevented, then explained.** Controls make bad values
  impossible where they can; a typed value is checked on Enter, and a refused
  edit keeps the old value and says why.
- **Help follows focus.** The help pane shows the step description, then the
  focused setting: what it does, unit, limits, default, and one line per choice.
- **Long forms** group settings under section headings; rarely changed ones
  start folded under **Advanced**. A folded section holding a changed setting
  is flagged on its heading.
- Labels are sentence case, units go in the label suffix ("(Hz)"), and no
  upstream token or code spelling is ever shown to the user.

## How a step declares it (schema 2)

All of it is data in `src/registry/stepRegistry.m`; the form, the pre-flight
check and the dispatch read the same declarations.

**Each setting** (`makeParam`):

- `type` - `scalar`, `integer`, `vector`, `logical`, `string`, `stringlist`,
  `file`, `folder`.
- `choices` - `{key, label, help}` rows for a closed list.
- `modes` - `{key, label, help[, emit]}` rows for named states beside a value.
  `emit` is what the upstream function receives for that state (default `[]`).
  The **first** mode is what an empty value in an old file meant.
- `limits`, `openMin`, `step` - what a number may be.
- `section`, `advanced` - where it sits in the form.
- `upstream` - how a logical is passed: `'onoff'` (default), `'yesno'`, `'01'`,
  `'logical'`.
- `pickFrom` - `'channels'` or `'events'`.

**Defaults are typed**: `true`/`false`, numbers, choice keys, mode keys, cell
arrays of labels.

**Relationships** (`paramRelation`), one vocabulary for every step:

| Kind | Meaning | Effect |
|---|---|---|
| `exclusive` | two ways of writing one setting | setting one disables the others; listed in precedence order |
| `enableWhen` | applies only for some values of another setting | disabled otherwise, and **not passed upstream** |
| `requires` | must be set (always, or for some values of another setting) | pre-flight refuses the run |
| `anyOf` | at least one of these must be set | pre-flight refuses the run |
| `order` | `a < b` when both are set | pre-flight refuses the run |

If a description says a setting "only applies", "is ignored" or "overrides"
something, the relationship must be declared too (`RegistryContractTest`
checks this).

**Passing upstream.** `toUpstream(entry, params)` returns the settings that
apply, with modes and logicals translated. The step's `case` in
`processOneFile` names the fields it passes; no positional access, no tests
against the text `'[]'`. Unit conversions (ms to s) and label-to-index lookups
live there, in one readable call.

**Old files.** `migrateStepParams` converts saved text to typed values on load
and again at dispatch (it is idempotent). Renamed or merged keys go in its
`legacyShapes` switch, keyed by step name. A value it cannot read falls back to
the default and says so.

**`upstreamAudit`** records what was checked: the upstream function and version
read, the options exposed, the options left out and why, and every correction
made to the old entry.

## Converting a step

1. **Re-audit independently.** Read the upstream function (signature, option
   parser, defaults, limits, and which options interact) and nestapp's dispatch
   before looking at the old registry entry; then diff. Check every relationship
   in both directions. `docs/param-audit-findings.md` lists findings from the
   earlier audit to fold in.
2. Write the schema-2 entry: typed defaults, choices with labels and help,
   limits, sections, relations, `upstreamAudit`.
3. Rewrite the `case` to use `up.<key>` from `toUpstream`.
4. Add `legacyShapes` rules for renamed keys or re-encoded values.
5. Check it while implementing:
   `c = captureStepArgs('cases', {'Step'}); captureStepArgs(c, 'before.mat')`
   on the old code, the same cases after, then
   `captureStepArgs('diff', 'before.mat', 'after.mat')`. Every difference is a
   bug or a deliberate correction recorded in `upstreamAudit` and the changelog.
6. Add a changelog line for anything a user would notice.
