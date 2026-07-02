## Context

zTerminal already injects a shell-integration snippet (`ShellColor.swift`) into every session:
zsh uses `add-zsh-hook preexec/precmd`, bash uses a DEBUG trap + `PROMPT_COMMAND`, together
emitting OSC 133 `C` (command start) and `D;<exit>` (command end). `TerminalHostView`
registers an OSC 133 handler that parses these into `CommandMarker` cases and updates
`SessionModel`. Crucially, the command text is *available at the start hook* — zsh `preexec`
gets it as `$1`, bash has `$BASH_COMMAND` — so capturing executed commands is an extension of
plumbing that already exists, not new scraping of the screen. This is the reliable source: it
is exactly what the shell is about to run, correctly handling aliases, quoting, and multiline.

## Goals / Non-Goals

**Goals:** capture every executed command app-side; one global, persisted, de-duplicated,
capped history; inline dim ghost autosuggestion (most-recent prefix match) at an idle prompt;
Tab accepts the suggestion, and Tab falls through to shell completion when there is none;
leading-space opt-out.

**Non-Goals:** a full history browser/palette UI (that can layer on later, or fold into the
command palette); fuzzy or substring suggestion (prefix match only, like fish); secret
redaction/scrubbing beyond the leading-space rule; syncing or importing the shell's existing
`~/.zsh_history`; multi-suggestion dropdowns; suggestions while a full-screen program runs.

## Decisions

### Decision: Capture the command from the shell integration, not the screen
Extend the `command start` hook to emit the command text alongside the OSC 133;C marker,
base64-encoded so newlines, quotes, and control bytes survive transport (payload e.g.
`133;C;<base64>`). The OSC handler decodes it and records it. Reading the command from the
integration (zsh `$1` / bash `$BASH_COMMAND`) is exact and avoids the ambiguity of parsing
wrapped prompt rows out of the grid buffer.

### Decision: One global, persisted, de-duplicated store
`CommandHistoryStore` is a global singleton shared by all tabs and windows. On record it
removes any existing identical entry and inserts at the front (most-recent-wins dedupe), caps
the list (e.g. a few thousand entries), and persists to disk so a freshly opened tab already
has suggestions. Empty commands, the integration's own internal commands (the `__zt_*` /
`_zt_*` helpers), and commands entered with a leading space are never recorded.

### Decision: Prefix-match suggestion, most-recent first
`suggestion(forPrefix:)` returns the most recent stored command that has the typed text as a
prefix and is longer than it (fish semantics). The ghost shows only the *remaining* suffix.
Empty input yields no suggestion (we do not surface a suggestion until the user types).

### Decision: Know the current input line via OSC 133;B
To render the ghost at the right place and to know the prefix, the app must know where the
user's input starts. Extend the integration to emit OSC 133;B (prompt end) so the app records
the prompt-end cursor column; the current input is then the buffer text from that column to
the cursor on the current (possibly wrapped) line. The ghost suffix is drawn as an overlay
starting at the cursor — it is never written to the PTY until accepted.

### Decision: Ghost text is an app overlay, not injected input
The suggestion is rendered by an overlay layer positioned at the cursor in a dim color; it is
not sent to the shell and does not occupy the shell's line buffer. This keeps the shell's own
line editor authoritative and means an un-accepted suggestion has zero side effects.

### Decision: Tab accepts only when a suggestion is visible; otherwise passes through
Tab handling checks: is the shell idle at the prompt (`isIdleAtPrompt`) and is a ghost
suggestion currently shown? If yes, consume Tab and send the suggestion's remaining suffix to
the shell (so the line now reads the full command); the caret ends at the line's end. If no,
do not consume Tab — forward it so the shell's native completion runs exactly as today.

### Decision: Suppress suggestions when they cannot be trusted
No ghost is shown while the shell is busy running a command, while a full-screen program owns
the alternate screen, or when the input line cannot be determined (no recent OSC 133;B). This
avoids drawing stale ghosts over program UI or mid-command output.

## Risks / Trade-offs

- **Ghost placement accuracy** — the overlay must track the cursor across typing, wrapping,
  scrolling, and resize. Mitigate by recomputing from the live cursor position on each render
  and hiding the ghost whenever the input line can't be resolved rather than drawing it wrong.
- **Tab collision** — intercepting Tab risks stealing the shell's completion. Mitigated by
  consuming Tab *only* when idle-at-prompt AND a suggestion is visible; every other case falls
  through untouched. Documented behavior; can be made rebindable later.
- **Integration edits affect every session** — a bug in the extended snippet degrades all
  shells. Keep the additions guarded (same `2>/dev/null` / armed-flag patterns already used),
  and ensure the OSC handler ignores malformed/oversized payloads.
- **Privacy** — commands (which may include secrets on the command line) are written to disk.
  Mitigated by the leading-space opt-out and by documenting the store's location; full
  redaction is a non-goal here. See Open Questions for an optional disable/clear control.
- **Non-integrated shells** — if a user replaces the shell so the integration doesn't load,
  capture stops (no markers). The feature degrades to "no suggestions," never to breakage.

## Migration Plan

Additive. New persisted file (absent → empty history). The extended integration is backward
compatible: an older app ignores the new `B`/command-text payloads, and the new app tolerates
markers without command text (records nothing extra). Rollback = revert the `ShellColor`
additions, remove the store, overlay, and Tab handling; existing exit/duration markers keep
working.

## Open Questions

- Should there be a Settings toggle to disable capture and a "Clear command history" action
  (and should ⌘R / a history browser be a follow-up that reads this same store)? (Leaning:
  add a disable toggle + clear action now; defer the browser to the command palette.)
- Should suggestions be scoped/biased by current directory (prefer commands last run in this
  CWD) rather than purely global-recency? (Leaning: global-recency first; revisit if noisy.)
- Cap size and trim policy — a few thousand entries by recency; confirm the number.
