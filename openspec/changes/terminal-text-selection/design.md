## Context

`ZTerminalView` subclasses SwiftTerm's `LocalProcessTerminalView`. Selection itself is
SwiftTerm's built-in behavior; this class adds copy-on-select (`selectionChanged`),
a right-click menu (Copy/Paste/Select All), and drag-and-drop of files. The spec already
requires selection + copy, so the task is to find why the drag no longer selects and
guarantee it.

## Goals / Non-Goals

**Goals:** click-drag selection works at the prompt; word/line selection via
double/triple click; every copy path works; a reliable way to select even when a program
has mouse reporting on.

**Non-Goals:** changing the copy-on-select or context-menu requirements (they stay);
custom selection rendering; rectangular/block selection (could be a later add).

## Likely causes (to confirm during implementation)

1. **Mouse reporting intercepts the drag.** If mouse reporting is active (a TUI, or a
   shell/plugin that enables it at the prompt), SwiftTerm forwards mouse events to the
   program instead of selecting. Fix: honor **Option-drag** as "force local selection,"
   and confirm mouse reporting is actually off at a plain prompt.
2. **The terminal view isn't first responder.** If clicks don't focus the terminal NSView
   (SwiftUI hosting / hit-testing), drags won't select and Cmd+C won't route here. Fix:
   ensure `makeFirstResponder` on click and that the active session's view accepts it.
3. **Drag-and-drop registration swallowing mouseDown.** Verify `registerForDraggedTypes`
   (a drop target) doesn't turn the view into a drag *source* that pre-empts selection.

## Decisions

### Decision: Guarantee selection at the prompt, with an Option-drag override
Spec the behavior the user expects regardless of root cause: drag selects at the prompt;
when mouse reporting is on, Option-drag forces local selection. This is the standard
terminal convention (Terminal.app, iTerm2) and gives a deterministic escape hatch.

### Decision: Keep the existing copy requirements intact
Copy-on-select and the context menu are already specified and implemented; this change
only tightens "Copy and paste" to nail down selection. No behavior is removed.

## Risks / Trade-offs

- **Distinguishing "mouse reporting on" cleanly** — rely on SwiftTerm's terminal mode
  state rather than guessing; Option-drag is the guaranteed fallback either way.
- **Focus stealing** — forcing first responder on click must not disrupt typing into the
  active shell (it shouldn't; the terminal is where typing goes anyway).

## Migration Plan

Behavior-restoring and additive; no persisted state. Rollback is not meaningful (this
returns a core behavior to spec).

## Open Questions

- Should Shift-drag also be accepted as a force-local-selection modifier (some users
  expect Shift)? Leaning Option only, matching macOS Terminal.app.
