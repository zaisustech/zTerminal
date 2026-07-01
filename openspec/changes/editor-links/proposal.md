## Why

Developers stare at paths and errors all day — `Sources/App/Foo.swift:42:10`, a stack
trace, a test failure location. Today the only way to open one is to select the text,
copy it, switch to the editor, and navigate by hand. zTerminal already reveals the CWD in
Finder from the status bar; the missing sibling is **jump straight to a file (and line)
in your editor**.

## What Changes

- **Cmd-click a file path** in the terminal to open it in the user's editor. When the
  path carries a `:line[:col]` suffix (compiler/linter/test output), open at that
  location.
- Paths are **resolved against the tab's current directory** so relative paths from build
  output work; only existing files are treated as links.
- Add an **"Open in editor"** button to the bottom status bar (next to reveal-in-Finder)
  that opens the current directory in the editor.
- A **Settings** control to choose the editor — VS Code, Xcode, Cursor, or a custom
  command — used for both actions.

## Capabilities

### New Capabilities
- `editor-integration`: Open files (optionally at a line/column) and the current directory in the user's chosen editor, from cmd-click in the terminal and a status-bar button.

### Modified Capabilities
<!-- None. Mirrors the existing finder-integration reveal action without changing it. -->

## Impact

- **New module:** `EditorLauncher` — resolves a path against the CWD, parses an optional
  `:line:col`, and launches the configured editor (`code -g <file>:<line>:<col>`,
  `cursor -g …`, `xed --line <n> <file>`, or a custom template).
- **Terminal view:** detect the path/token under the pointer on ⌘-click (via SwiftTerm
  hyperlinks/OSC 8 where present, plus a path heuristic) and route to `EditorLauncher`.
- **Status bar:** an "Open in editor" button in `BottomToolbar`.
- **Setting:** an `editor` preference in `DesignTokens` (tolerant-decoded like the rest).
- No new external dependencies.
