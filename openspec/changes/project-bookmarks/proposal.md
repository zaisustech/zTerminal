## Why

The Run popover surfaces tasks auto-detected from manifests (npm scripts, cargo,
make…), but every project also has a handful of **project-specific commands** that
no manifest declares — `expo prebuild --clean`, a "clean install"
(`rm -rf node_modules && npm ci`), a one-off deploy script. Today those are retyped
by hand every time. Teams also want a project to open with its own **look** (accent,
gradient, terminal palette) so context-switching between repos is visually obvious.

A checked-in `.zTerminal.json` lets a project carry both: a list of **bookmarks**
(favorite/custom commands, each with an icon) and an optional **theme** override.

## What Changes

- Add a per-project config file **`.zTerminal.json`**, read from the active tab's
  current directory.
- **Bookmarks:** each entry has a `name`, a `command` (any shell command), and an
  `icon` (SF Symbol). They appear as a **"Bookmarks" group at the top of the Run
  popover** — i.e. right where the play button opens — and run like any other task
  (current tab when idle, new tab when busy or ⌘-activated).
- The presence of `.zTerminal.json` makes a directory **recognized**, so the play
  button appears even in folders with no build manifest.
- **Add from the app:** an "Add bookmark" affordance in the popover writes a new
  bookmark (name, command, icon) back to `.zTerminal.json`, creating the file if
  needed.
- **Theme override:** an optional `theme` block (accent, gradient, mode, terminal
  palette/background, glass tokens) is applied **live and non-destructively** while
  a tab in that project is active, and reverts to the user's global theme when they
  leave. It never overwrites the user's saved Settings.

## Capabilities

### New Capabilities
- `project-bookmarks`: A per-directory `.zTerminal.json` contributing bookmarked commands (with icons) to the Run popover and an optional live, non-persisted theme override.

### Modified Capabilities
- `package-script-runner`: A new task source (`.zTerminal.json` bookmarks) is recognized alongside the manifest ecosystems and its group is listed first; run rows may show a per-task icon.

## Impact

- **New module:** `ZTerminalConfig` (Codable model + load/save) and
  `ZTerminalTaskSource` (a `TaskSource`).
- **RunTask** gains an optional `icon`; `RunPopover`/`RunRow` render it and add the
  "Add bookmark" form.
- **ThemeManager** gains a non-persisted project-theme override layer
  (`effectiveTokens`/`effectiveMode`); rendering call sites read effective values,
  Settings continues editing the user's base theme.
- No new external dependencies.
