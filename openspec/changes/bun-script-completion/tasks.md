## 1. Prompt-input tracking (OSC 133;B)

- [x] 1.1 `ShellColor` zsh: append the OSC 133;B (prompt-end) marker to `PROMPT` after the user's rc is sourced, wrapped `%{…%}` (zero-width)
- [x] 1.2 `ShellColor` bash: append the OSC 133;B marker to `PS1`, wrapped `\[…\]` (zero-width)
- [x] 1.3 `CommandMarker` gains a `.promptEnd` case (`"B"`); OSC 133 handler in `TerminalHostView` routes it to the view
- [x] 1.4 `ZTerminalView.notePromptEnd()` snapshots the prompt-end column + absolute row synchronously from the buffer

## 2. Suggestion engine + package-manager-aware source

- [x] 2.1 Pure `ScriptCompletion.ghostSuffix(forInput:managers:scripts:)` — completes for a detected manager only; `<mgr> run <script>` for all, plus bare `<mgr> <script>` for managers with `runsScriptsBare` (bun/pnpm/yarn, not npm); strict-longer prefix, `ranked(_:)`
- [x] 2.2 `GhostSuggesting` protocol + `SuggestionEngine` (ordered sources, first non-empty suffix wins)
- [x] 2.3 `ScriptCompletionSource`: fast-reject non-manager command words, load CWD managers + scripts via `PackageRunner` (detected from lockfile/`packageManager`, cached by CWD), rank, delegate to `ScriptCompletion`; `PackageManager.runsScriptsBare` added

## 3. Ghost overlay

- [x] 3.1 `GhostTextView`: click-through NSView drawing dim text in the terminal font
- [x] 3.2 `ZTerminalView.refreshGhost()`: derive input line (prompt col → cursor via `translateToString`), query engine, position via `caretFrame`; hide when busy, on the alternate screen, or when the input line can't be resolved
- [x] 3.3 Recompute on `rangeChanged` (with `notifyUpdateChanges = true`), `scrolled`, `bufferActivated`

## 4. Accept & fall-through

- [x] 4.1 `installKeyMonitor()` (NSEvent local monitor): consume Tab only when first responder + idle + a ghost is visible, sending the suffix to the PTY
- [x] 4.2 When no ghost is visible, forward Tab untouched; hide the ghost on cursor-navigation keys

## 5. Wiring

- [x] 5.1 `TerminalHostView` builds the engine `[ScriptCompletionSource()]`, wires `isIdleAtPrompt`, sets `notifyUpdateChanges = true`, installs the key monitor

## 6. Verification

- [x] 6.1 `swift build`
- [x] 6.2 Unit-test `ScriptCompletion` (manager-aware slots, lockfile gate, npm-needs-`run`, prefix/strict-longer, ranking, rejects) — `ScriptCompletionTests`
- [x] 6.3 Unit-test `CommandMarker.parse` for the `B` (prompt-end) marker
- [ ] 6.4 Manual (GUI, not automatable headless): in a project, type `<mgr> run d`/bare → dim suffix; Tab fills it; Tab with no ghost still runs shell completion; wrong-manager (lockfile gate) shows nothing; no ghost in `vim` or while a command runs
- [x] 6.5 `openspec validate bun-script-completion --strict`
