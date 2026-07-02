## Context

SwiftTerm exposes the emulator through `term.getTerminal()`, whose buffer holds both the
visible grid and the scrollback as rows of styled cells reachable via public
`getLine(row:)` / `getCharData(col:row:)`. The app already reaches into this buffer elsewhere
(clear erases scrollback with `ESC[3J`). Search is therefore a **read-over-buffer +
presentation layer**: no PTY or shell involvement.

The pivotal constraint: **SwiftTerm's public search API is single-match only.**
`TerminalView.findNext(_:options:)` / `findPrevious(_:options:)` take a `SearchOptions`
(public: `caseSensitive`, `regex`, `wholeWord`), select **one** result, and scroll it into
view; `clearSearch()` resets. There is **no public way** to get a total count, the full list
of match positions, or an all-match highlight — the internal `SearchService.findAll` and
per-match rendering are not exposed. So highlight-all, the `n/total` counter, multi-keyword
coloring, and the minimap **must be driven by our own match index** built over `getLine`,
with our own overlay for drawing. We keep the app's option semantics aligned with
`SearchOptions` so behavior matches SwiftTerm's own find where they overlap.

## Goals / Non-Goals

**Goals:** a sticky ⌘F find bar; search the *entire* scrollback + visible grid; highlight
**all** matches with a distinct **active-match** color; live `n/total` counter; keyboard
next/previous (Return, Shift+Return, F3/Shift+F3, ↑/↓) with scroll-to; case / regex /
whole-word options; multi-keyword coloring; search history; clickable scrollbar minimap
markers; per-tab search state.

**Non-Goals (this change):** **Filter Mode**, context lines, severity chips, Invert Filter,
and 100k–1M-line virtualized rendering — all deferred to the future **`log-inspector`**
change, which snapshots the buffer into an immutable, virtualizable list where hiding lines
is safe. Also out: search-and-replace; cross-tab "search all tabs"; searching evicted
scrollback; searching a full-screen program's alternate screen.

## Decisions

### Decision: Own match index over the buffer, not the single-match public API
On each (debounced) query change, iterate the emulator's rows (scrollback + visible) via
`getLine`, extract each **logical** line's plain text, and compute all match ranges. Store an
ordered `[Match]` (buffer row, column range, which keyword) plus an `activeIndex`. This one
index feeds the counter, the highlight overlay, next/previous navigation, and the minimap.
SwiftTerm's `findNext`/`findPrevious` are **not** used as the source of truth (they can't
count or list); we own scroll-to via the public scroll API. The buffer stays the source of
truth — no shadow mirror — so results always reflect exactly what is on screen and in
scrollback.

### Decision: Highlight via a custom overlay, keep selection separate
Draw match highlights in a transparent overlay layer above the `ZTerminalView`, mapping each
match's buffer position → view rect using the terminal's cell geometry (font metrics, cell
size, current scroll offset), and re-projecting on scroll/resize/new-output. All matches get
the base highlight color; the **active** match gets a distinct color. This deliberately does
**not** reuse SwiftTerm's selection for highlighting (selection is single-range and would
fight a user's own text selection). Any prior user selection is left intact and restored
focus-wise when the bar closes.

### Decision: Options mirror `SearchOptions`
Default is case-insensitive substring. `Aa` → case-sensitive, `ab|` → whole-word, `.*` →
regex (`NSRegularExpression`). Whole-word uses the same non-word-boundary notion SwiftTerm
uses. An **invalid regex** is handled non-destructively: the field shows an invalid/zero
state, the overlay clears, the buffer view is unchanged — never a throw.

### Decision: Multi-keyword = space-split terms, union in buffer order
When regex is off, the query is split on spaces into N terms; each term is matched
independently and assigned a stable **color from a fixed palette** (cycled if > palette
size). The match list is the union of all terms' matches sorted by buffer position, so the
counter and next/previous walk every hit in document order regardless of keyword. When regex
is **on**, the whole query is one pattern (spaces are literal) — a quoted/one-term escape
hatch for phrases with spaces. Case/whole-word apply per term.

### Decision: Scrollbar minimap gutter
A thin gutter aligned to the scroll extent renders one marker per matched **row**,
positioned proportionally (matchRow / totalRows). The active match's marker is emphasized.
Clicking a marker scrolls that row into view and makes the nearest match active. The gutter
recomputes from the same index, so it never drifts from the highlights or counter.

### Decision: Search history — persisted, capped, dedup
Committed non-empty queries are pushed onto a small persisted list (most-recent-first,
de-duplicated, capped, e.g. 20). The bar offers them for re-use via a history affordance
(recent-terms menu). To avoid clobbering match navigation, **↑/↓ move between matches**;
history is browsed through its own control, not the arrow keys in the field.

### Decision: Alternate-screen behavior
While a program owns the alternate screen (`vim`, `less`, pagers), the find bar is
disabled/closed for that pane — those programs own search there — and it re-enables when the
program exits and the normal screen returns. This avoids highlighting rows the program will
overwrite.

### Decision: Per-session state, window-level keybinding
Each `SessionModel` (tab) owns its find state (query, options, active index, open/closed) so
switching tabs preserves each tab's search. ⌘F opens/focuses the bar for the **active**
session and targets its `ZTerminalView`.

## Risks / Trade-offs

- **Large-scrollback scan cost** — scanning tens of thousands of rows per keystroke. Mitigate
  by debouncing (50–100 ms) and cheap per-row string ops; cache extracted row text keyed by
  row and invalidate on new output so re-queries don't re-extract unchanged rows. Only the
  active match drives a scroll.
- **Overlay ↔ buffer sync** — highlights and minimap are computed positions, not part of
  SwiftTerm's render, so they must re-project on scroll, resize, font change, and new output,
  or they visibly drift. Recompute rects from live geometry on those events; recompute the
  index on buffer change so the counter stays correct.
- **Live output during search** — new output can arrive while the bar is open. Re-index on
  buffer change; the counter and minimap update; the active match holds its position when
  still present, else clamps to the nearest valid index.
- **Wrapped lines** — a logical line may wrap across grid rows; a match spanning the wrap must
  highlight across both. Extract text per **logical** line (following the buffer's
  continuation flag), then map ranges back to the grid rows they occupy.
- **Regex cost / catastrophic patterns** — a pathological regex over a huge buffer can stall.
  Compile once per query; bound work per debounce tick; treat compile failure as invalid.

## Migration Plan

Purely additive except a small persisted search-history list. No terminal-core changes, no
schema migration. Rollback = remove `FindBar`, the highlight overlay + minimap gutter, the
`TerminalSearch` engine, the ⌘F binding, and the history store. No effect on existing
sessions.

## Open Questions

- Should ⌘G / ⌘⇧G (next/previous while the field is unfocused) ship now alongside
  Return/F3/↑↓? (Leaning: yes — cheap and expected.)
- Fixed keyword-color palette vs. theme-derived colors that adapt to the active Liquid Glass
  theme? (Leaning: fixed accessible palette first; theme-derive later if it clashes.)
- Minimap density on very large buffers — one marker per matching row can saturate the
  gutter; do we coalesce adjacent rows into a single band? (Leaning: coalesce above a
  threshold.)
