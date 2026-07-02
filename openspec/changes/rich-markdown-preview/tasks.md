# Tasks — Rich Markdown Preview

## 1. Web renderer asset pipeline

- [x] 1.1 Create `scripts/build-preview-assets.sh` (esbuild) that bundles markdown-it + plugins (task-lists, footnote, emoji, anchor), highlight.js (curated ~40 languages), DOMPurify, Mermaid, and KaTeX (+fonts) into `Resources/Preview/preview.js` / `preview.css`, and commit the built bundle
- [x] 1.2 Write `Resources/Preview/preview.html` shell with strict CSP (no network), container elements for content/TOC/search overlay, and the `preview.*` JS API surface (`setContent`, `setTheme`, `search`, `exportHTML`)
- [x] 1.3 Write custom markdown-it plugins: callout blockquotes (`> Note/Warning/Danger/Tip` + GitHub `[!NOTE]` alerts) and code-fence attributes (filename/title)
- [x] 1.4 Wire resource copying for both build paths (`Package.swift` resources + XcodeGen `project.yml`) and add a `PreviewAssets` locator with a unit test that resolves the bundle in SwiftPM

## 2. Rendering core (JS)

- [x] 2.1 Implement the block pipeline: markdown source → markdown-it tokens → top-level blocks with stable content-hash keys → keyed DOM diff (insert/remove/replace changed blocks only)
- [x] 2.2 Implement streaming behavior: per-frame update coalescing, last-block-only re-render, open-fence display heuristic, and bottom auto-follow only when already at bottom
- [x] 2.3 Integrate highlight.js into the render pass; add lazy Mermaid init + per-diagram IntersectionObserver rendering with parse-error fallback; add KaTeX inline/block math
- [x] 2.4 Add large-document handling: `content-visibility: auto` + intrinsic-size hints per block; chunked first render via requestIdleCallback if needed; verify 5,000-line fixture paints viewport <500ms
- [x] 2.5 Implement block fade-in / cross-fade animations with zero layout jump

## 3. Theme (CSS)

- [x] 3.1 Build `preview.css` design system on CSS custom properties: 16–18px type, ≥1.6 line height, centered ~720px column, light/dark palettes, heading accents (H1 blue gradient, H2 violet, H3 red, H4 cyan, H5 green), glass cards on soft-gray background
- [x] 3.2 Style code blocks: rounded corners, language badge, copy button with confirmation, line numbers, current-line highlight, word-wrap toggle, optional filename header
- [x] 3.3 Style tables (rounded borders, zebra rows, hover, soft shadow, sticky header in scroll container), callout cards with icons/colors, images (responsive, rounded, shadow, click-to-zoom lightbox), and remaining GFM elements (blockquotes, hr, task lists, footnotes)
- [x] 3.4 Add print stylesheet (no glass, page margins, unclipped code) shared by PDF export and ⌘P

## 4. Swift host

- [x] 4.1 Create `Sources/zTerminal/Preview/`: `PreviewWebView` (WKWebView wrapper), `PreviewViewModel` (debounced content pushes, theme pushes), script message handler (links, ready/error), and `zt-asset://` WKURLSchemeHandler scoped to the document directory
- [x] 4.2 Implement `PreviewSource` protocol with `FileSource` (load + DispatchSource vnode watcher, scroll-preserving reload) and `StreamSource` (appendable buffer)
- [x] 4.3 Bridge the theme system: observe app theme + `NSApp.effectiveAppearance`, resolve auto on the Swift side, push light/dark to JS without document reload
- [x] 4.4 Handle links: external → NSWorkspace/default browser, relative `.md` → load in preview, anchors → in-page smooth scroll
- [x] 4.5 Add Settings toggle for raw HTML rendering (default off) wired to sanitized-HTML mode

## 5. Shell integration

- [x] 5.1 Add split-pane preview beside the terminal (draggable divider, collapsible) and dedicated preview tab with document name as title
- [x] 5.2 Add entry points: File → Open Markdown Preview…, `.md` drag-and-drop onto the window, and `zterminal://preview?path=` URL scheme handling
- [x] 5.3 Implement focus-based ⌘F routing (preview focused → preview search; terminal focused → terminal search) and ⌘P print routing

## 6. Navigation & search (JS)

- [x] 6.1 Build the collapsible TOC sidebar generated from heading anchors, updating incrementally on content changes, with smooth-scroll on click
- [x] 6.2 Add scroll-spy via IntersectionObserver to highlight the current section in the TOC
- [x] 6.3 Build the search overlay: text-node match highlighting, "N of M" count, Enter/Shift+Enter (and ⌘G/⇧⌘G) next/prev with wraparound, Escape to dismiss, forcing visibility of matches inside content-visibility-skipped blocks

## 7. Export

- [x] 7.1 Implement self-contained HTML export (inline CSS, data-URI images) via JS serialization + NSSavePanel
- [x] 7.2 Implement PDF export via `WKWebView.createPDF` with the print stylesheet, Markdown source export (file source or accumulated stream buffer), and ⌘P print via `printOperation(with:)`

## 8. Verification

- [x] 8.1 Add a GFM torture-test fixture (all constructs incl. mermaid, KaTeX, callouts, footnotes, emoji) and a 5,000+ line fixture; unit-test the Swift bridge/source layer (`swift test`)
- [x] 8.2 Add a streaming demo harness (feed a fixture through `StreamSource` in chunks) and manually verify flicker-free token streaming, scroll-position stability, and TOC/search during streaming
- [x] 8.3 Verify offline rendering (network blocked), HTML sanitization (script never executes), both build paths (`swift build` + XcodeGen app), and light/dark/auto switching end-to-end
