## 1. Language detection + highlighter

- [x] 1.1 `CodeLanguage` enum + `detect(url:)`/`detect(filename:)` (extension → language; shebang fallback; else plainText) — pure (`Sources/zTerminal/CodeEditor/CodeLanguage.swift`)
- [x] 1.2 `SyntaxHighlighter`: per-language token rules (keywords/strings/comments/numbers) → attributed ranges; theme `Palette`; plain-text fallback
- [x] 1.3 Comment/string masking so keywords inside them aren't re-highlighted; a `highlightByteLimit` (2 MB) above which highlighting is skipped
- [x] 1.4 Unit tests: `CodeLanguageTests` (5) + `SyntaxHighlighterTests` (6) — detection, token kinds, keyword-in-string/comment, plain-text, ordering

## 2. Viewer

- [x] 2.1 `CodeTextView` (`NSViewRepresentable` over a non-editable, selectable `NSTextView`) rendering the highlighted attributed string
- [x] 2.2 Line-number gutter (`LineNumberRulerView`); soft-wrap toggle; theme font + read-only affordance; select/copy work
- [x] 2.3 `CodeDocument`: off-main load, UTF-8→Latin-1 decode fallback, large-file cap + notice, decode-failure message, Reload

## 3. Integration

- [x] 3.1 `SessionKind.code`; render `CodeViewerView` in `SessionContentView` (dedicated `.code` tab, and split beside a terminal via `session.code`)
- [x] 3.2 `WindowModel.openCode(url:split:)` + `WindowRouter.openCode` — split beside the active terminal, tab fallback
- [x] 3.3 File-explorer `onOpenFile` routes text/code → `openCode(split:)`, binaries → `NSWorkspace.open` (binary-extension denylist)
- [x] 3.4 ⌘F in a `.code` tab / code split → the `NSTextView` find bar (app ⌘F routing posts `.codeFind`; the focused viewer shows its find interface)

## 3b. Multiple tabs

- [x] 3b.1 `CodePanelModel` holds multiple `CodeDocument`s with an active tab (mirrors `PreviewPanelModel`); `open` adds/focuses, `close` removes, `moveDoc` reorders
- [x] 3b.2 `SessionModel.code` is now a `CodePanelModel`; `WindowModel.openCode` uses the single-split-panel policy (opening a file adds a tab to the existing panel; re-open focuses; tab fallback when no terminal)
- [x] 3b.3 `CodePanelView` — tab strip (chips, close ✕, drag-reorder) + the active doc's `CodeViewerView`; last-tab-close dismisses the panel; Markdown source↔preview toggle preserved per-doc
- [x] 3b.4 Tab switching: ⌘1–9 and ⌃1–9 (window tabs) — added ⌃ variants per request

## 4. Verification

- [x] 4.1 `swift build` — green
- [x] 4.2 Unit tests from 1.4 green (11 code-editor tests; 16 with file-tree)
- [ ] 4.3 **Manual/GUI QA** — needs the app run (blocked here by the multi-display/Spaces screenshot issue): open files of several languages → correct coloring; unknown → plain; line numbers + wrap; select/copy; read-only; Reload; ⌘F finds; large file opens without hanging; dark/light/Blur legibility; tap-to-split beside terminal; close pane
- [x] 4.4 `openspec validate code-editor --strict`

> **Scope note:** files open **split beside the terminal by default** (per follow-up request), tab fallback when no terminal. A terminal's secondary pane shows the code split (taking precedence over a Markdown preview split); each has its own close control. Editing/saving remains out of scope (deferred phase 3).
