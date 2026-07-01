## ADDED Requirements

### Requirement: Manage script shortcuts in a Settings tab
The application SHALL provide a **Scripts** tab in the Settings window where the user can
add, edit, delete, and reorder **script shortcuts**. Each shortcut SHALL have a `name` (the
word typed at the prompt) and a `command` (what runs). The list SHALL be persisted with the
user's other settings and available across launches.

#### Scenario: Add a shortcut
- **WHEN** the user opens the Scripts tab and adds a shortcut with name `zaisus` and command `bun run start`
- **THEN** the shortcut is saved and appears in the list, and persists after the app restarts

#### Scenario: Edit and delete
- **WHEN** the user edits a shortcut's name or command, or deletes it
- **THEN** the change is persisted and reflected in the list

### Requirement: Run a shortcut by typing its name at the prompt
The application SHALL make each defined shortcut runnable by typing its `name` at the shell
prompt of a zTerminal tab, such that pressing Enter executes the mapped `command`.
Shortcuts SHALL be injected into the shell the application spawns (as a shell alias or
function) so the shell performs the expansion; the application SHALL NOT rely on
intercepting typed keystrokes. Extra arguments typed after the name SHALL be forwarded to
the command.

#### Scenario: Typed shortcut runs the mapped command
- **WHEN** a `zaisus → bun run start` shortcut exists and the user types `zaisus` and Enter in a tab
- **THEN** `bun run start` is executed in that tab and appears in its scrollback

#### Scenario: Arguments are forwarded
- **WHEN** the user types `zaisus --watch`
- **THEN** the command runs as `bun run start --watch`

#### Scenario: Applies to new tabs
- **WHEN** the user adds or edits a shortcut while tabs are open
- **THEN** the shortcut is available in newly opened tabs (existing shells are unaffected until a new tab is opened)

### Requirement: Global scope, distinct from project bookmarks
Script shortcuts SHALL be **global** — available in every tab regardless of the current
working directory — and SHALL be independent of per-project `.zTerminal.json` bookmarks.

#### Scenario: Available in any directory
- **WHEN** the user opens a tab in any directory
- **THEN** all defined shortcuts are usable there, whether or not the directory has a `.zTerminal.json`

### Requirement: Validate names and safely embed commands
The application SHALL validate each shortcut `name` and safely quote each `command` before
injecting it into the shell. A `name` SHALL match `^[A-Za-z_][A-Za-z0-9_-]*$`, SHALL NOT be
a shell keyword, and SHALL be unique within the list; invalid or duplicate names SHALL be
rejected in the editor with a clear message. A `command` SHALL be embedded so that quotes,
`$`, backticks, and newlines cannot break the shell definition or inject additional
commands. A single malformed or unexpected entry SHALL NOT prevent the shell from reaching
a prompt.

#### Scenario: Invalid or duplicate name is rejected
- **WHEN** the user enters an empty name, a name with spaces or illegal characters, a shell keyword, or a name already in the list
- **THEN** the editor blocks it with a clear validation message and does not save it

#### Scenario: Command with special characters is embedded safely
- **WHEN** a shortcut's command contains quotes, `$`, or backticks (e.g. `echo "$USER" \`date\``)
- **THEN** typing the shortcut runs exactly that command, and the special characters neither break shell startup nor inject other commands

#### Scenario: A bad entry does not break the shell
- **WHEN** one shortcut entry is malformed
- **THEN** the remaining shortcuts are still installed and the tab still reaches a working prompt

### Requirement: Warn when a shortcut shadows an existing command
The application SHALL warn the user, without blocking, when a shortcut `name` matches a
known shell builtin or a command on the user's `PATH`, since the shortcut will override it.

#### Scenario: Shadowing warning
- **WHEN** the user names a shortcut `ls` (or another existing command/builtin)
- **THEN** the editor shows a non-blocking warning that it will override the existing command, and still allows saving
