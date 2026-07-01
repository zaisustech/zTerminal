## Context

zTerminal already: injects a shell bootstrap for new tabs (`ShellColor`, zsh ZDOTDIR /
bash rcfile), tracks per-tab start time and a live duration timer (`SessionModel`), knows
if a tab is idle at the prompt, and posts/clears notifications + Dock badge on the bell
(`AttentionManager`, focus-aware). This feature reuses all four; the only genuinely new
capability is knowing **when a command starts/ends and its exit code**.

## Goals / Non-Goals

**Goals:** reliable "command finished" notification for unfocused tabs with duration and
success/failure; per-command exit + duration badge; a configurable threshold; no false
alerts for the focused tab or trivially short commands.

**Non-Goals:** capturing command output/errors; notifying on the focused tab; parsing
arbitrary program logs (that's the separate output-triggers idea).

## Decisions

### Decision: Shell integration marks (OSC 133-style) for command boundaries
Extend the injected bootstrap with `preexec`/`precmd` hooks that emit semantic sequences:
a "command started" mark (with the command line) before execution and a "command finished"
mark carrying `$?` after. This is the robust, well-established way (VS Code, iTerm2, WezTerm
all use OSC 133) — far better than heuristically diffing the screen. It composes with the
existing prompt/OSC 7 injection and is skipped for unsupported shells, exactly like the
prompt theming.

### Decision: Parse marks in `SessionModel`, reuse the duration timer
The terminal data handler recognizes the marks: on start, record the command + start time
(the duration timer already runs); on end, compute elapsed and read the exit code, and
publish a `LastCommandResult { command, duration, exitCode }`.

### Decision: Notify path in `AttentionManager`, gated by focus + threshold
On a "command finished" result, if the tab is **not** the focused one and
`duration >= threshold`, post a notification: title = success/failure, body = command +
duration; increment the Dock badge; clear on return (reusing the existing clear path).
Focused tabs never notify.

### Decision: Badge from the same result
Render a compact ✓/✗ + elapsed badge for the finished command (near the toolbar/scrollback),
driven by `LastCommandResult` — no extra bookkeeping.

### Decision: Threshold + toggle in Settings, tolerant-decoded
Add fields to `DesignTokens` (e.g. `commandFinishNotify: Bool`, `commandFinishThreshold:
Double` seconds) decoded with the existing tolerant decoder.

## Risks / Trade-offs

- **Shell integration off / unsupported shell** → no marks, so the feature is inert (no
  false notifications); the bell path still works. Document that it needs the injected
  bootstrap.
- **Very chatty short commands** → the threshold suppresses them; default a few seconds.
- **Exit code of pipelines** → uses `$?` (last element); acceptable and matches shell
  semantics. `pipefail` users get their configured behavior.

## Migration Plan

Additive; default threshold chosen so only genuinely long commands notify. Existing bell
behavior is unchanged. Rollback = remove the marks, the parse path, and the setting.

## Open Questions

- Should the badge persist per-command in scrollback (like shell-integration decorations)
  or only show the most recent result near the toolbar? (Starting with the latter.)
