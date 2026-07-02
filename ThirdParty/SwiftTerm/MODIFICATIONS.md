# Vendored SwiftTerm fork

This is a local, vendored copy of **SwiftTerm 1.13.0**
(`migueldeicaza/SwiftTerm` @ commit `8e7a1e1`), used as a SwiftPM path dependency
so our modifications survive `swift package resolve` (which wipes
`.build/checkouts`). `Package.swift` here is trimmed to only the `SwiftTerm`
library target, dropping the upstream Fuzz / Termcast / Benchmarks targets and
their external dependencies, so this fork pulls in nothing external.

## Why we forked

The `terminal-search` feature (IDE-style ⌘F over the live terminal) needs to
search the **entire scrollback** and draw an all-matches **highlight overlay** +
scrollbar minimap. Upstream's public API exposes neither the full buffer nor cell
geometry, so we added a few narrow public accessors rather than reimplement the
emulator.

## Local modifications

All additions are marked with `zTerminal fork addition` comments.

1. **`Sources/SwiftTerm/Terminal.swift`** — after `getScrollInvariantLine`:
   - `public var bufferLineCount: Int` — total lines (scrollback + on-screen) in
     the current buffer, in the same coordinate space as `getTopVisibleRow()`.
   - `public func bufferLine(atIndex:) -> BufferLine?` — read any line by absolute
     buffer index, for full-scrollback text extraction.

2. **`Sources/SwiftTerm/Mac/MacTerminalView.swift`** — after `getOptimalFrameSize()`:
   - `public var cellSize: CGSize` — character-cell size in points, for mapping
     buffer positions to view rects (highlight overlay + minimap).

## Updating upstream

To re-sync with a newer SwiftTerm: replace `Sources/SwiftTerm/`, then re-apply the
additions above (grep for `zTerminal fork addition`).
