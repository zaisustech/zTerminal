# app-shell Delta Specification

## ADDED Requirements

### Requirement: Markdown preview surfaces in the shell
The application shell SHALL host the Markdown preview as a split pane beside the terminal within a tab and as a dedicated tab. Entry points SHALL include a File-menu command, drag-and-drop of a `.md` file onto the window, and the `zterminal://preview?path=<path>` URL scheme. Closing the preview SHALL restore the plain terminal layout unchanged.

#### Scenario: Open preview from File menu
- **WHEN** the user chooses File → Open Markdown Preview… and selects a .md file
- **THEN** the current tab splits, showing the terminal and the rendered preview side by side

#### Scenario: Drag-and-drop opens preview
- **WHEN** the user drops a .md file onto the zTerminal window
- **THEN** the file opens in a preview surface

#### Scenario: URL scheme opens preview
- **WHEN** `zterminal://preview?path=/path/to/README.md` is opened
- **THEN** zTerminal activates and shows that file in a preview

### Requirement: Markdown document-type registration
The app SHALL register as a Viewer for Markdown documents (`.md`/`.markdown`) so Finder's Open With, document double-click (when zTerminal is the chosen handler), and Dock-icon drops open the file in a preview. Files opened before the window exists (cold launch by document) SHALL be queued and opened once the window is ready. Registration SHALL use Alternate rank so zTerminal does not steal the user's default editor.

#### Scenario: Open With while running
- **WHEN** the user chooses Open With → zTerminal on a .md file with the app running
- **THEN** the file opens in a preview in the existing window (no second instance)

#### Scenario: Cold launch by document
- **WHEN** the app is not running and a .md file is opened with zTerminal
- **THEN** the app launches directly into a preview of that file

### Requirement: Multi-file Markdown drop
Dropping multiple Markdown files at once (window or terminal area) SHALL open every file — as document tabs in the single split panel (or as window tabs when the user's open-mode is "tab") — never displaying only the last file. Dropping Markdown on the terminal SHALL open the preview instead of inserting shell paths; ⌘-drop keeps the shell-path insertion.

#### Scenario: Three files dropped
- **WHEN** the user drags three .md files onto the window
- **THEN** all three open as tabs and each is viewable

### Requirement: Markdown settings tab
Settings SHALL include a dedicated Markdown tab with: font size, reading width, table-of-contents visibility, animations, code line numbers, default code wrap, default open mode (split pane vs. new tab), and the sanitized raw-HTML toggle. Changes SHALL apply live to every open preview without reload.

#### Scenario: Live font-size change
- **WHEN** the user moves the Font Size slider while a preview is open
- **THEN** the preview's body text resizes immediately

#### Scenario: Open-mode default respected
- **WHEN** the user sets "Open Markdown files in: New Tab" and then drops a single .md file
- **THEN** the file opens as a tab instead of a split

### Requirement: Focus-based ⌘F routing
The shell SHALL route ⌘F to the preview's in-page search when a preview pane has key focus, and to the terminal search otherwise. Focus SHALL be switchable between the terminal and preview panes by click.

#### Scenario: Preview focused
- **WHEN** the preview pane has focus and the user presses ⌘F
- **THEN** the preview search overlay opens; the terminal search does not

#### Scenario: Terminal focused
- **WHEN** the terminal pane has focus and the user presses ⌘F
- **THEN** the existing terminal search behavior is triggered
