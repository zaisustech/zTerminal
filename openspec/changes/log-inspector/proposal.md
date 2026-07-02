## Why

`terminal-search` (phase 1) highlights and navigates matches in place, but developers
inspecting long build output or console streams want the other half of a modern log tool:
**filter to just the relevant lines**, the way Chrome DevTools' console, VS Code's output
filter, or `k9s`/Lens logs work. Type `database` and everything else disappears; flip a
severity chip and only errors remain. You can't do that on the live VT100 grid — hiding rows
would break cursor addressing — so this change adds a **filter panel** over a snapshot of the
buffer, reusing the `TerminalSearch` engine that already returns every matching line with its
original line number.

## What Changes

- Add a **Filter toggle** to the existing find bar (a funnel button). Turning it on opens a
  **filter panel** over the terminal showing **only the lines that match** the query — each
  with its **original line number** and matches highlighted — instead of highlighting in
  place. Turning it off (or clearing the query) restores the normal terminal view.
- The panel shows a **`Showing N of M lines`** count and is **click-to-jump**: clicking a
  filtered line scrolls the live terminal to that line and makes it the active match.
- **Severity chips** — `All · Error · Warning · Info · Debug · Trace` — filter the panel by a
  log level auto-detected per line (from common tokens like `ERROR`, `WARN`, `[info]`, etc.).
  Chips compose with the text query.
- **Invert filter** — a toggle that shows the lines that do **not** match (DevTools' `-`
  negative filter), so noise can be hidden.
- Filtering is a **read-only projection over a snapshot** of the current buffer + scrollback;
  it never mutates or discards terminal contents. New output while filtering refreshes the
  snapshot.

## Capabilities

### New Capabilities
- `log-inspector`: A Chrome-DevTools-style filter over the terminal buffer — a filter panel
  that shows only matching lines (original line numbers, click-to-jump, `N of M` count),
  auto-detected severity chips, and an invert toggle, built on the `terminal-search` engine.

### Modified Capabilities
- `terminal-search`: the find bar gains a **Filter toggle** that switches between highlight
  mode (phase 1) and the new filter panel; both share one query, options, and match index.

## Impact

- **New UI:** a `FilterPanel` (SwiftUI list, virtualized via `List`/`LazyVStack`) overlaying
  the terminal when filter mode is on, a severity-chip row, and an invert toggle in the find
  bar. Reuses `SearchPalette` colors and the `FindBarView` layout.
- **New logic:** a `LogSeverity` classifier (line text → level) and filter/severity/invert
  selection in `SearchController`; the matching-line set comes from the existing
  `TerminalSearch.matches` (grouped by line). A cached line snapshot so scrolling the panel
  and toggling chips don't re-extract the whole buffer each time.
- **Reuses:** the forked SwiftTerm buffer accessors (`bufferLineCount` / `bufferLine(atIndex:)`),
  `TerminalSearch`, the find bar, and click-to-jump scrolling — all already in place.
- **No new external dependencies.**

## Non-Goals

- Context lines around matches (± N surrounding lines) — a natural follow-up, deferred to
  keep this change focused; the panel shows matching lines only for now.
- A full detached 100k–1M-line virtualized log viewer for files on disk — this operates on
  the live terminal's buffer + retained scrollback, not arbitrary files.
- Editing, saving, or exporting filtered output.
