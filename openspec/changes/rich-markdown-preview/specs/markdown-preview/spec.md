# markdown-preview Specification

## ADDED Requirements

### Requirement: GitHub-Flavored Markdown rendering
The preview SHALL render full GitHub-Flavored Markdown: headings (H1–H6), paragraphs, tables, nested lists, task lists/checklists, links, images, footnotes, blockquotes, horizontal rules, emoji shortcodes, and fenced code blocks.

#### Scenario: GFM document renders completely
- **WHEN** a Markdown document containing headings, a table, nested lists, task list items, links, footnotes, blockquotes, horizontal rules, and `:emoji:` shortcodes is loaded
- **THEN** every construct renders as its rich visual form with no raw Markdown syntax visible

#### Scenario: Task list checkboxes reflect state
- **WHEN** the document contains `- [x] done` and `- [ ] pending` items
- **THEN** the preview renders checked and unchecked checkbox glyphs respectively

#### Scenario: Footnote round-trip
- **WHEN** the user clicks a footnote reference marker
- **THEN** the preview scrolls smoothly to the footnote definition, and a back-link returns to the reference

### Requirement: Syntax-highlighted code blocks
Fenced code blocks SHALL be syntax-highlighted according to their language tag using a bundled highlighter, with graceful plain-text fallback for unknown languages.

#### Scenario: Known language is highlighted
- **WHEN** a fenced block is tagged `typescript`
- **THEN** the code renders with TypeScript token coloring

#### Scenario: Unknown language falls back
- **WHEN** a fenced block is tagged with an unrecognized language
- **THEN** the code renders as plain monospace text without errors

### Requirement: Mermaid diagram rendering
Fenced code blocks tagged `mermaid` SHALL render as live Mermaid diagrams using a bundled Mermaid library, with the diagram source shown as a fallback when the diagram fails to parse.

#### Scenario: Valid diagram renders
- **WHEN** the document contains a ```mermaid fence with `graph TD; A --> B`
- **THEN** the preview displays the rendered flowchart, not the source text

#### Scenario: Invalid diagram degrades gracefully
- **WHEN** a mermaid fence contains invalid diagram syntax
- **THEN** the preview shows the raw source in a code block with an inline error note, and the rest of the document renders normally

### Requirement: Math rendering with KaTeX
Inline (`$...$`) and block (`$$...$$`) math expressions SHALL render via bundled KaTeX.

#### Scenario: Block math renders
- **WHEN** the document contains `$$E = mc^2$$`
- **THEN** the preview displays the typeset equation

### Requirement: Raw HTML is opt-in and sanitized
Raw HTML blocks SHALL NOT render by default. When the user enables HTML rendering in Settings, HTML SHALL be sanitized so that scripts and event handlers never execute.

#### Scenario: HTML disabled by default
- **WHEN** a document containing `<div onclick="...">` is loaded with default settings
- **THEN** the HTML is escaped or omitted and no interactive HTML renders

#### Scenario: Enabled HTML is sanitized
- **WHEN** HTML rendering is enabled and the document contains a `<script>` tag
- **THEN** the script is stripped and never executes

### Requirement: Preview presentation surfaces
The preview SHALL be openable as a split pane alongside the terminal in the current tab and as a dedicated tab. The split divider SHALL be draggable and the pane collapsible.

#### Scenario: Open as split pane
- **WHEN** the user opens a Markdown file in preview from the File menu
- **THEN** the preview appears in a split pane beside the terminal, and dragging the divider resizes both panes

#### Scenario: Open as dedicated tab
- **WHEN** the user opens the preview as a tab
- **THEN** a new tab shows only the rendered document with the document name as the tab title

### Requirement: File source with live reload
When previewing a file on disk, the preview SHALL watch the file and re-render automatically when it changes, without losing scroll position.

#### Scenario: External edit re-renders
- **WHEN** the previewed file is modified by another program
- **THEN** the preview updates to the new content within one second, keeping the reader's scroll position stable

### Requirement: Streaming content source
The preview SHALL accept an appendable in-memory stream source so that Markdown arriving incrementally (e.g., AI token output) renders live as it grows.

#### Scenario: Appending renders incrementally
- **WHEN** Markdown text is appended to a stream source in small chunks
- **THEN** the preview updates continuously to include the new content without requiring a manual refresh

### Requirement: Multi-document preview panel
A preview surface SHALL host multiple documents as tabs inside itself (terminal | split | doc-tab1 | doc-tab2 …). The window SHALL keep at most ONE split preview panel: opening another Markdown file in split mode adds a document tab to the existing panel (selecting its host tab) rather than attaching previews to other terminal tabs. Opening an already-open file SHALL re-select its tab instead of duplicating it. Closing a document's tab keeps the panel; closing the last document closes the panel.

#### Scenario: Second file becomes a document tab
- **WHEN** a split preview is open and the user opens another Markdown file in split mode
- **THEN** the file appears as a second tab inside the same panel, and no other terminal tab gains a preview

#### Scenario: Re-opening selects the existing tab
- **WHEN** the user opens a file that is already a document tab in the panel
- **THEN** that tab is selected and no duplicate tab is created

#### Scenario: Closing the last document closes the panel
- **WHEN** the user closes the only remaining document tab
- **THEN** the split collapses and the terminal returns to full width

### Requirement: Shell commands
The shell integration SHALL define `markdown <file>` (opens the preview split beside the invoking terminal) and `md <file>` (opens a preview tab). Both SHALL resolve relative paths and `~`, validate the file, print a usage/error message for bad input, and signal the app in-band (OSC) so the preview opens in the exact tab where the command ran.

#### Scenario: markdown command splits
- **WHEN** the user types `markdown README.md` at the prompt
- **THEN** the rendered file opens split beside that terminal

#### Scenario: md command opens a tab
- **WHEN** the user types `md docs/spec.md`
- **THEN** the rendered file opens as a preview tab

#### Scenario: Invalid input reports an error
- **WHEN** the user types `markdown` with no argument or a nonexistent file
- **THEN** a usage or "no such file" message prints and nothing opens

### Requirement: Link handling
External links SHALL open in the user's default browser; internal anchor links SHALL smooth-scroll within the preview. Relative links to local Markdown files SHALL open in the preview.

#### Scenario: External link opens browser
- **WHEN** the user clicks an `https://` link
- **THEN** the default browser opens the URL and the preview does not navigate away

#### Scenario: Relative markdown link opens in preview
- **WHEN** the user clicks a relative link to `./docs/other.md`
- **THEN** the preview loads and renders that file

### Requirement: Offline operation
All rendering assets (parser, highlighter, Mermaid, KaTeX, fonts, styles) SHALL be bundled with the app; the preview SHALL function fully with no network access, and remote network requests from rendered content SHALL be blocked.

#### Scenario: Renders with networking unavailable
- **WHEN** the machine has no network connectivity and a document with code, diagrams, and math is opened
- **THEN** all content renders identically to the online case
