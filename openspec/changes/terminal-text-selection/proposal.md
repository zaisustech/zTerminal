## Why

`terminal-core` already specifies selecting text with the mouse, Cmd+C / context-menu
Copy, and copy-on-select — but in practice **text can no longer be selected in the
terminal**: click-drag highlights nothing, so there is nothing to copy. This is a
regression that breaks a table-stakes terminal behavior (grab a path, an error, a URL).
This change re-establishes and tightens the spec so mouse selection is guaranteed at the
shell prompt, and clarifies the interaction with programs that enable mouse reporting.

## What Changes

- Guarantee **mouse selection at the shell prompt**: click-drag selects a range,
  double-click selects a word, triple-click selects a line.
- Keep **all copy paths** working on a selection: Cmd+C, the right-click Copy item, and
  automatic copy-on-select.
- Define the **mouse-reporting override**: when a running program has enabled mouse
  reporting (a TUI/full-screen app), holding **Option (⌥)** while dragging SHALL force
  local text selection instead of forwarding the mouse events to the program — so the user
  can always select text.
- Ensure the terminal view takes **keyboard/mouse focus on click** so selection and Cmd+C
  are routed to it.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `terminal-core`: The "Copy and paste" requirement is tightened to guarantee mouse selection at the prompt (drag / double / triple click), keep every copy path working, and force local selection via Option-drag when a program has enabled mouse reporting.

## Impact

- **`ZTerminalView` / hosting:** verify the terminal becomes first responder on click and
  that selection gestures reach SwiftTerm; ensure Option-drag maps to local selection when
  mouse reporting is active; confirm nothing (drag-and-drop registration, hit-testing)
  swallows the selection drag.
- Spec-only in this change; the code fix follows the tasks below.
- No new external dependencies.
