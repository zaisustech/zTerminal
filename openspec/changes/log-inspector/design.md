## Context

Phase 1 (`terminal-search`) built a `TerminalSearch` engine that, given the buffer's per-row
text and a query, returns every `Match` (buffer-line index, column range, keyword) ordered in
buffer order, plus a `SearchController` that extracts row text via the forked SwiftTerm
accessors (`bufferLineCount` / `bufferLine(atIndex:)`) and draws a highlight overlay. Filter
mode needs the *same* match set, just presented differently: instead of highlighting matches
in place, show a **list of the matching lines**. The engine already has everything needed —
this change is a presentation + classification layer, not new search plumbing.

The hard constraint from phase 1 still holds: **the live VT100 grid cannot hide rows** (the
emulator addresses fixed rows/cols; removing lines corrupts the display). So filtering is a
**panel over a snapshot**, never an edit of the terminal.

## Goals / Non-Goals

**Goals:** a Filter toggle in the find bar; a panel showing only matching lines with original
line numbers + highlighting; `Showing N of M lines`; click-to-jump to the live buffer;
severity chips (All/Error/Warning/Info/Debug/Trace) auto-detected per line; invert filter;
refresh on new output; a snapshot cache so chip/scroll interactions are instant.

**Non-Goals:** context lines (± N) — deferred; arbitrary on-disk file viewing; export/edit;
replacing highlight mode (the two coexist behind one toggle).

## Decisions

### Decision: Filter is a panel over a snapshot, not in-place hiding
When filter mode is on, `SearchController` builds a **snapshot** = the array of per-row text
(the same extraction highlight mode already does) plus, for each row, its detected severity.
The `FilterPanel` renders the subset of rows selected by (text query ∧ severity chip, XOR
invert). The terminal underneath is untouched; closing filter mode just hides the panel.

### Decision: One query, two presentations
The find bar owns a single query + options + match index. A **Filter toggle** picks the
presentation: **highlight** (phase 1 overlay) or **filter** (this panel). Switching modes
does not re-type or re-run — it re-renders from the same `TerminalSearch` state. This keeps
the DevTools mental model (one search box, a filter switch) and avoids duplicate state.

### Decision: Matching-line set derives from the engine
A line is "matching" when `TerminalSearch.matches` contains any match on that line index (so
regex / whole-word / multi-keyword all flow through unchanged). The panel lists those line
indices in order; when the query is empty but a severity chip is active, the set is every
line of that severity (text predicate is vacuously true).

### Decision: Severity detection is a cheap per-line classifier
`LogSeverity.classify(_ line:)` scans a line for well-known level tokens — `error`/`err`,
`warn`/`warning`, `info`, `debug`, `trace`/`verbose` (case-insensitive, bounded to common
shapes like `ERROR`, `[warn]`, `level=info`) — returning `.error/.warning/.info/.debug/.trace`
or `.none`. Chips: **All** (no filter), or a specific level. It's heuristic (logs aren't
structured) — good enough for the DevTools-style quick filter; documented as best-effort.

### Decision: Invert = negate the text predicate only
Invert flips the **text-match** predicate (show lines the query does NOT match), matching
DevTools' `-term`. The severity chip still applies (AND). Invert with an empty query +
`All` = everything (no-op), which is fine.

### Decision: Snapshot cache keyed by buffer revision
Extraction over a large scrollback is O(rows); doing it on every chip tap or panel scroll
would be wasteful. Cache the extracted `[(text, severity)]` and invalidate on new output
(`onBufferChanged`) or an explicit query/extract. Chip toggles and scrolling then just
re-filter the cached array — instant.

### Decision: Click-to-jump reuses phase-1 scrolling
Clicking a filtered row calls the existing `activateNearest(line:col:)` + scroll-to path in
`SearchController`, so the live terminal scrolls to that line and the highlight overlay marks
it — the panel and the terminal stay in sync.

## Risks / Trade-offs

- **Severity false positives/negatives** — a line containing "error" in prose is tagged
  `.error`. Acceptable for a quick filter; users can fall back to text filtering. Keep the
  token set conservative.
- **Snapshot vs. live output** — while filtered, new output appends to the buffer; the
  snapshot refreshes on `onBufferChanged` (debounced) so the panel stays current without
  thrashing. The panel shows a point-in-time projection between refreshes.
- **Panel virtualization** — SwiftUI `List`/`LazyVStack` only realizes visible rows, so even
  a few thousand matching lines scroll smoothly; the filtered array itself is bounded by the
  retained scrollback.
- **Wide/wrapped lines** — same per-grid-row model as phase 1 (BufferLine.isWrapped isn't
  public); a wrapped logical line shows as its grid rows. Consistent with highlight mode.

## Migration Plan

Additive. New `FilterPanel`, `LogSeverity`, and filter/severity/invert state on
`SearchController`; a Filter toggle + chip row in `FindBarView`. No persistence, no schema
change, no terminal-core change. Rollback = remove the panel + classifier + the toggle;
highlight-mode search is unaffected.

## Open Questions

- Persist the last-used severity chip / invert across opens, or reset each time? (Leaning:
  reset — a fresh filter each session matches DevTools.)
- Should the panel replace the terminal view (full-bleed) or float as a side/overlay panel?
  (Leaning: overlay that covers the terminal area while active, with the find bar on top —
  simplest and closest to DevTools' console.)
- Add context lines now or in a follow-up? (Leaning: follow-up, per Non-Goals.)
