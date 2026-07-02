## Why

zTerminal already knows a project's **Bun scripts** — `PackageRunner` detects the `bun`
package manager and reads `package.json` `scripts` for the play/run popover. But at the
prompt, a developer still types `bun run <script>` from memory, with no help from the app
that already has the answer on screen. Meanwhile the (unimplemented) `command-history` change
specifies a general **inline dim ghost-text autosuggestion** at the prompt. Rather than build
that overlay twice, this change builds the ghost-text engine **once**, with the project's Bun
scripts as its **first suggestion source** — so typing `bun run d` shows a dim `ev` you accept
with Tab. `command-history` then plugs its recent-command source into the same overlay.

## What Changes

- **Inline ghost-text overlay (shared infrastructure):** while the shell is idle at the
  prompt, the terminal renders a dim suggestion suffix after the cursor. It is a visual
  overlay only — never sent to the PTY until accepted — and hides when the shell is busy, on
  the alternate screen, or when the current input line can't be resolved.
- **Prompt-input tracking:** the shell integration emits an OSC 133;B (prompt-end) marker so
  the app knows the column where the user's input begins; the current input line is the buffer
  text from that column to the cursor.
- **Bun script suggestion source:** when the input is `bun run <partial>` or `bun <partial>`,
  the overlay suggests the remaining characters of the most-relevant matching `package.json`
  script in the current directory (Bun runs `package.json` scripts directly, so both forms are
  valid). Preferred scripts (`dev`, `start`, …) rank first for the empty-prefix suggestion.
- **Accept with Tab:** when a suggestion is visible, Tab fills the remaining text into the
  prompt. When none is visible, Tab passes through untouched to the shell's native completion.
- **Pluggable sources:** the engine takes an ordered list of suggestion sources so
  `command-history` (and future sources) reuse the same overlay and accept path.

## Capabilities

### New Capabilities
- `bun-script-completion`: an inline, dim ghost-text autosuggestion at the prompt that
  completes Bun `package.json` script names (accepted with Tab, falling back to shell
  completion), built on a reusable ghost-text overlay + OSC 133;B prompt-input tracking that
  other suggestion sources can plug into.

### Modified Capabilities
<!-- The OSC 133 shell-integration snippet in ShellColor gains a prompt-end (B) marker; no
     existing terminal-core requirement changes user-visible behavior. -->

## Impact

- **Shell integration (`ShellColor.swift`):** append the OSC 133;B marker at prompt end for
  zsh (PROMPT) and bash (PROMPT_COMMAND), guarded like the existing OSC 7 / 133 emitters.
- **Marker handling (`SessionModel` / `TerminalHostView`):** `CommandMarker` gains a
  `.promptEnd` case; the OSC 133 handler records the prompt-end cursor column on the session.
- **New pure logic (`Suggest/BunCompletion.swift`):** turns `(input, scripts)` into a ghost
  suffix — fully unit-tested, no SwiftTerm dependency.
- **New engine (`Suggest/SuggestionEngine.swift`):** an ordered list of `GhostSuggesting`
  sources; `BunScriptSource` reads scripts for the CWD (via `PackageRunner`) with a small
  cache keyed by CWD.
- **New overlay (`Suggest/GhostTextOverlay.swift` + `ZTerminalView`):** draws the suffix at
  the cursor cell in a dim color, recomputed from the live buffer; Tab-accept in `keyDown`.
- **No new external dependencies.**

## Coordination with `command-history`

This change **supersedes the autosuggest/overlay portion** of `command-history` (its tasks
3.x "Inline ghost autosuggestion" and 4.x "Accept & fall-through", plus the OSC 133;B / input
tracking parts of 1.x). `command-history` retains its own scope — capturing commands into a
persisted, de-duplicated store — and becomes a **second `GhostSuggesting` source** feeding this
overlay. When `command-history` is implemented, both sources are consulted in order.
