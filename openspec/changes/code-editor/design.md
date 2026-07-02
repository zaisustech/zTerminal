## Context

The Markdown-preview feature already established the pattern this builds on: a `SessionKind`
(`.terminal` / `.preview`), `SessionContentView` switching per kind, tabs and an `HSplitView`
split beside the terminal, and a `WindowModel.openPreview(url:split:)` entry point. A code
viewer is the same shape with a new `.code` kind. The `file-explorer` change left an
`onOpenFile(url)` hook precisely so this phase can intercept code files. Find-in-file reuses
the existing `SearchController`/find bar.

## Goals / Non-Goals

**Goals:** open a text/code file in a read-only, syntax-highlighted viewer (tab or split);
auto-detect language from extension with a plain-text fallback; line numbers + soft-wrap
toggle; find-in-file; reload; large-file cap; honor theme fonts/colors and appearance.

**Non-Goals:** editing/saving (deferred phase 3); LSP/semantic highlighting, completion,
diagnostics; minimap/folding/diff; rendering binaries as text.

## Decisions

### Decision: A `.code` session kind, reusing the tab/split layout
Add `SessionKind.code` beside `.terminal`/`.preview`. `SessionContentView` renders a
`CodeViewer` for `.code` tabs and, when a terminal tab has an attached code file, in an
`HSplitView` beside it — identical to how preview tabs/splits already work. This reuses tab
management, titles, and the split UX with no new window plumbing. `WindowModel.openCode(url:
split:)` mirrors `openPreview`.

### Decision: NSTextView-backed viewer for performance
Render with an `NSTextView` (via `NSViewRepresentable`) configured non-editable/selectable,
fed an `NSAttributedString` produced by the highlighter, with a line-number ruler
(`NSRulerView`) in the gutter. `NSTextView`/TextKit handles large documents, selection, and
find far better than laying out SwiftUI `Text`. Soft-wrap toggles the text container's width
tracking. Selection + copy work; typing does nothing (read-only).

### Decision: Rule-based `SyntaxHighlighter`, no external engine
Highlighting is a tokenizer producing attributed ranges (keywords, strings, comments, numbers,
types/identifiers, punctuation) colored from a theme palette. Per-language rules
(keyword sets + regex for strings/comments/numbers) cover the common set; unknown languages
fall back to plain text. Kept dependency-free and fast (highlight the visible range first,
then the rest incrementally for big files). Token colors come from the theme so light/dark/Blur
all read well.

### Decision: `CodeLanguage` detection by extension (+ a couple of shebang cases)
Map extension → language (`.swift`, `.js/.ts/.jsx/.tsx`, `.json`, `.py`, `.go`, `.rs`, `.sh/
.zsh/.bash`, `.md`, `.yml/.yaml`, `.html`, `.css`, `.c/.h/.cpp`, …); fall back to shebang
sniffing for extensionless scripts; else plain text. Pure and unit-testable.

### Decision: Read-only, with reload; large-file cap
The buffer is non-editable and the viewer shows a subtle "read-only" affordance. A **Reload**
action re-reads from disk (the file may change). Files above a size cap (e.g. 2 MB / very long
lines) load as plain text with a "large file — highlighting disabled" notice rather than
hanging; a hard cap streams/truncates with a clear notice (no silent truncation).

### Decision: Find-in-file reuses the find bar
⌘F in a `.code` tab opens the existing find UX bound to the viewer's text (highlight all +
next/previous + counter), reusing `SearchController` semantics over the document string instead
of the terminal buffer. (Implementation may specialize the controller for a static string
source.)

### Decision: Encoding + off-main load
Load file data off-main; decode as UTF-8, falling back to Latin-1/other on failure; publish the
string + detected language back on main. Decode failure shows a clear message, not garbage.

## Risks / Trade-offs

- **Highlighter correctness/perf** — regex tokenizers can mis-highlight edge cases and be slow
  on pathological input. Mitigate: highlight visible range first, bound work, and always have
  the plain-text fallback. Correctness is "good enough to read," not compiler-accurate.
- **NSTextView ↔ SwiftUI bridging** — ruler/wrap/selection wiring is fiddly. Encapsulate in one
  representable with a coordinator; keep the SwiftUI surface small.
- **Large files** — enforce the cap up front; never block the main thread on load or highlight.
- **Theme contrast** — token palette must be legible in light, dark, and Blur; derive from the
  theme and validate contrast.

## Migration Plan

Additive: new `.code` `SessionKind`, `CodeViewer` + `SyntaxHighlighter` + `CodeLanguage`, a
`WindowModel.openCode` entry point, and the `file-explorer` hook now routing code files here.
No change to terminal/preview behavior. Rollback = drop the `.code` kind + viewer and revert
the explorer hook to open externally.

## Open Questions

- Open code files as their own **tab** by default, or **split** beside the terminal (like
  preview)? (Leaning: split when launched from the sidebar next to a terminal, tab otherwise —
  mirror preview.)
- How many languages to cover at first? (Leaning: the ~12 listed; add more rules incrementally.)
- Wrap on or off by default? (Leaning: off for code, with a toggle.)
