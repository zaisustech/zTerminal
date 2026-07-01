## ADDED Requirements

### Requirement: Right-click a selected folder to open it in the terminal
The system SHALL register a macOS Services entry labeled "zTerminal" that appears
when the user right-clicks one or more selected folders in Finder and opens the
terminal at the selected folder.

#### Scenario: Entry appears for a selected folder
- **WHEN** the user right-clicks a selected folder in Finder
- **THEN** a "zTerminal" entry is shown in the context (Services) menu

#### Scenario: Entry acts on the selected folder
- **WHEN** the user invokes the "zTerminal" Services entry on a selected folder
- **THEN** the app opens a terminal at that folder

### Requirement: Open the current Finder folder from the window background
The system SHALL provide a Finder Sync app-extension that contributes a
"zTerminal" context-menu item when the user right-clicks the background of an open
Finder window, targeting the folder that window is displaying.

#### Scenario: Entry available from Finder background
- **WHEN** the user right-clicks the empty background of an open Finder window
- **THEN** a "zTerminal" item is shown that opens a terminal at the currently displayed folder

#### Scenario: Extension unavailable
- **WHEN** the Finder Sync extension is not enabled (e.g. app not signed/approved)
- **THEN** the Services entry (selected-folder path) still works, so the feature degrades gracefully

### Requirement: Open a terminal at the selected folder
When the "zTerminal" entry is invoked, the system SHALL activate the app and open
a terminal session whose shell starts in (is `cd`'d to) the selected folder.

#### Scenario: New terminal starts in the selected folder
- **WHEN** the user invokes "zTerminal" on a folder
- **THEN** the app opens a terminal whose current working directory is that folder, and the toolbar shows that folder's path

#### Scenario: App already running
- **WHEN** the app is already running and the user invokes "zTerminal" on a folder
- **THEN** the app is brought to the foreground and opens a new terminal (tab/window) in that folder rather than launching a second instance

#### Scenario: Path passed safely
- **WHEN** the selected folder path contains spaces or unicode characters
- **THEN** the terminal still starts in the correct directory (the path is passed as a URL/argument, not shell-interpolated)

### Requirement: Validate the incoming path
The app SHALL validate any path received through the "open at path" entry point
(reachable via the registered `zterminal://open?path=...` URL scheme) before
opening a terminal. The path MUST resolve to an existing local directory and be
canonicalized; the app SHALL reject it if it is not a directory or not a local
file path.

#### Scenario: Nonexistent or non-directory path is rejected
- **WHEN** an `open at path` request references a path that does not exist or is a file, not a directory
- **THEN** the app does not spawn a shell there and surfaces no error dialog loop (the request is ignored or reported)

#### Scenario: Path is canonicalized
- **WHEN** an incoming path contains `..`, symlinks, or a trailing slash
- **THEN** the app resolves it to a canonical existing directory before starting the shell there
