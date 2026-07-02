# Rich Markdown Preview

## Why

zTerminal has no way to render Markdown content — README files, software specs, and AI-generated documentation can only be read as raw text in the terminal. A premium, live-updating Markdown preview panel (rendering quality on par with markdownlivepreview.com, Notion, and GitBook) turns zTerminal into a first-class documentation reading surface, and gives AI-streamed Markdown output a flicker-free, token-by-token live preview.

## What Changes

- New **Markdown preview panel** hosted in a `WKWebView`, openable as a split pane alongside the terminal or as a dedicated tab, rendering a Markdown file or a live-streamed Markdown buffer.
- **Full GitHub-Flavored Markdown rendering**: headings, paragraphs, tables, nested lists, task lists/checklists, links, images, footnotes, blockquotes, horizontal rules, emoji, syntax-highlighted code blocks, Mermaid diagrams, KaTeX math, and (optionally, off by default) raw HTML blocks.
- **Premium documentation theme**: colorful heading hierarchy (H1 blue gradient, H2 violet, H3 red, H4 cyan, H5 green), soft-gray glassmorphism background, rounded content cards, comfortable reading width, 16–18px type with generous line height, and clean responsive margins.
- **Rich code blocks**: rounded corners, copy button, language badge, optional filename header, line numbers, current-line highlight, and a word-wrap toggle.
- **Styled tables**: rounded borders, zebra striping, row hover, soft shadows, optional sticky header.
- **Callout cards** for `> Note`, `> Warning`, `> Danger`, `> Tip` blockquotes with icons and blue/orange/red/green card styling.
- **Interactive table of contents**: auto-generated from headings, smooth-scrolls on click, scroll-spy highlights the current section.
- **In-preview search** (⌘F/Ctrl+F): match highlighting, match count, next/previous navigation.
- **Smooth animated updates**: fade-in for new blocks, animated tables/images/code blocks, no flashing or scroll jumps while content changes.
- **Streaming-safe incremental rendering**: token-by-token AI streaming updates re-render only changed blocks; 5,000+ line documents render instantly (incremental rendering, virtual scrolling if necessary).
- **Theme support**: light, dark, and auto (follows system appearance), integrated with zTerminal's existing theme system.
- **Export**: HTML, PDF, Markdown (source), and print.
- All rendering assets (Markdown parser, syntax highlighter, Mermaid, KaTeX, fonts) are **bundled locally** — no network access required.

## Capabilities

### New Capabilities

- `markdown-preview`: Core preview panel — GFM rendering pipeline, WKWebView host, panel/tab presentation, file loading and file-watching, and streaming input source.
- `markdown-theme`: The premium visual design system — typography, color palette, heading colors, glass cards, code block chrome, table styling, callouts, images, animations, and light/dark/auto theme integration.
- `markdown-navigation`: Reader interaction — interactive table of contents with scroll-spy, in-preview search (⌘F with count and next/prev), and smooth scrolling.
- `markdown-export`: Export of the rendered document to HTML, PDF, Markdown, and print.
- `markdown-performance`: Incremental/streaming rendering guarantees — instant rendering of 5,000+ line documents, block-level diffing during token-by-token streaming, no flicker or scroll jumps.

### Modified Capabilities

- `app-shell`: The shell gains a preview split pane / preview tab surface and the ⌘F key routing rule (search targets the preview when the preview has focus).

## Impact

- **New code**: `Sources/zTerminal/Preview/` (panel controller, WKWebView bridge, streaming buffer, file watcher, export), bundled web renderer assets under `Resources/` (markdown-it + GFM plugins, highlight.js/Shiki, Mermaid, KaTeX, CSS theme).
- **Modified code**: `Sources/zTerminal/UI/` (tab/split-pane integration, toolbar/menu entries), `Sources/zTerminal/Theme/` (propagating light/dark/auto to the web renderer), keyboard shortcut routing for ⌘F.
- **Dependencies**: adds `WebKit` (system framework) usage; vendored JS/CSS libraries bundled into the app resources (app size grows by a few MB — Mermaid and KaTeX dominate).
- **Build**: both SwiftPM and XcodeGen paths must copy the new resource bundle.
- **No breaking changes**; the terminal experience is unchanged when the preview is closed.
