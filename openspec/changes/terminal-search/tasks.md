> **Blocker resolved (decision A):** SwiftTerm is now a **vendored fork** with a few
> public accessors (`Terminal.bufferLineCount` / `bufferLine(atIndex:)`,
> `TerminalView.cellSize`) so the app can search the whole scrollback and place the
> highlight overlay. See `ThirdParty/SwiftTerm/MODIFICATIONS.md`; Package.swift +
> project.yml now use `.package(path:)`. Extraction/matching is **per grid row**
> (BufferLine.isWrapped is not public and per-row keeps overlay rects exact).
>
> **Remaining gate:** the AppKit overlay geometry, focus, scroll-to, and minimap
> interactions are implemented and compile but need **visual QA** (task 5.3) — they
> cannot be verified headlessly.

## 1. Match-index engine

- [x] 1.1 Extract plain text per grid row from the buffer (scrollback + visible) via forked `bufferLineCount`/`bufferLine(atIndex:)` → `translateToString`, in `getTopVisibleRow()` coordinate space (`SearchController.extractLines`). *(Row-text caching deferred — extraction is O(rows) per debounced tick; fine for the live buffer, revisit for the phase-2 inspector's 100k–1M lines.)*
- [x] 1.2 Compute all match ranges for a query: case-insensitive (default), case-sensitive, whole-word, and `NSRegularExpression` modes (semantics aligned with SwiftTerm `SearchOptions`); invalid regex → empty/invalid result, no throw
- [x] 1.3 Multi-keyword: when regex off, split on spaces into terms, match each independently, assign a stable palette color per term; produce one ordered match list (union, buffer order) each match tagged with its keyword/color; when regex on, treat query as a single pattern
- [x] 1.4 Ordered match list + active index; next/previous with wrap-around; clamp active index on re-index when matches change
- [x] 1.5 Debounce recomputation (70 ms) on query change and on new terminal output (`SearchController.scheduleRefresh`)

## 2. Highlight overlay & minimap

- [x] 2.1 Transparent highlight overlay above `ZTerminalView` (`SearchHighlightOverlay`): map each match's buffer position → view rect from `cellSize` + `getTopVisibleRow()`; re-projects on scroll/resize/new-output (reads live geometry each `draw`). *(needs visual QA)*
- [x] 2.2 Base color for all matches, distinct (brighter + bordered) active match, per-keyword palette colors (`SearchPalette`)
- [x] 2.3 Scrollbar minimap gutter (`SearchMinimapView`): one marker per matching row, proportional positioning, active marker emphasized; click → jump + activate nearest. *(coalescing of adjacent rows above a density threshold not yet done; overlap with SwiftTerm's own scroller to review in QA)*

## 3. Find bar UI

- [x] 3.1 Sticky `FindBarView` (SwiftUI, `.regularMaterial`) — search field, `Aa`/`.*`/`ab|` toggles, `n / total` counter, prev/next, history menu, close — pinned top-trailing over the active pane
- [x] 3.2 Keyboard: Return / F3 = next, Shift+Return / Shift+F3 = previous, ↑/↓ = prev/next, Esc = close (Return/Shift/↑↓/Esc via `NSSearchField` delegate; F3/⇧F3 via a key monitor while active); each move scrolls the active match into view
- [x] 3.3 Empty/zero-match ("No results") and invalid-regex ("Invalid regex" + red field) states shown without disturbing the buffer view

## 4. History & wiring

- [x] 4.1 Persisted search-history store: most-recent-first, de-duplicated, capped; push committed non-empty queries; expose recent terms to the bar
- [x] 4.2 Open the bar for the active session from (a) ⌘F, (b) an **Edit ▸ Search** menu item, and (c) a configurable **search button in the bottom toolbar** (`ToolbarItemKind.search`, magnifying-glass; shown for terminal tabs, auto-listed in Settings + the toolbar context menu)
- [x] 4.3 Per-session search state (`SearchController` on `SessionModel`); switching tabs shows the active tab's bar/query independently
- [x] 4.4 Close the bar when the pane switches to the alternate screen; ⌘F is a no-op there; user text selection is never touched

## 5. Verification

- [x] 5.1 `swift build` (SwiftPM, against the vendored fork) — green
- [x] 5.2 Unit-test `TerminalSearch` + `SearchHistory` (31 tests total for search, 142 suite-wide, green)
- [ ] 5.3 **Manual / GUI QA** (see checklist below) — run the app and verify overlay geometry, focus, scroll-to, minimap, alt-screen
- [x] 5.4 `openspec validate terminal-search --strict` — valid

### 5.3 Manual QA checklist (run the app: `./scripts/bundle.sh && open build/zTerminal.app`)

1. Print lots of output (e.g. `seq 1 5000`). Press **⌘F** → bar appears top-right, caret focused.
2. Type `database` (after `printf 'connecting to database\n'` a few times) → every occurrence highlighted; counter shows `1 / N`.
3. **Return / F3** cycles forward, **Shift+Return / Shift+F3** backward, **↑/↓** too; the active match is a **different (bordered) color** and the view **auto-scrolls** to it; counter index updates and wraps.
4. A match in **deep scrollback** (scroll to bottom, search a term only near the top) is found and scrolled to.
5. Toggle **Aa** (case), **.\*** (regex, e.g. `err(or|no)`), **ab|** (whole word) — results change correctly; an invalid regex shows "Invalid regex" + red field, no crash, buffer unchanged.
6. Multi-keyword `database error timeout` → three **distinct colors**; next/prev walks all three in buffer order.
7. **Minimap** markers appear on the right edge at proportional positions; clicking one jumps there and makes the nearest match active.
8. **History**: search, close, reopen → clock menu lists the prior term; selecting it re-runs it.
9. **Esc** closes the bar and clears all highlighting; prior text selection (if any) is intact.
10. Open **`vim`** (alt screen) → the bar closes / ⌘F is inert; **quit vim** → ⌘F works again over the restored scrollback.
11. Two tabs, different searches → switching tabs preserves each tab's bar/query independently.
12. Verify overlay rects sit **exactly** on the matched glyphs at different font sizes (⌘+ / ⌘-) and after window resize.
