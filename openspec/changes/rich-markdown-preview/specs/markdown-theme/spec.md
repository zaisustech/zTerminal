# markdown-theme Specification

## ADDED Requirements

### Requirement: Premium documentation typography
Body text SHALL render at 16–18px with generous line height (≥1.6), a comfortable reading width (~680–760px column, centered), clean margins, and Notion/Linear-grade spacing between blocks. The layout SHALL be responsive to pane width with no horizontal body scrolling; wide content (tables, code, diagrams) SHALL scroll within its own container.

#### Scenario: Narrow pane stays readable
- **WHEN** the preview pane is resized to a narrow width
- **THEN** text reflows, wide tables and code blocks gain their own horizontal scrollbars, and the page body never scrolls horizontally

### Requirement: Colorful heading hierarchy
Headings SHALL use the documentation accent palette: H1 large blue gradient (#3B82F6 base), H2 violet (#8B5CF6), H3 soft red (#EF4444), H4 cyan (#06B6D4), H5 green (#22C55E), with sizes and weights forming a clear visual hierarchy in both light and dark themes.

#### Scenario: Heading colors applied
- **WHEN** a document with H1–H5 headings renders
- **THEN** each heading level shows its assigned accent color, and the H1 renders with a blue gradient treatment

### Requirement: Glassmorphism surface styling
Content SHALL sit on a soft-gray background with rounded content cards and a subtle glass (blur/translucency) effect consistent with zTerminal's liquid-glass UI, applied without harming text contrast or legibility.

#### Scenario: Cards render with glass styling
- **WHEN** the preview renders any document
- **THEN** content containers have rounded corners, soft shadows, and a subtle translucent glass background in both light and dark themes

### Requirement: Rich code block chrome
Every code block SHALL render with rounded corners, a language badge, a copy button, and line numbers; an optional filename header SHALL render when specified (e.g., ```ts title=app.ts); a word-wrap toggle and current-line highlight SHALL be available per block.

#### Scenario: Copy button copies source
- **WHEN** the user clicks a code block's copy button
- **THEN** the block's raw source text is placed on the clipboard and the button shows brief confirmation feedback

#### Scenario: Word wrap toggle
- **WHEN** the user toggles word wrap on a code block with long lines
- **THEN** lines wrap within the block instead of scrolling horizontally, and toggling back restores horizontal scrolling

#### Scenario: Filename header renders
- **WHEN** a fence specifies a filename attribute
- **THEN** the code block shows a header row with the filename above the code

### Requirement: Styled tables
Tables SHALL render with rounded outer borders, zebra-striped rows, row hover highlighting, and soft shadows; headers of long tables SHALL remain visible via sticky positioning while the table scrolls.

#### Scenario: Zebra and hover
- **WHEN** a table with several rows renders and the pointer moves over a row
- **THEN** alternating rows have distinct background tints and the hovered row is visibly highlighted

### Requirement: Callout cards
Blockquotes beginning with `Note`, `Warning`, `Danger`, or `Tip` (including GitHub `[!NOTE]`-style alerts) SHALL render as styled callout cards with an icon and the semantic color: Note = blue, Warning = orange, Danger = red, Tip = green. Plain blockquotes SHALL keep a standard elegant blockquote style.

#### Scenario: Callout types styled
- **WHEN** the document contains `> Note`, `> Warning`, `> Danger`, and `> Tip` blockquotes
- **THEN** each renders as a rounded card with the matching color and icon

### Requirement: Image presentation
Images SHALL render responsively (never overflowing the column) with rounded corners and a soft shadow, and SHALL zoom to a lightbox view on click.

#### Scenario: Image zoom
- **WHEN** the user clicks an image
- **THEN** the image enlarges in an overlay, and clicking again (or pressing Escape) dismisses it

### Requirement: Light, dark, and auto themes
The preview SHALL support light and dark variants of the full theme and an auto mode that follows the system appearance, coordinated with zTerminal's theme system so the preview never disagrees with the app chrome.

#### Scenario: Auto follows system
- **WHEN** theme mode is auto and macOS switches from light to dark appearance
- **THEN** the preview transitions to the dark palette without reloading the document

### Requirement: Animated content updates
Content changes SHALL animate smoothly — new blocks fade in, updated tables/images/code blocks transition without flashing — and animations SHALL never cause layout jumps or scroll displacement.

#### Scenario: New content fades in
- **WHEN** new blocks are appended to a streaming document
- **THEN** each new block appears with a brief fade-in and previously rendered blocks do not flash or shift unexpectedly
