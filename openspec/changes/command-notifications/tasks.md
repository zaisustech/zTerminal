## 1. Shell integration marks

- [ ] 1.1 Extend `ShellColor` zsh bootstrap: `preexec`/`precmd` hooks emit command-start and command-end (with `$?`) marks
- [ ] 1.2 Same for bash (`PROMPT_COMMAND` / `DEBUG` trap); skip for unsupported shells
- [ ] 1.3 Compose with existing prompt/OSC 7 injection; keep a bad entry non-fatal

## 2. Parse & model

- [ ] 2.1 Recognize the marks in the terminal data path; ignore them in rendered output
- [ ] 2.2 On start: record command + start; on end: compute duration, read exit code
- [ ] 2.3 Publish `LastCommandResult { command, duration, exitCode }` on `SessionModel`

## 3. Notify & badge

- [ ] 3.1 `AttentionManager`: on finish, notify when tab is unfocused and `duration >= threshold` (success/failure + duration); update Dock badge; clear on return
- [ ] 3.2 Render a compact ✓/✗ + duration badge for the last command
- [ ] 3.3 Add threshold + on/off to `DesignTokens` (tolerant-decoded) + a Settings control

## 4. Verification

- [ ] 4.1 `swift build`
- [ ] 4.2 Unit-test mark parsing (start/end/exit code) and the notify decision (focus × duration × threshold)
- [ ] 4.3 Manual: run a long command in a background tab → notification with duration + success/failure; badge shows ✓/✗; focused tab does not notify
- [ ] 4.4 Run `openspec validate command-notifications --strict`
