## Why

Developers kick off a long build/test/deploy and switch away. Today zTerminal only alerts
on the terminal **bell** — most CLIs don't ring it — so you keep flipping back to check
"is it done yet?". And once it's done, the scrollback doesn't tell you at a glance whether
each command **succeeded** or how long it took. Two small additions close that loop:
notify when a long command finishes in a background tab, and badge each command with its
exit status and duration.

## What Changes

- When a foreground command **finishes in a tab that isn't the focused one** and it ran
  longer than a threshold, post a notification stating the command, its **duration**, and
  whether it **succeeded or failed** (exit code).
- Annotate finished commands in the tab with a compact **exit-status + duration badge**
  (✓ / ✗ and elapsed time).
- Capture command boundaries and exit codes via **shell integration** injected into the
  spawned shell (the same bootstrap that already themes the prompt) — no guessing.
- A **Settings** control for the "long command" threshold (and to toggle the feature).

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `attention-notifications`: In addition to the terminal bell, notify when a long-running command finishes in an unfocused tab (with duration and success/failure), and annotate commands with exit status + duration captured via shell integration.

## Impact

- **Shell integration:** extend `ShellColor`'s injected zsh/bash bootstrap to emit
  semantic marks (OSC 133-style `preexec`/`precmd`) carrying command start and exit code.
- **`SessionModel`:** parse those marks to know when a command starts/ends, its duration
  (already tracked) and exit code; expose the last result.
- **`AttentionManager`:** add a "command finished while unfocused" path alongside the bell,
  gated by the threshold and focus.
- **Setting:** a threshold + on/off in `DesignTokens` (tolerant-decoded).
- No new external dependencies.
