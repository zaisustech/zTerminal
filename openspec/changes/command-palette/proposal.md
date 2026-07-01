## Why

zTerminal keeps growing useful, runnable things — global and per-project bookmarks,
auto-detected script tasks (npm/cargo/make…), script shortcuts, open tabs, recent
directories — but each lives behind its own button or menu. There is no single, fast,
keyboard-first way to find and run *anything*. Developers expect a **⌘K command
palette**: type a few letters, hit Return, done.

## What Changes

- Add a **command palette** opened with **⌘K**, a fuzzy-searchable overlay that
  aggregates actions from everything the app already knows:
  - **Bookmarks** — Global (`~/.zTerminal.json`) and Current folder.
  - **Script tasks** — every ecosystem `TaskRunner` detects in the CWD.
  - **Script shortcuts** — the user's global shortcuts.
  - **Tabs** — switch to any open tab.
  - **Recent directories** — jump the active tab to a recently visited folder.
  - **App commands** — new tab, open Settings, reveal in Finder, clear, restart.
- Activating a command SHALL follow the existing run semantics: run in the current tab
  when idle, in a new tab when the shell is busy or the user holds ⌘ (⌘Return).
- Results are **grouped by category** and **ranked** by fuzzy score with a most-recent
  bias, filtered as the user types.

## Capabilities

### New Capabilities
- `command-palette`: A ⌘K fuzzy launcher that aggregates bookmarks, script tasks, shortcuts, tabs, recent directories, and app commands into one keyboard-first surface.

### Modified Capabilities
<!-- None; the palette reads existing sources without changing them. -->

## Impact

- **New UI:** a `CommandPalette` overlay + a `PaletteItem` model and an aggregator that
  pulls from `TaskRunner`, `ScriptShortcut`, `ZTerminalConfig` (home + cwd),
  `WindowModel.sessions`, and a recent-directories store.
- **Recent directories:** a small persisted list updated from CWD changes (reuses the
  existing OSC 7 tracking).
- **Keybinding:** ⌘K registered at the window level.
- No new external dependencies.
