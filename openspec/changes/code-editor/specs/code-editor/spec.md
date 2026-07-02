## ADDED Requirements

### Requirement: Open a file in a code viewer
The app SHALL open a text/code file in a read-only code viewer — as a tab or split beside a
terminal — launched from the file explorer, a `zterminal://` URL, or a menu. The viewer SHALL
show the file's name as its title and its full contents.

#### Scenario: Open from the file explorer
- **WHEN** the user opens a text/code file from the file-explorer sidebar
- **THEN** the file opens in a code viewer showing its contents, titled with the file name

#### Scenario: Opens split beside the terminal by default
- **WHEN** the user taps a file while a terminal tab is active
- **THEN** the code viewer opens as a split pane beside that terminal (with a close control); when there is no terminal to split beside, it opens as its own tab

### Requirement: Multiple files as tabs
The code viewer SHALL hold multiple open files as tabs in a single panel: opening another
file SHALL add a tab (rather than replacing the current one), re-opening an already-open file
SHALL focus its existing tab, each tab SHALL be individually closable, and closing the last
tab SHALL dismiss the panel/tab. Tabs SHALL be reorderable.

#### Scenario: Open several files
- **WHEN** the user opens a second (different) file while a code viewer is already open
- **THEN** it appears as an additional tab in the same panel, and the user can switch between the open files

#### Scenario: Re-opening focuses the existing tab
- **WHEN** the user opens a file that is already open in the panel
- **THEN** its existing tab is focused instead of a duplicate being created

#### Scenario: Closing tabs
- **WHEN** the user closes a code tab
- **THEN** that file's tab is removed; closing the last tab dismisses the code panel

#### Scenario: Binary files still open externally
- **WHEN** the user opens a non-text (binary) file from the sidebar
- **THEN** it opens in the system default app rather than the code viewer

### Requirement: Syntax highlighting by language
The viewer SHALL syntax-highlight the file using a color theme, with the language auto-detected
from the file extension (and, for extensionless scripts, a shebang). Common languages SHALL be
supported (e.g. Swift, JavaScript/TypeScript, JSON, Python, Go, Rust, shell, Markdown, YAML,
HTML, CSS). Unknown types SHALL fall back to readable plain text.

#### Scenario: Highlight a known language
- **WHEN** a `.swift` (or other supported) file is opened
- **THEN** keywords, strings, comments, and numbers are colored distinctly per the theme

#### Scenario: Unknown type falls back to plain text
- **WHEN** a file of an unrecognized type is opened
- **THEN** it displays as plain, readable text without error

#### Scenario: Colors follow the appearance
- **WHEN** the app is in light, dark, or Blur appearance
- **THEN** the syntax colors remain legible against the viewer background

### Requirement: Line numbers and soft-wrap
The viewer SHALL show a line-number gutter and SHALL provide a soft-wrap toggle. Text SHALL be
selectable and copyable.

#### Scenario: Line numbers shown
- **WHEN** a file is open in the viewer
- **THEN** a line-number gutter is shown alongside the content

#### Scenario: Toggle soft-wrap
- **WHEN** the user toggles soft-wrap
- **THEN** long lines wrap to the viewport width, or extend with horizontal scrolling, accordingly

#### Scenario: Select and copy
- **WHEN** the user selects text and copies
- **THEN** the selected text is copied; the buffer cannot be edited

### Requirement: Read-only with reload
The viewer SHALL be read-only and SHALL indicate this. It SHALL provide a Reload action that
re-reads the file from disk.

#### Scenario: Editing is not possible
- **WHEN** the user types into the viewer
- **THEN** the content does not change (read-only)

#### Scenario: Reload from disk
- **WHEN** the file changes on disk and the user triggers Reload
- **THEN** the viewer shows the updated contents

### Requirement: Find in file
Pressing ⌘F in the code viewer SHALL open a find UX over the file's text — highlighting all
matches, navigating next/previous, and showing a match count — consistent with the terminal
find bar.

#### Scenario: Find within the file
- **WHEN** the user presses ⌘F and types a query in the code viewer
- **THEN** matches are highlighted, next/previous navigation works, and a match count is shown

### Requirement: Large-file handling
The viewer SHALL open large files without hanging: above a size threshold it SHALL load as
plain text with highlighting disabled and a clear notice, and any hard truncation SHALL be
disclosed to the user rather than silent. File loading and highlighting SHALL not block the
main thread.

#### Scenario: Large file loads without hanging
- **WHEN** the user opens a file above the highlighting size threshold
- **THEN** it opens as plain text with a notice that highlighting was disabled, and the UI stays responsive

#### Scenario: Decode failure is reported
- **WHEN** a file cannot be decoded as text
- **THEN** the viewer shows a clear message rather than garbled content
