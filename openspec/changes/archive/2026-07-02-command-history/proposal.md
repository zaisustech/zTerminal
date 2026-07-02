## Why

Re-running or slightly editing a command you ran earlier is one of the most common terminal
actions, yet zTerminal offers nothing beyond whatever the shell's own Ctrl-R/up-arrow gives
— which is per-shell, invisible until invoked, and lost when you open a fresh tab. Developers
increasingly expect **fish-style inline autosuggestion**: start typing and the terminal shows,
in dim ghost text, the most recent command you ran that starts the same way, ready to accept
in one key. zTerminal already tracks command lifecycle via OSC 133 shell integration, so it is
well positioned to own an app-level, cross-tab command history and surface it inline.

## What Changes

- **Capture every executed command** into an app-owned history store. The existing OSC 133
  shell integration (which already emits command start/end) is extended so the command *text*
  travels with the `command start` marker, giving the app the exact executed command per
  session, independent of the shell's own history file.
- The store is **global** (shared across all tabs and windows), **persisted to disk** so it
  survives restarts, **capped**, and **de-duplicated most-recent-wins** (re-running a command
  moves it to the front rather than adding a duplicate).
- **Inline ghost autosuggestion:** while the user is typing at an idle prompt, the terminal
  shows the most recent history entry that begins with what they have typed, as **dim ghost
  text** after the cursor (a "recent command" placeholder). It updates on every keystroke and
  disappears when nothing matches, when the shell is busy, or inside a full-screen program.
- **Accept with Tab:** when a ghost suggestion is visible, **Tab** fills the rest of the
  suggestion into the prompt. When no suggestion is visible, **Tab** passes through unchanged
  to the shell's own completion — so native completion is never lost.
- Follows the shell convention that a command typed with a **leading space is not stored**,
  giving the user an easy opt-out for sensitive one-offs.

## Capabilities

### New Capabilities
- `command-history`: A global, persisted, de-duplicated store of executed commands, captured
  via the shell integration, that powers an inline dim ghost autosuggestion at the prompt
  accepted with Tab (falling back to shell completion when no suggestion is shown).

### Modified Capabilities
<!-- The OSC 133 shell-integration snippet in ShellColor is extended to carry command text;
     no existing terminal-core requirement changes behavior for the user. -->

## Impact

- **Shell integration (`ShellColor.swift`):** extend the `command start` hook to emit the
  command text — zsh `preexec` already receives it as `$1`, bash exposes `$BASH_COMMAND` in
  the DEBUG trap — encoded (e.g. base64) so arbitrary/multiline commands are transport-safe.
  Also emit the prompt-end marker (OSC 133;B) so the app knows where the user's input begins
  on the current line.
- **New model:** `CommandHistoryStore` (global singleton) — ordered, capped, de-duplicated,
  persisted (e.g. alongside `~/.zTerminal.json`); records a command on the extended marker;
  provides `suggestion(forPrefix:)`.
- **Marker handling:** `CommandMarker` / the OSC 133 handler in `TerminalHostView` gains a
  case carrying the command text; `SessionModel` records it into the store.
- **Autosuggest UI:** a ghost-text overlay on `ZTerminalView` that renders the suggested
  suffix at the cursor in a dim color, driven by the current input line (buffer text from the
  OSC 133;B column to the cursor). Tab-accept handling intercepts Tab only when a suggestion
  is visible and the shell is idle at the prompt.
- **No new external dependencies.**
