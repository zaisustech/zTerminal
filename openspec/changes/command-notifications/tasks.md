## 1. Shell integration marks

- [x] 1.1 zsh emits OSC 133 command-start/end marks (with `$?`) — shipped via `ShellColor` + the `command-history` change; parsed by `CommandMarker`
- [x] 1.2 bash equivalent (DEBUG trap / prompt hooks); unsupported shells skip
- [x] 1.3 Composed with the existing prompt/OSC 7 injection; a bad entry is non-fatal

## 2. Parse & model

- [x] 2.1 Marks recognized in the OSC 133 handler (`TerminalHostView`); not rendered
- [x] 2.2 On start: record command + start time; on end: compute duration + exit code (`SessionModel.noteCommandStart/End`, now keeping the running command text)
- [x] 2.3 `CommandResult { command, duration, exitCode }` published as `SessionModel.lastCommand` (added `command`)

## 3. Notify & badge

- [x] 3.1 `AttentionManager.commandFinished(for:result:)` — notifies (✓/✗ + command + duration) when the tab is unfocused and `duration >= threshold`; reuses the Dock-badge/notification path
- [x] 3.2 Compact ✓/✗ + duration badge for the last command (existing `commandStatus` toolbar segment)
- [x] 3.3 `DesignTokens.notifyOnCommandFinish` + `commandNotifyThreshold` (tolerant-decoded) + Settings → Terminal → Notifications control; wired to `AttentionManager` from `RootView`

## 4. Verification

- [x] 4.1 `swift build` — green
- [x] 4.2 `CommandNotificationTests` (6) — the notify decision (focus × duration × threshold × enabled) + result carries the command; `CommandMarker` parse already covered by `CommandMarkerTests`
- [ ] 4.3 **Manual/GUI QA** — needs the app run (blocked here by the multi-display/Spaces screenshot issue): long command in a background tab → notification with ✓/✗ + duration; focused tab does not notify; threshold + on/off respected
- [x] 4.4 `openspec validate command-notifications --strict`
