## 1. Model & aggregation

- [x] 1.1 `PaletteItem` (category, title, subtitle, icon, `activate(newTab:)`, `supportsNewTab`) — `Sources/zTerminal/CommandPalette/PaletteItem.swift`
- [x] 1.2 `PaletteAggregator`: bookmarks (home + cwd, de-duped), `TaskRunner.detect` tasks, script shortcuts, open tabs, recent dirs, app commands — built fresh each open
- [x] 1.3 `RecentDirectories` store: capped, de-duplicated, persisted; recorded on CWD change (via the active-session observer)

## 2. UI & search

- [x] 2.1 `CommandPaletteView` overlay: filter field, grouped-by-category when empty, click-away scrim, Liquid Glass
- [x] 2.2 `FuzzyMatch` (subsequence + contiguity/boundary/prefix bonuses) + `PaletteRanker` (grouped when empty, ranked flat when searching; title beats subtitle)
- [x] 2.3 Keyboard nav via an `NSSearchField` delegate: ↑/↓ move, Return activate (current tab), ⌘Return new tab, Esc close; selection scrolls into view

## 3. Wiring

- [x] 3.1 Register **⌘K** at the window level to toggle the palette (**Clear moved to ⌘⌥K** so the palette owns ⌘K per the spec)
- [x] 3.2 Runnable items reuse the existing run semantics (idle→current tab, busy/⌘→new tab), mirroring `RunPopover`
- [x] 3.3 Directory items `cd` the active tab (⌘Return → new tab there); tab items call `WindowModel.select`

## 4. Verification

- [x] 4.1 `swift build` — green
- [x] 4.2 Unit tests: `FuzzyMatchTests` (6) + `PaletteRankerTests` (3) + `RecentDirectoriesTests` (3). *(The aggregator wires live sources — exercised via GUI QA rather than a heavyweight WindowModel fixture.)*
- [ ] 4.3 **Manual/GUI QA** — needs the app run (blocked here by the multi-display/Spaces screenshot issue): ⌘K opens; typing filters/ranks; ↑/↓/Return/⌘Return/Esc; runs a bookmark, a task, a shortcut; switches tabs; jumps to a recent dir; grouped when empty
- [x] 4.4 `openspec validate command-palette --strict`
