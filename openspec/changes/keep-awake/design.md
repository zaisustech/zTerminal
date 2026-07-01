## Context

zTerminal already knows when a tab is "busy" (`SessionModel.isIdleAtPrompt`, via the
tty foreground process group). We reuse that to drive an optional power assertion.

## Goals / Non-Goals

**Goals:** prevent idle *system* sleep while working; simple Off/While-Busy/Always
control; persisted; no third-party deps.

**Non-Goals:** keeping the *display* awake (too aggressive); caffeinate-style CLI;
per-tab assertions.

## Decisions

### Decision: `ProcessInfo.beginActivity` over IOKit
Use `ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled], reason:)`
and retain the returned token; end it to release. Rationale: high-level, safe,
auto-released if the process dies — simpler than raw `IOPMAssertionCreate`.

### Decision: `KeepAwakeManager` singleton holds the single token
One assertion for the whole app. `setActive(true/false)` begins/ends it idempotently.

### Decision: Mode stored in `DesignTokens` (persisted settings bag)
`keepAwake: KeepAwakeMode` (off/whileBusy/always). Settings + a menu command bind to
it. A lightweight ticker (reusing the per-session idle check, ~1s) recomputes the
desired assertion state for While Busy; Always/Off are static.

### Decision: While-Busy evaluation
Desired-active = `mode == .always || (mode == .whileBusy && anySessionBusy)`, where
`anySessionBusy = sessions.contains { !$0.isIdleAtPrompt }`. Evaluated on a 1s timer
and on mode change.

## Risks / Trade-offs

- **User forgets it's on (Always)** → surface state in the menu (checkmark) and Settings.
- **Busy detection false-negative** (idle check unavailable) → defaults to idle, so While Busy simply won't hold; Always is the guaranteed option.

## Migration Plan

Additive; default Off. Rollback = remove the setting.

## Open Questions

- Should While Busy be the default instead of Off? (Currently Off to avoid surprise.)
