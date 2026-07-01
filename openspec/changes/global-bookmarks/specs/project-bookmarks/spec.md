## ADDED Requirements

### Requirement: Global bookmarks in `~/.zTerminal.json`
The application SHALL read bookmarks from a **global** `~/.zTerminal.json` in the
user's home directory, in addition to the active tab's per-project `.zTerminal.json`.
Global bookmarks SHALL be available in every directory. A missing or unreadable global
file SHALL be treated as absent (no error, no crash).

#### Scenario: Global bookmarks available everywhere
- **WHEN** the user opens the Bookmarks popover in any directory
- **THEN** the bookmarks defined in `~/.zTerminal.json` are listed, regardless of the current folder

#### Scenario: Absent global file is tolerated
- **WHEN** `~/.zTerminal.json` does not exist or cannot be parsed
- **THEN** the Global section is empty (offering to add one) and the app does not crash

### Requirement: Bookmarks popover shows Global and Current sections
The Bookmarks popover SHALL present bookmarks in two labeled sections: a **Global**
section (from `~/.zTerminal.json`) and a **Current** section (from the active tab's
`.zTerminal.json`), the Current section titled with the folder's name. When the active
tab's directory is the home directory — so both sections would read the same file — the
popover SHALL show a single Global section. The filter field SHALL narrow both
sections, and activating "run first match" (Return) SHALL run the first visible
bookmark, preferring the Global section.

#### Scenario: Two sections in a project folder
- **WHEN** the user opens the Bookmarks popover in a folder that is not the home directory
- **THEN** a Global section and a Current section (titled with the folder name) are shown

#### Scenario: Home directory shows a single section
- **WHEN** the active tab's directory is the home directory
- **THEN** only the Global section is shown (no duplicate Current section)

#### Scenario: Filter and run-first across sections
- **WHEN** the user types in the filter and presses Return
- **THEN** both sections narrow to matches and the first matching bookmark runs, preferring a Global match

### Requirement: Add, edit, and delete target a bookmark's own section
Each section SHALL provide its own affordance to add a bookmark, writing to that
section's file (`~/.zTerminal.json` for Global, the current folder's `.zTerminal.json`
for Current), creating the file when needed. Editing or deleting a bookmark SHALL
modify the file of the section that bookmark belongs to.

#### Scenario: Add to Global
- **WHEN** the user uses the Global section's "Add" affordance to save a bookmark
- **THEN** it is written to `~/.zTerminal.json` and appears in the Global section

#### Scenario: Add to Current
- **WHEN** the user uses the Current section's "Add" affordance to save a bookmark
- **THEN** it is written to the current folder's `.zTerminal.json` and appears in the Current section

#### Scenario: Edit or delete affects the right file
- **WHEN** the user edits or deletes a bookmark in one section
- **THEN** only that section's `.zTerminal.json` is modified, and the other section is unchanged

### Requirement: Visual icon picker with previews
When adding or editing a bookmark, the icon chooser SHALL present a searchable grid of
**rendered SF Symbol previews** (not a text list of names), highlight the currently
selected icon, and offer only symbols that are available on the running system.

#### Scenario: Grid of rendered previews
- **WHEN** the user opens the icon chooser
- **THEN** icons are shown as a grid of rendered previews, with the current selection highlighted

#### Scenario: Filter icons by name
- **WHEN** the user types in the icon chooser's filter field
- **THEN** the grid narrows to icons whose symbol name matches

#### Scenario: Only available symbols are offered
- **WHEN** a candidate symbol is not available on the running macOS
- **THEN** it is omitted from the grid (never shown as a blank tile)
