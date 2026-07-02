## Context

zTerminal embeds SwiftTerm's `LocalProcessTerminalView`. The shell owns line editing;
the app already injects a shell-integration snippet (`ShellColor.swift`) emitting OSC 7 (CWD)
and OSC 133 C/D (command lifecycle), handled by an OSC handler in `TerminalHostView` that
feeds `SessionModel`. The app also already discovers Bun scripts (`PackageRunner` reads
`package.json` `scripts` and detects the `bun` manager). What's missing is (a) a way to know
where the user's input begins on the prompt line and (b) a dim overlay that draws a suggested
suffix at the cursor. Both are the shared machinery the unimplemented `command-history` change
also needs, so we build them here and expose a pluggable source list.

A SwiftTerm API survey established the exact (and limited) surface we can use — several
relevant methods are sealed. The decisions below are shaped by that.

## Goals / Non-Goals

**Goals:** a reusable inline dim ghost-text overlay at an idle prompt; OSC 133;B prompt-input
tracking; a Bun script suggestion source (complete `package.json` script names in
`bun run <script>` / `bun <script>`); Tab accepts, Tab falls through to shell completion when
no ghost; graceful degradation (no marker / unknown input → simply no ghost, never breakage);
a pluggable `GhostSuggesting` source list so `command-history` reuses the overlay.

**Non-Goals:** multi-candidate dropdowns; fuzzy/substring matching (prefix only); completing
Bun flags/subcommand names; multi-line/wrapped prompt input (v1 tracks single-row input);
suggestions when the user runs a non-default shell prompt that rebuilds `PROMPT` each render
(the marker is lost → ghost simply hides); the persisted command-history store (its own change).

## Decisions

### Decision: Intercept Tab with an `NSEvent` local monitor, not a `keyDown` override
SwiftTerm's `keyDown(with:)` and `doCommand(by:)` are `public override` — **not `open`** — so a
subclass in our module cannot override them (a plain Tab is routed through `doCommand` →
`insertTab` → `send("\t")`, never through the `open` `insertText`). We therefore intercept with
`NSEvent.addLocalMonitorForEvents(matching: .keyDown)`, exactly as the existing Option-drag
`installSelectionMonitor` does. The monitor consumes Tab (returns nil) **only** when this view
is first responder, the shell is idle at the prompt, and a ghost suffix is currently shown;
otherwise it returns the event so the shell's native completion is untouched. It also hides the
ghost on cursor-navigation keys (arrows/Home/End) to avoid drawing a stale suffix.

### Decision: Position the overlay from the public `caretFrame`
Cell metrics (`cellDimension`) are internal and there is no public (col,row)→rect API. But
`caretFrame: CGRect` (public) is the cursor cell's rect in the view's coordinate space and its
size *is* the cell size. Since the ghost is drawn starting at the cursor, we place a
click-through `GhostTextView` subview at `caretFrame.origin` with width `cellWidth ×
suffix.count` and the cell height — no reliance on internal math.

### Decision: Know the input line via OSC 133;B + public buffer reads
Extend the integration to emit OSC 133;B at prompt end. The OSC handler snapshots the
prompt-end position synchronously (`getCursorLocation()` + `buffer.yDisp` for the absolute
row). The current input is then `getLine(row: cursorRow)?.translateToString(startCol:
promptCol, endCol: cursorX)` — all public API. If the cursor row differs from the recorded
prompt row (wrapped/multi-line) or no marker was seen, we hide the ghost.

### Decision: Recompute on `rangeChanged` / `scrolled` / `bufferActivated`
There is no "cursor moved" callback and `updateDisplay`/`updateCursorPosition` are internal.
We subclass and override the `open` delegate methods `rangeChanged` (with `notifyUpdateChanges
= true`), `scrolled`, and `bufferActivated`, recomputing the ghost after the buffer settles
(so echoed keystrokes are already reflected). Full-screen apps are gated by
`terminal.isCurrentBufferAlternate` and busy state by the existing `SessionModel.isIdleAtPrompt`.

### Decision: Pluggable `GhostSuggesting` sources; Bun first
`SuggestionEngine` holds an ordered `[GhostSuggesting]` and returns the first non-empty suffix.
`BunScriptSource` fast-rejects non-`bun` input, loads the CWD's `package.json` scripts via
`PackageRunner` (cached by CWD), ranks them (`dev`/`start`/… first), and delegates to the pure
`BunCompletion.ghostSuffix(forInput:scripts:)`. `command-history` later adds a second source.

### Decision: Keep matching logic pure and unit-tested
`BunCompletion` is a pure enum: `(input, scripts) → suffix?`. It handles the two script slots,
strict-longer prefix semantics (no self-ghost), ranking, and rejects non-script positions. All
covered by `BunCompletionTests` with no SwiftTerm dependency — the risky terminal glue stays
thin.

## Risks / Trade-offs

- **Sealed SwiftTerm input methods** — mitigated by the local-event-monitor approach already
  proven in this codebase for mouse events.
- **Custom prompts** — appending the B marker to `PROMPT`/`PS1` works for static prompts; a
  prompt framework that rebuilds `PROMPT` each render drops the marker, so the ghost simply
  doesn't appear. Degradation, not breakage.
- **Overlay placement across scroll/resize/wrap** — recomputed from live `caretFrame`/cursor on
  each change; hidden whenever the input line can't be resolved rather than drawn wrong.
- **Per-keystroke work** — gated by `isIdleAtPrompt` and a CWD-keyed script cache, so typing at
  a prompt does one buffer read + a small in-memory match; file IO only on CWD change.

## Migration Plan

Additive. The extended integration is backward compatible (an older app ignores the B marker;
the new app tolerates its absence → no ghost). Rollback = revert the `ShellColor` B-marker
line, remove `Suggest/*`, the `CommandMarker.promptEnd` case, and the overlay wiring; existing
OSC 7 / 133 C-D behavior is untouched.

## Open Questions

- Should a Settings toggle disable autosuggestion (and later choose accept key)? (Leaning: add
  a toggle when `command-history` lands and both sources are live.)
- Should completion also cover other detected managers' scripts (npm/pnpm/yarn) under their own
  command words? (Leaning: yes as follow-up sources once the Bun path is validated.)
