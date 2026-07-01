## 1. Model & aggregation

- [ ] 1.1 Add `PaletteItem` (category, title, subtitle, icon, `activate(newTab:)`)
- [ ] 1.2 Aggregator: bookmarks (home + cwd), `TaskRunner` tasks, `ScriptShortcut`s, open tabs, recent dirs, app commands
- [ ] 1.3 Recent-directories store: capped, de-duplicated, persisted; append on CWD change

## 2. UI & search

- [ ] 2.1 `CommandPalette` overlay with a filter field, grouped-by-category when empty
- [ ] 2.2 Fuzzy match + ranking with recency bias; flat ranked list while searching
- [ ] 2.3 Keyboard nav: arrows to move, Return = activate (current tab), ⌘Return = new tab, Esc = close

## 3. Wiring

- [ ] 3.1 Register ⌘K at the window level to toggle the palette
- [ ] 3.2 Runnable items reuse existing run semantics (idle→current, busy/⌘→new tab)
- [ ] 3.3 Directory items jump the active tab; tab items call `WindowModel.select`

## 4. Verification

- [ ] 4.1 `swift build`
- [ ] 4.2 Unit-test the fuzzy ranker and the aggregator (given fixtures → expected items/order)
- [ ] 4.3 Manual: ⌘K finds and runs a bookmark, a task, a shortcut; switches tabs; jumps to a recent dir
- [ ] 4.4 Run `openspec validate command-palette --strict`
