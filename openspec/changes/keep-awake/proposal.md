## Why

AI CLI agents (Claude Code, etc.) run long tasks — builds, tests, multi-step
edits — during which users often switch away. If the Mac sleeps, the run stalls
or the SSH/session state suffers. Users want to keep the machine awake while a
terminal is actually working, without disabling sleep system-wide.

## What Changes

- Add a **Keep Awake** option that holds a power assertion to prevent **idle system
  sleep** while enabled (the display may still sleep).
- Expose it as a **Settings toggle** and a **menu command**, persisted across launches.
- Offer an **"only while busy"** behavior so the assertion is held only when a tab
  is running a foreground program, and released when all tabs return to a prompt.

## Capabilities

### New Capabilities
- `keep-awake`: Prevent idle system sleep while a terminal session is working (manual toggle or automatic while-busy), surfaced in Settings and the menu.

### Modified Capabilities
<!-- None. -->

## Impact

- **New module:** `KeepAwakeManager` wrapping `ProcessInfo.beginActivity`.
- **Setting:** a persisted `keepAwake` mode; a View/Session menu command.
- No new external dependencies.
