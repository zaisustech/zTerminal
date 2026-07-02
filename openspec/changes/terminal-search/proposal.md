## Why

zTerminal has scrollback but no way to *search* it. Finding an earlier error, a printed
URL, or a build warning means eyeballing the whole buffer or re-running the command through
`grep`. Every mature terminal (Terminal.app, iTerm2) has a ⌘F find bar, and developers who
live in VS Code / Cursor / IntelliJ expect more: all matches highlighted at once, a live
`n/total` counter, keyboard-driven next/previous, regex and whole-word options, and markers
on the scrollbar so they can see *where* in a long buffer the hits are.

This is **phase 1 of two**. It delivers IDE-grade **search over the live terminal** —
highlight, count, navigate, options, multi-keyword, history, and a minimap. A separate
follow-up change, **`log-inspector`**, will add a snapshot view for **Filter Mode**
(showing only matching lines), severity chips, context lines, invert, and 100k–1M-line
virtualization — things that cannot be done on a live VT100 grid without freezing it into an
immutable list (see Non-Goals).

## What Changes

- Add a **find bar** opened with **⌘F**, anchored to the top of the active pane and
  **sticky** (stays put while the buffer scrolls). It searches the entire scrollback plus
  the visible grid, not just the on-screen rows.
- **Real-time, debounced** (50–100 ms) matching as the user types.
- **Highlight every match**; the **current/active match uses a distinct color**. A live
  **`Current: n / total`** counter is shown (e.g. `4 / 15`).
- **Navigate matches**: **Return** = next, **Shift+Return** = previous, **F3 / Shift+F3**
  same, **↑ / ↓** optional; each move scrolls the active match into view.
- **Options**: **case-sensitive** (`Aa`), **regex** (`.*`), and **whole-word** (`ab|`)
  toggles. Default is case-insensitive substring.
- **Multi-keyword search**: space-separated terms (e.g. `database error timeout`) are each
  highlighted in a **different color**; navigation and the counter span the union of all
  terms in buffer order.
- **Search history**: recent terms are remembered and offered for re-use.
- **Match-navigation minimap**: markers along the scrollbar show where matches occur;
  **clicking a marker jumps** to that location. The active match's marker is emphasized.
- **Esc** closes the bar and clears all highlighting.
- Search operates over the **normal buffer**. While a full-screen program owns the
  **alternate screen** (`vim`, `less`, pagers), the find bar is unavailable — those programs
  provide their own search — and it returns when they exit.

## Capabilities

### New Capabilities
- `terminal-search`: A ⌘F find bar that searches the full scrollback with highlight-all,
  a distinct active-match color, an `n/total` counter, keyboard next/previous (Return /
  Shift+Return / F3 / ↑↓), case/regex/whole-word options, multi-keyword coloring, search
  history, and clickable scrollbar minimap markers.

### Modified Capabilities
<!-- None; search reads the existing SwiftTerm buffer without changing terminal-core behavior. -->

## Impact

- **New UI:** a sticky `FindBar` overlay (search field, `Aa`/`.*`/`ab|` toggles, `n/total`
  counter, next/previous, history affordance, close), styled with the existing Liquid Glass
  chrome, plus a **highlight overlay** layer and a **scrollbar minimap** gutter over the
  active `ZTerminalView`.
- **New logic:** a `TerminalSearch` engine that builds its own **match index** over the
  buffer via SwiftTerm's public `getLine`/`getCharData`, because SwiftTerm's public search
  API (`findNext`/`findPrevious`/`clearSearch` + `SearchOptions`) is **single-match,
  select-and-scroll only** — it cannot report a total count, highlight all matches, or feed a
  minimap. The engine computes match ranges per logical line, tracks an ordered match list +
  active index, and drives the overlay, counter, minimap, and scroll-to.
- **Wiring:** ⌘F registered at the window level to open/focus the bar for the active
  session; per-session search state so each tab keeps its own query; a small persisted,
  capped, de-duplicated **search-history** store.
- **No new external dependencies** (regex via `NSRegularExpression`; `SearchOptions` already
  ships with SwiftTerm).

## Non-Goals (deferred to the `log-inspector` change)

- **Filter Mode** (hiding non-matching lines), **context lines**, **severity chips**
  (All/Error/Warning/…​), and **Invert Filter** — these require an immutable snapshot list,
  not the live VT100 grid, and land in `log-inspector`.
- **100k–1M-line virtualized rendering** — the live PTY scrollback is capped; huge-buffer
  virtualization belongs to the snapshot inspector.
- Search-and-replace; cross-tab "search all tabs"; searching output already evicted from the
  capped scrollback; searching a running full-screen program's alternate screen.
