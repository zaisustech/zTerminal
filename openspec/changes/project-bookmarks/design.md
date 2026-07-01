# Design — project-bookmarks

## File format: `.zTerminal.json`

Checked into the project root (the active tab's CWD). All keys optional.

```json
{
  "bookmarks": [
    { "name": "Prebuild",      "command": "expo prebuild --clean",        "icon": "hammer.fill" },
    { "name": "Clean install", "command": "rm -rf node_modules && npm ci", "icon": "trash.fill" },
    { "name": "Start",         "command": "npx expo start",               "icon": "play.fill" }
  ],
  "theme": {
    "mode": "glass",
    "accentHex": "#EC4899",
    "gradientHexes": ["#EC4899", "#F472B6", "#DB2777", "#FB7185", "#F9A8D4"],
    "terminalScheme": "liquidGlass",
    "terminalBackgroundHex": "#160A12"
  }
}
```

- `bookmarks[].icon` is an **SF Symbol** name; missing/unknown → `star.fill`.
- `bookmarks[].command` is run verbatim (shell semantics, `&&`, pipes allowed).
- `theme` mirrors a subset of `DesignTokens` plus `mode`; every field optional and
  merged over the user's base theme.

## Bookmarks as a task source

`ZTerminalTaskSource` implements the existing `TaskSource` protocol so it composes
with the current runner with zero changes to detection flow:

- `matches` → `.zTerminal.json` exists (this is what makes an otherwise-unrecognized
  folder show the play button).
- `detect` → a `RunGroup(title: "Bookmarks", bookmarks: true)` whose tasks map each
  bookmark to a `RunTask(name, rawCommand: command, runCommand: command, icon:)`.

It is placed **first** in `TaskRunner.sources` so the Bookmarks group renders at the
top of the popover. `RunTask` gains an optional `icon`; `RunRow` shows it when set.

## Adding bookmarks from the app

The Bookmarks section renders an "Add bookmark" row that expands an inline form
(name, command prefilled from the filter field, icon menu). Saving calls
`ZTerminalConfig.addBookmark(_:in:)` which loads-or-creates the file, appends, and
writes pretty-printed JSON. The popover recomputes its groups on the next render, so
the new bookmark appears immediately.

## Theme override — live but non-destructive

The hard constraint: a project theme must **not** clobber the user's saved Settings.
Chosen approach — an **effective layer** on `ThemeManager`:

- `@Published var tokens` / `mode` stay the **user/base** values (persisted; Settings
  binds to these, unchanged).
- `@Published private(set) var projectTheme: ProjectTheme?` — the active override,
  **never persisted**.
- Computed `effectiveTokens` = base `tokens` with each non-nil `projectTheme` field
  applied; `effectiveMode` = `projectTheme.mode ?? mode`.
- The existing derived accessors (`accent`, `gradientColors`, `colorScheme`,
  `terminalFont`, `terminalBackground`, `effectiveTerminalBackground`) are rebased on
  the effective values, so most call sites get project theming for free. The few
  rendering sites that read `tokens.x`/`mode` directly switch to
  `effectiveTokens.x`/`effectiveMode`. Settings deliberately keeps editing base.

Application is **active-tab-driven**: a tiny `ProjectThemeApplier` view observes the
active session and calls `theme.applyProjectTheme(from: cwd)` on appear and whenever
the CWD changes. Transitions animate with the existing 0.28s ease, matching Settings.

**Cascade (global → project).** `applyProjectTheme(from:)` resolves the override by
loading two files and layering them, highest priority last:

1. user Settings (persisted `tokens`/`mode`) — the base;
2. the **global** `~/.zTerminal.json` `theme`;
3. the **project** `<cwd>/.zTerminal.json` `theme`.

`ProjectTheme.combine(project, over: global)` merges levels 2–3 into the non-persisted
`projectTheme` override (a field present at a higher level wins; absent fields fall
through). When the CWD has no project theme, the global theme applies; when neither
exists, `projectTheme` is nil and the user's Settings show through. The home directory
is not double-counted (when `cwd == ~`, only the global load runs).

## Alternatives considered

- **Mutating `tokens` directly with a save-suppression flag.** Simpler to wire but
  loses user edits made while an override is active, and is fragile across tab
  switches. Rejected in favor of the clean base/effective split.
- **Per-tab theme (each tab keeps its own).** More flexible but the app renders one
  window chrome/gradient; "active tab wins" is simpler and matches how the toolbar
  already reflects the active session.
