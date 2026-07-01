## 1. Config model

- [x] 1.1 Add `ZTerminalConfig` (Codable): `bookmarks: [Bookmark]`, `theme: ProjectTheme?`
- [x] 1.2 `Bookmark` = `{ name, command, icon }`, icon defaulting to `star.fill` when absent
- [x] 1.3 `ProjectTheme` = all-optional subset of `DesignTokens` + `mode`
- [x] 1.4 `load(in:)` (nil when missing/unreadable), `save(in:)`, `addBookmark(_:in:)`, `exists(in:)`

## 2. Bookmarks in the runner

- [x] 2.1 Add optional `icon` to `RunTask`
- [x] 2.2 `ZTerminalTaskSource: TaskSource` — `matches` on file presence, `detect` → "Bookmarks" group
- [x] 2.3 Register it **first** in `TaskRunner.sources`; flag the group `bookmarks: true`
- [x] 2.4 Render the icon in `RunRow`; render an "Add bookmark" form in the Bookmarks section that writes back and refreshes

## 3. Theme override

- [x] 3.1 Add non-persisted `projectTheme` + `effectiveTokens`/`effectiveMode` to `ThemeManager`; rebase derived accessors on effective values
- [x] 3.2 `applyProjectTheme(from cwd:)` loads the file's `theme` and sets the override (animated)
- [x] 3.3 Switch rendering call sites (`RootView`, `TabBar`, `LiquidGlass`, `TerminalHostView`) to effective values; keep Settings on base
- [x] 3.4 `ProjectThemeApplier` view applies/clears the override on active-tab and CWD changes

## 4. Verification

- [x] 4.1 `swift build`
- [x] 4.2 Unit tests: config load/save round-trip, missing-icon default, `ZTerminalTaskSource.detect`, theme merge (override vs revert)
- [ ] 4.3 Manual: drop a `.zTerminal.json` in a folder → play button + Bookmarks group with icons; run one; add one from the app; theme applies on entry and reverts on leave
- [x] 4.4 Run `openspec validate project-bookmarks`
