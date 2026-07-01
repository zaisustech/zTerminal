## ADDED Requirements

### Requirement: Open a file from the terminal in the editor
The application SHALL let the user ⌘-click a file path in the terminal to open it in the
configured editor. The clicked token SHALL be resolved as an absolute path or relative to
the active tab's current directory, and SHALL be treated as a link only when the resolved
file exists.

#### Scenario: Cmd-click a relative path from build output
- **WHEN** the user ⌘-clicks `src/app/foo.ts` printed by a build in a tab whose CWD contains that file
- **THEN** the file opens in the configured editor

#### Scenario: Non-file text is not a link
- **WHEN** the user ⌘-clicks a token that does not resolve to an existing file
- **THEN** nothing is opened and no error is shown

### Requirement: Open at a specific line and column
The application SHALL open a clicked file at the location given by a trailing `:line` or `:line:col` suffix on the path, and SHALL open a path with no suffix at the top of the file.

#### Scenario: Jump to a compiler error location
- **WHEN** the user ⌘-clicks `Sources/App/Foo.swift:42:10`
- **THEN** the editor opens `Foo.swift` positioned at line 42 (column 10 when supported)

### Requirement: Open the current directory in the editor
The status bar SHALL provide an "Open in editor" action that opens the active tab's
current directory in the configured editor.

#### Scenario: Open the working directory
- **WHEN** the user clicks the "Open in editor" status-bar button
- **THEN** the current directory opens as a project/folder in the configured editor

### Requirement: Choose the editor
The application SHALL provide a setting to choose the editor used for these actions —
a known editor (e.g. VS Code, Cursor, Xcode) or a custom command template with
`{file}`, `{line}`, and `{col}` placeholders — and SHALL fall back to the system default
open behavior when the chosen editor's command is unavailable.

#### Scenario: Custom editor command
- **WHEN** the user sets a custom command template and opens a file at a line
- **THEN** the template is invoked with the file, line, and column substituted

#### Scenario: Fallback when the CLI is missing
- **WHEN** the configured editor's command-line tool is not installed
- **THEN** the file or directory still opens via the system default, without crashing
