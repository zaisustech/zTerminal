# markdown-navigation Specification

## ADDED Requirements

### Requirement: Auto-generated table of contents
The preview SHALL generate an interactive table of contents from the document's headings, shown in a collapsible sidebar. Clicking an entry SHALL smooth-scroll to that section. The TOC SHALL update automatically as document content changes.

#### Scenario: TOC click scrolls
- **WHEN** the user clicks a TOC entry
- **THEN** the preview smooth-scrolls until the target heading is at the top of the viewport

#### Scenario: TOC tracks streaming content
- **WHEN** a new `## Section` heading is appended to a streaming document
- **THEN** the TOC gains the new entry without a full re-render

### Requirement: Scroll-spy section highlighting
While the user scrolls, the TOC SHALL highlight the entry for the section currently in view.

#### Scenario: Highlight follows scroll
- **WHEN** the user scrolls the document from one section into the next
- **THEN** the TOC highlight moves to the new section's entry

### Requirement: In-preview search
The preview SHALL provide a search overlay (⌘F when the preview has focus) that highlights all matches, shows a match count (e.g., "3 of 14 matches"), and supports jump-to-next (Enter/⌘G) and jump-to-previous (Shift+Enter/⇧⌘G). Escape SHALL dismiss the overlay and clear highlights.

#### Scenario: Search highlights and counts
- **WHEN** the user presses ⌘F in a focused preview and types a query with 14 matches
- **THEN** all 14 matches are highlighted, the current match is visually distinct, and the overlay shows the count

#### Scenario: Next and previous navigation
- **WHEN** the user presses Enter, then Shift+Enter
- **THEN** the view scrolls to the next match and then back to the previous one, updating the "N of M" indicator, wrapping around at the ends

#### Scenario: Matches in collapsed regions are found
- **WHEN** a match lies in an off-screen region skipped by rendering optimizations
- **THEN** search still finds it, and jumping to it scrolls it into view fully rendered

### Requirement: Smooth scrolling
All programmatic scrolling (TOC clicks, anchor links, footnotes, search jumps) SHALL animate smoothly rather than jumping instantly.

#### Scenario: Anchor navigation is smooth
- **WHEN** any in-document navigation is triggered
- **THEN** the viewport animates to the target instead of teleporting
