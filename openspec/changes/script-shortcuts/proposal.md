## Why

Developers repeat the same long commands all day — `bun run start`, `docker compose up`,
`./gradlew bootRun`. They want a short, memorable word they can type at the prompt to run
the full command. zTerminal already has **Bookmarks** (per-project named commands you
*click* in the Run popover), but there is no way to define a personal, always-available
**typed** shortcut: type `zaisus`, press Enter, and `bun run start` runs.

## What Changes

- Add a **Scripts** tab to Settings (⌘,) alongside Appearance and Terminal.
- Let the user define **script shortcuts**: a `name` (the word you type, e.g. `zaisus`)
  mapped to a `command` (what actually runs, e.g. `bun run start`).
- Make each shortcut runnable **by typing its name** at the prompt in any zTerminal tab —
  the shortcut is injected into the spawned shell as a real shell alias/function, so the
  shell itself expands it (no fragile keystroke interception).
- Shortcuts are **global** (persisted in Settings, available in every tab and directory),
  distinct from per-project Bookmarks.
- Validate names and safely quote commands so a bad entry can never break shell startup or
  inject unintended commands.

## Capabilities

### New Capabilities
- `script-shortcuts`: User-defined, globally available typed command shortcuts (name → command), edited in a Settings **Scripts** tab and injected into each new shell as an alias/function.

### Modified Capabilities
<!-- None. The existing app-shell Settings surface gains a tab; no behavior of an existing capability changes. -->

## Impact

- **New model:** `ScriptShortcut { name, command }` and a `[ScriptShortcut]` field on the
  persisted settings bag (`DesignTokens`).
- **New UI:** `ScriptsSettings` tab in `SettingsView` (add / edit / delete / reorder rows).
- **Shell init:** extend the existing shell bootstrap (the same path that installs the
  colorful prompt for new tabs) to emit `alias`/function definitions for each shortcut.
- **Scope:** applies to **new** tabs; existing shells are unaffected until reloaded
  (same limitation as the current `colorfulShell` setting).
- No new external dependencies.
