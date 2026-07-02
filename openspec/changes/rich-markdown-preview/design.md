# Design — Rich Markdown Preview

## Context

zTerminal is a native macOS app (SwiftUI + AppKit, SwiftTerm emulator) with two build paths (SwiftPM and XcodeGen). It has an existing theme system (`Sources/zTerminal/Theme/`), a tab bar, and per-tab terminal views. There is no web view, no Markdown rendering, and no AI/preview panel today.

The preview must render full GFM plus Mermaid, KaTeX, and syntax-highlighted code with a premium documentation look, stay smooth while content streams in token-by-token, and handle 5,000+ line documents instantly. Rendering quality benchmark: markdownlivepreview.com elevated with Notion/GitBook/Linear-style visual design.

## Goals / Non-Goals

**Goals:**
- A reusable preview surface (split pane next to the terminal, or its own tab) that renders a Markdown file or an appendable in-memory stream.
- Full GFM + Mermaid + KaTeX + highlighted code, all offline (bundled assets, no CDN).
- Premium colorful theme with light/dark/auto tied to the existing theme system.
- Flicker-free incremental updates during streaming; instant load for large documents.
- TOC with scroll-spy, in-preview ⌘F search, export to HTML/PDF/Markdown/print.

**Non-Goals:**
- Building the AI assistant itself — the preview consumes a content source; who produces the tokens is out of scope.
- Markdown *editing* (WYSIWYG or source editor) — read-only preview.
- Rendering arbitrary remote web pages; network fetches are blocked except local file images.
- Windows/Linux portability.

## Decisions

### D1: Render in a `WKWebView` with a bundled JS pipeline (not native SwiftUI)

Mermaid, KaTeX, and quality syntax highlighting only exist as mature web libraries; `AttributedString(markdown:)` covers a fraction of GFM and none of the visual design. A single WKWebView hosting a self-contained `preview.html` + JS bundle gives us the full ecosystem, CSS-grade typography control, and `createPDF`/print for free.
*Alternatives:* native TextKit renderer (years of work to match quality); Down/cmark + NSAttributedString (no tables/mermaid/math); embedding a localhost server (needless complexity — `loadFileURL` + custom scheme suffices).

### D2: Parser is `markdown-it` + GFM plugin set, prebuilt with esbuild

`markdown-it` is fast (CommonMark-compliant, ~30k lines/sec), synchronous, and has first-party plugins for everything required: `markdown-it-task-lists`, `-footnote`, `-emoji`, `-anchor` (TOC ids), plus a small custom plugin for `> Note/Warning/Danger/Tip` callouts. A build script (`scripts/build-preview-assets.sh`, run at dev time and committed as a dist bundle under `Resources/Preview/`) uses esbuild to produce one `preview.js` + `preview.css`; the app never runs Node.
*Alternatives:* remark/unified (heavier, async pipeline complicates incremental rendering); marked (weaker plugin ecosystem, laxer spec compliance).

### D3: Syntax highlighting via `highlight.js`; Mermaid and KaTeX lazy-loaded per block

highlight.js is synchronous, ~100KB with a curated language set, and fast enough to run inside the render pass. Shiki's output is prettier but its WASM + grammar payload is multi-MB and async — wrong trade-off for streaming. Mermaid (~1MB) and KaTeX (+fonts) are bundled but only initialized when the document actually contains a ```mermaid fence or math delimiters, and individual diagrams render via `IntersectionObserver` so off-screen diagrams don't block first paint.

### D4: Incremental rendering by block-level keyed diffing

The JS side maintains the pipeline: markdown source → markdown-it token stream → array of top-level blocks → stable content-hash key per block → DOM patch (insert/remove/replace only changed block elements). During streaming, appended tokens only ever dirty the last (possibly unclosed) block; earlier blocks keep their DOM nodes, so images don't re-fetch, Mermaid doesn't re-render, and nothing flashes. An unclosed code fence renders as an open code block rather than escaping as text. New blocks animate in with a ~150ms fade; replaced blocks cross-fade with no layout jump.
*Alternatives:* full `innerHTML` replace (flicker, scroll jump, re-runs Mermaid — exactly what the spec forbids); virtual-DOM library like morphdom (still diffs the whole tree; block keying is cheaper and matches Markdown's structure).

### D5: Large-document performance via `content-visibility: auto`, not JS virtual scrolling

Each top-level block gets `content-visibility: auto` + `contain-intrinsic-size` hints, so the browser skips layout/paint for off-screen blocks — 5,000+ line documents paint the viewport immediately. This keeps ⌘F, TOC anchors, and text selection working on real DOM (JS virtualization breaks all three). If profiling shows the token→DOM step itself is the bottleneck on huge docs, first render is chunked over `requestIdleCallback` (viewport first).

### D6: Swift ⇄ JS bridge

- **Swift → JS**: `PreviewViewModel` pushes the full Markdown source via `evaluateJavaScript("preview.setContent(...)")`, debounced to one push per frame (~16ms) during streaming; the JS diff makes full-source pushes cheap and keeps the protocol stateless/recoverable.
- **JS → Swift**: one `WKScriptMessageHandler` ("preview") for link clicks (external links open in browser), TOC/search state, and ready/error signals.
- **Content sources**: `PreviewSource` abstraction with two implementations — `FileSource` (loads a `.md` file, watches it with a `DispatchSource` vnode watcher, reloads on change) and `StreamSource` (appendable buffer for AI/token streaming).

### D7: Security posture

Raw HTML blocks are **off by default** (`markdown-it` `html: false`); when the user enables them in Settings, output is sanitized with bundled DOMPurify. A strict CSP in `preview.html` blocks all network loads. Local images resolve through a `WKURLSchemeHandler` (`zt-asset://`) that only serves files under the previewed document's directory. JavaScript in content never executes (sanitizer strips it).

### D8: Theming — CSS custom properties driven by the app theme system

All colors/typography are CSS variables in `preview.css` with `light`/`dark` variants; heading accents fixed at H1 blue `#3B82F6` (gradient), H2 violet `#8B5CF6`, H3 red `#EF4444`, H4 cyan `#06B6D4`, H5 green `#22C55E`; semantic palette (success/warning/info/accent) matches. Swift observes the existing theme system + `NSApp.effectiveAppearance` and pushes `preview.setTheme('light'|'dark')`; "auto" is resolved on the Swift side so preview and app can never disagree. Glass effect via `backdrop-filter` cards over a soft-gray body, consistent with the existing liquid-glass UI language.

### D9: Search and TOC live in JS; ⌘F routes by focus

Custom JS search (walk text nodes, wrap matches in `<mark>`) rather than `WKWebView` find API — we need match count, styled current-match, and next/prev, which the native API doesn't expose well. The search bar is an in-page overlay. The app shell routes ⌘F to the preview when the preview pane has key focus, otherwise to the existing terminal search. Scroll-spy TOC uses `IntersectionObserver` over heading elements; TOC is a collapsible in-page sidebar.

### D10: Export

- **HTML**: JS serializes the rendered document with inlined CSS (and inlined images as data URIs) → single self-contained file.
- **PDF**: `WKWebView.createPDF` with a print stylesheet (no glass blur, page margins).
- **Print**: `webView.printOperation(with:)`.
- **Markdown**: writes the current source buffer (trivial for FileSource; captures the stream for StreamSource).
Save panels via `NSSavePanel` on the Swift side.

### D11: Presentation — split pane within a tab + preview-only tab

The preview mounts in an `NSSplitView`-backed SwiftUI split alongside the terminal (default: right pane, 50%, draggable, collapsible), and can also open as a full tab. Entry points: File → Open Preview…, drag-and-drop of a `.md` file onto the window, `zterminal://preview?path=…` URL scheme, and a programmatic API for future AI integration.

## Risks / Trade-offs

- [Bundle size: Mermaid + KaTeX fonts add ~3–4MB] → Acceptable for a desktop app; lazy init keeps runtime cost zero when unused; revisit tree-shaking Mermaid if it grows.
- [Streaming pushes full source every frame] → markdown-it parses ~1MB in tens of ms and the diff discards unchanged blocks; if profiling shows parse cost dominating on huge streamed docs, switch the bridge to append-only deltas with a JS-side buffer (protocol already isolates this in `PreviewSource`).
- [Unclosed constructs mid-stream (half a table row, open fence) can render oddly for a frame] → Last-block-only re-render confines the churn to one block; heuristics close fences for display.
- [`content-visibility` quirks with in-page search/anchors (matches inside skipped subtrees)] → Search temporarily forces `content-visibility: visible` on blocks containing matches; anchors use `scrollIntoView` which forces layout correctly on modern WebKit.
- [WKWebView resource loading differs between SwiftPM `Bundle.module` and Xcode app bundle] → Single `PreviewAssets` locator abstraction with unit test coverage on both paths; assets copied via `Package.swift` resources and XcodeGen `project.yml`.
- [Raw HTML is a XSS vector if enabled] → Off by default; DOMPurify + CSP + no-network scheme handler as defense in depth.

## Open Questions

- Which highlight.js language set to bundle (proposal: top ~40 languages, ~250KB) — finalize during implementation.
- Whether the AI streaming producer will feed `StreamSource` in this change or a follow-up; this change ships the API plus a demo path (piping a file/clipboard stream) to prove flicker-free streaming.
