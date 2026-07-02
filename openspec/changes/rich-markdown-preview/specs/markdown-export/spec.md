# markdown-export Specification

## ADDED Requirements

### Requirement: Export to HTML
The preview SHALL export the rendered document as a single self-contained HTML file (styles inlined, images embedded) chosen via a save panel, so the file renders identically when opened in a browser with no network access.

#### Scenario: Self-contained HTML export
- **WHEN** the user exports a document with code blocks, a diagram, and local images as HTML
- **THEN** a single .html file is written that reproduces the rendered appearance offline

### Requirement: Export to PDF
The preview SHALL export the rendered document as a paginated PDF using a print-optimized stylesheet (no glass/translucency effects, sensible page margins, code blocks not truncated).

#### Scenario: PDF export
- **WHEN** the user exports as PDF
- **THEN** a save panel appears and the resulting PDF contains the full document with readable pagination

### Requirement: Export Markdown source
The preview SHALL export the current Markdown source to a file — for file-backed previews the original source, for streamed previews the accumulated buffer.

#### Scenario: Streamed source export
- **WHEN** the user exports Markdown from a preview fed by a stream
- **THEN** the saved .md file contains exactly the Markdown received so far

### Requirement: Export completeness and error reporting
PDF export SHALL include the entire document (blocks skipped by rendering optimizations are expanded before capture). Export failures SHALL surface an alert with the reason — never fail silently.

#### Scenario: Long document exports fully
- **WHEN** the user exports a 5,000-line document as PDF
- **THEN** every section appears in the PDF, including content never scrolled into view

#### Scenario: Failure shows an alert
- **WHEN** PDF rendering or file writing fails
- **THEN** an "Export Failed" alert explains the reason

### Requirement: Print
The preview SHALL support printing via the standard macOS print dialog (⌘P when the preview has focus) using the same print stylesheet as PDF export.

#### Scenario: Print dialog
- **WHEN** the user presses ⌘P in a focused preview
- **THEN** the macOS print dialog opens with a paginated print preview of the document
