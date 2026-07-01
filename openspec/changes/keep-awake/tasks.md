## 1. Power assertion

- [x] 1.1 Add `KeepAwakeMode` (off/whileBusy/always) to `DesignTokens`, persisted
- [x] 1.2 Implement `KeepAwakeManager` wrapping `ProcessInfo.beginActivity` (idempotent setActive)

## 2. Wiring

- [x] 2.1 Evaluate desired state (Always, or While-Busy via `anySessionBusy`) on a 1s ticker + on mode change
- [x] 2.2 Add a Settings control (segmented Off/While Busy/Always)
- [x] 2.3 Add a menu command to cycle/toggle Keep Awake

## 3. Verification

- [x] 3.1 Unit-test the desired-active decision (mode × busy)
- [ ] 3.2 Manual: Always prevents idle sleep; While Busy holds during a long command and releases at prompt
- [x] 3.3 Run `openspec validate keep-awake`
