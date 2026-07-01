## 1. Diagnose

- [x] 1.1 Confirm mouse reporting is off at a plain shell prompt (SwiftTerm terminal mode state)
- [x] 1.2 Confirm the terminal NSView becomes first responder on click (selection + Cmd+C route to it)
- [x] 1.3 Confirm drag-and-drop registration / hit-testing does not swallow the selection drag
      → Root cause: SwiftTerm's `mouseDragged` skips selection when `allowMouseReporting` (default true) and `mouseMode != .off`, with no built-in Option bypass; its `mouseDown/Up` are not `open`.

## 2. Fix

- [x] 2.1 Ensure click-drag selects at the prompt (range), double-click a word, triple-click a line (SwiftTerm built-in when mouse mode off)
- [x] 2.2 Force local selection on Option-drag when a program has enabled mouse reporting (local NSEvent monitor toggles `allowMouseReporting` for the gesture; also makes the view first responder)
- [x] 2.3 Cmd+C, right-click Copy, and copy-on-select all place the selection on the clipboard (existing paths, unchanged)

## 3. Verification

- [x] 3.1 `swift build` (and `swift test` — 78 pass)
- [ ] 3.2 Manual: at a prompt, drag-select text and Cmd+C → clipboard has it; double/triple click select word/line
- [ ] 3.3 Manual: in a TUI with mouse reporting, Option-drag selects locally while plain drag reaches the program
- [x] 3.4 Run `openspec validate terminal-text-selection --strict`
