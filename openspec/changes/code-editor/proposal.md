## Why

With the `file-explorer` sidebar (phase 1), developers can browse a project's tree — but
clicking a file only reveals/opens it externally. The natural next step, and what makes
zTerminal feel like a real IDE, is to **open a file right in the app as a syntax-highlighted,
read-only code viewer**: colorized by language, with line numbers and search. This closes the
inspect-code loop (grep in the terminal → click the file → read it, colored) without leaving
the window. Editing/saving is intentionally deferred (see Non-Goals) so this phase can ship a
fast, correct viewer.

## What Changes

- Opening a text/code file from the sidebar (or via `zterminal://` / a menu) opens it in a
  **code-viewer tab** — reusing the existing tab system (a new `SessionKind.code`, alongside
  `terminal` and `preview`), or split beside the terminal like the Markdown preview.
- **Syntax highlighting** with a color theme that matches the app: language auto-detected from
  the file extension; common languages covered (Swift, JS/TS, JSON, Python, Go, Rust, shell,
  Markdown, YAML, HTML/CSS, …), with a graceful plain-text fallback for unknown types.
- **Line numbers**, soft-wrap toggle, and the file name/path as the tab title.
- **Find in file** — reuse the ⌘F search UX (find/highlight/next-previous) over the viewer.
- **Read-only**: the buffer is not editable; the viewer clearly indicates read-only. Large
  files are handled gracefully (size cap with a notice; no hang).
- **Reload**: a refresh action re-reads the file from disk (it may change underneath).
- Honors the app's light/dark/Blur appearance and font settings.

## Capabilities

### New Capabilities
- `code-editor`: A read-only, syntax-highlighted code viewer that opens files (from the file
  explorer, a URL, or a menu) in a tab or split — language auto-detected, with line numbers,
  soft-wrap, find-in-file, reload, and a large-file cap.

### Modified Capabilities
- `file-explorer`: the sidebar's `onOpenFile` hook now routes text/code files to the code
  viewer instead of the system default app (binary/other files still open externally).

## Impact

- **New UI:** a `CodeViewer` view (an `NSTextView`/`NSViewRepresentable` for performance and
  precise attributed-string rendering, or SwiftUI `Text` for small files) with a line-number
  gutter, hosted as a `.code` session kind in the existing tab/split layout (mirrors how
  `preview` tabs work).
- **New logic:** a `SyntaxHighlighter` that maps a language + source to attributed ranges
  (token colors from the theme), and a `CodeLanguage` detector (extension → language). File
  loading off-main with an encoding guess and a size cap.
- **Reuses:** the tab system + `SessionKind`/`SessionContentView` split pattern (from the
  preview feature), the ⌘F find bar (`SearchController`) for find-in-file, the theme's fonts
  and colors, and the `file-explorer` open hook.
- **No new external dependencies** — highlighting via a built-in rule/regex-based tokenizer
  (or `NSAttributedString` with a bundled grammar), not a third-party engine.

## Non-Goals

- **Editing and saving** — this is a viewer; edit + save (⌘S, dirty state, undo, external-change
  detection) is a deliberate deferred phase-3 change.
- Full language servers / semantic highlighting, autocomplete, diagnostics, formatting.
- Minimap, code folding, multiple cursors, diff view — possible later, out of scope now.
- Rendering binary files as text (they open externally).
