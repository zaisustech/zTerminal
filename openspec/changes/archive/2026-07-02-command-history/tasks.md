## 1. Capture executed commands

- [x] 1.1 Extend `ShellColor` zsh integration: `preexec` emits the command (`$1`) as `133;C;<base64>`, and emit `133;B` at prompt end
- [x] 1.2 Extend `ShellColor` bash integration: DEBUG trap emits `$BASH_COMMAND` as `133;C;<base64>`; emit `133;B` from `PROMPT_COMMAND`; keep skipping internal `__zt_*` commands
- [x] 1.3 Extend `CommandMarker` + the OSC 133 handler in `TerminalHostView` to decode the command-text payload and the `B` (prompt-end) marker
- [x] 1.4 `SessionModel` records the decoded command into the store and remembers the prompt-end cursor column

## 2. History store

- [x] 2.1 `CommandHistoryStore` global singleton: ordered, capped, most-recent-wins de-duplication
- [x] 2.2 Persist to disk (alongside `~/.zTerminal.json`); load on launch; tolerate missing/corrupt file (→ empty)
- [x] 2.3 Never record: empty commands, internal `_zt_*`/`__zt_*` helpers, or commands entered with a leading space
- [x] 2.4 `suggestion(forPrefix:)` → most recent entry that has the prefix and is strictly longer (nil for empty input)

## 3. Inline ghost autosuggestion

- [x] 3.1 Derive the current input line from the buffer (OSC 133;B column → cursor) on each keystroke *(provided by the shared SuggestionEngine/GhostTextView from bun-script-completion; history plugs in as CommandHistorySource)*
- [x] 3.2 Ghost-text overlay on `ZTerminalView`: render the suggestion's remaining suffix at the cursor in a dim color; not sent to the PTY *(provided by the shared SuggestionEngine/GhostTextView from bun-script-completion; history plugs in as CommandHistorySource)*
- [x] 3.3 Update/hide the ghost on typing, cursor move, scroll, and resize; hide when the shell is busy, on the alternate screen, or when the input line can't be resolved *(provided by the shared SuggestionEngine/GhostTextView from bun-script-completion; history plugs in as CommandHistorySource)*

## 4. Accept & fall-through

- [x] 4.1 Tab handling: when idle-at-prompt AND a suggestion is visible, consume Tab and send the remaining suffix to the shell *(provided by the shared SuggestionEngine Tab handling)*
- [x] 4.2 When no suggestion is visible, do NOT consume Tab — forward it so the shell's native completion runs unchanged *(provided by the shared SuggestionEngine Tab handling)*

## 5. Verification

- [x] 5.1 `swift build`
- [x] 5.2 Unit-test `CommandHistoryStore`: dedupe/reorder on re-run, cap/trim, leading-space and internal-command exclusion, `suggestion(forPrefix:)` recency + prefix semantics
- [x] 5.3 Unit-test the extended `CommandMarker` parse (base64 command payload, `B` marker, malformed payloads ignored)
- [x] 5.4 Manual: run several commands; open a new tab and confirm suggestions appear from the persisted store; typing a prefix shows dim ghost text; Tab fills it; Tab with no ghost still triggers shell completion; a leading-space command is not stored; no ghost inside `vim`
- [x] 5.5 `openspec validate command-history --strict`
