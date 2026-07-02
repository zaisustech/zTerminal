## 1. Severity classifier

- [x] 1.1 `LogSeverity` enum (`error/warning/info/debug/trace/none`) + `classify(_ line:)` scanning conservative level tokens (`Sources/zTerminal/Search/LogSeverity.swift`)
- [x] 1.2 Unit-test the classifier (`LogSeverityTests`, 7 tests)

## 2. Filter state (SearchController)

- [x] 2.1 `@Published filterMode / severityFilter / invert` on `SearchController`
- [x] 2.2 Snapshot cache `[(text, severity)]`, rebuilt in `refresh()` and invalidated on new output; `filterRevision` bumps the panel
- [x] 2.3 `filteredLines()` via pure `nonisolated static select(...)`: (query match XOR invert; empty query ⇒ all) AND severity chip
- [x] 2.4 `totalCount` + panel count for `Showing N of M lines`
- [x] 2.5 Filter mode is a presentation switch (`toggleFilterMode`) over the shared query/index; highlight overlay + minimap suppressed while the panel is shown

## 3. Filter panel UI

- [x] 3.1 `FilterPanel` (SwiftUI `List`, lazy rows) listing filtered lines: original line number + text with matches highlighted (reuses `SearchPalette`)
- [x] 3.2 Severity chip row (All · Error · Warning · Info · Debug · Trace) + Invert toggle + `Showing N of M lines`
- [x] 3.3 Tap a row → `jumpToLine` scrolls the live terminal to it
- [x] 3.4 Filter toggle (funnel) added to `FindBarView`

## 4. Wiring

- [x] 4.1 `FilterPanelHost` shown from `RootView` as an overlay over the terminal (below the find bar) for the active terminal tab, driven by `filterMode`
- [x] 4.2 Snapshot + panel refresh on new output (reuses debounced `scheduleRefresh` → `refresh`)
- [x] 4.3 Disabling filter / clearing the query restores the terminal view; buffer never mutated

## 5. Verification

- [x] 5.1 `swift build` — green
- [x] 5.2 Unit tests: `LogSeverityTests` (7) + `FilterSelectionTests` (7, covering query-only / severity-only / query+severity / invert / invert+severity / empty-query) — green
- [ ] 5.3 **Manual / GUI QA** (see checklist) — needs the app run (blocked here by the multi-display/Spaces capture issue, same as terminal-search 5.3)
- [x] 5.4 `openspec validate log-inspector --strict` — valid

### 5.3 Manual QA checklist

1. Print mixed output (levels + a repeated term), press ⌘F, type a term, click the **funnel** (Filter) toggle → panel shows only matching lines, each with its **original line number**, matches highlighted.
2. `Showing N of M lines` reflects the filter.
3. **Severity chips**: Error/Warning/Info/Debug/Trace scope the list by detected level; **All** clears it; chips compose with the text query.
4. **Invert**: shows non-matching lines; composes with a severity chip.
5. **Click a line** → the live terminal scrolls to it and it becomes the active match.
6. Print a new matching line while filtering → it appears and the count updates.
7. Toggle Filter off / clear query → terminal view restored intact; Esc closes the bar and panel.
