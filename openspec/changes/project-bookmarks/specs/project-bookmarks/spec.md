## ADDED Requirements

### Requirement: Read a per-project `.zTerminal.json`
The application SHALL read an optional `.zTerminal.json` file from the active tab's
current working directory. The file MAY contain a list of `bookmarks` and an optional
`theme` block; all keys are optional. A missing or unreadable file SHALL be treated as
absent (no error, no crash), and a malformed file SHALL NOT crash the app.

#### Scenario: Config is loaded from the current directory
- **WHEN** the active tab's CWD contains a `.zTerminal.json`
- **THEN** its bookmarks and theme are loaded and applied to that project's context

#### Scenario: Absent or malformed config is tolerated
- **WHEN** there is no `.zTerminal.json`, or it cannot be parsed
- **THEN** the app behaves as if no project config is present and does not crash

### Requirement: Bookmarks surface in a dedicated bookmark action
The application SHALL show a dedicated **bookmark** toolbar action (distinct from the
play/Run action used for auto-detected script-shortcuts) and SHALL present the project's
bookmarks in its popover. The bookmark action SHALL always be available (opening it where
no `.zTerminal.json` exists lets the user add the first bookmark, creating the file),
while the play/Run action SHALL be shown when — and only when — a manifest-based ecosystem
is present. The two actions MAY appear together. Each bookmark SHALL
show its name, its command, and its icon (an SF Symbol, defaulting to a star when the
icon is missing or unknown) tinted with its own optional `color` (a hex, defaulting to the
app accent color when unset). Selecting a bookmark SHALL run its command with the same
current-tab/new-tab rules as other tasks (current tab when idle, a new tab when busy or
on ⌘-activation).

#### Scenario: Bookmark action lists the bookmarks
- **WHEN** the user opens the bookmark action in a directory containing `.zTerminal.json` bookmarks
- **THEN** the bookmarks are listed, each row with its icon, name, and command

#### Scenario: Bookmark action shows without a build manifest
- **WHEN** a directory has a `.zTerminal.json` but no build manifest
- **THEN** the bookmark action is shown (exposing the bookmarks) even though the play/Run action is not

#### Scenario: Both actions can appear together
- **WHEN** a directory has both `.zTerminal.json` and a build manifest
- **THEN** the bookmark action and the play/Run action are both shown, each opening its own list

#### Scenario: Running a bookmark
- **WHEN** the user activates a bookmark
- **THEN** its command runs in the current tab if idle, or in a new tab in the same directory if the shell is busy or the user ⌘-activates it

### Requirement: Bookmark commands support run-time arguments
The application SHALL support run-time argument placeholders, written `<label>`, in a
bookmark command. When a command being run contains one or more placeholders, the
application SHALL prompt the user for a value per unique placeholder, substitute the
entered values into the command, and run the result. A command with no placeholders SHALL
run directly as before. Substitution SHALL fill every occurrence of a repeated placeholder
from a single value, and SHALL never crash on a missing value.

#### Scenario: Prompt for an argument before running
- **WHEN** the user runs a bookmark whose command contains `<pattern>` (e.g. `swift test --filter <pattern>`)
- **THEN** a prompt collects a value for `pattern`, and the substituted command runs (in the current or a new tab per the activation)

#### Scenario: Multiple and repeated placeholders
- **WHEN** a command has several `<label>` placeholders (some repeated)
- **THEN** the prompt shows one field per unique label and fills every occurrence from that field

#### Scenario: No placeholders runs directly
- **WHEN** a bookmark command has no `<...>` placeholder
- **THEN** it runs immediately with no prompt

### Requirement: Add, edit, and delete bookmarks from the app
The application SHALL let the user add, edit, and delete bookmarks (name, command, icon,
and color) from the bookmark popover, persisting each change to `.zTerminal.json` in the
project directory and creating the file if it does not exist. Changes SHALL be reflected
in the popover without requiring a restart.

#### Scenario: Add a custom command
- **WHEN** the user fills in a name and command (and optionally picks an icon and color) and confirms
- **THEN** the bookmark is written to `.zTerminal.json` and shown in the list

#### Scenario: Edit an existing bookmark
- **WHEN** the user edits a bookmark's name, command, icon, or color and confirms
- **THEN** the updated bookmark is written to `.zTerminal.json` and the list reflects the change

#### Scenario: Delete a bookmark
- **WHEN** the user deletes a bookmark
- **THEN** it is removed from `.zTerminal.json` and no longer shown

#### Scenario: File is created on first add
- **WHEN** the project has no `.zTerminal.json` and the user adds a bookmark
- **THEN** the file is created with the new bookmark

### Requirement: Cascading theme override (global then per-project)
The application SHALL resolve the active theme by cascading, in increasing priority:
the user's saved Settings, then the **global** `~/.zTerminal.json` `theme` block, then
the **project** `.zTerminal.json` `theme` block in the active tab's CWD. Each level
layers its provided fields over the lower level (a field absent at a higher level shows
the lower level through). The override SHALL be applied live and SHALL NOT overwrite the
user's saved Settings. When the active directory has no project theme, the global theme
SHALL be in effect; when neither is present, the user's Settings SHALL be in effect.

#### Scenario: Global theme is the default
- **WHEN** `~/.zTerminal.json` defines a `theme` and the active directory has no project `.zTerminal.json`
- **THEN** the global theme fields are applied

#### Scenario: Project theme overrides global
- **WHEN** the active tab's CWD has a `.zTerminal.json` `theme` block
- **THEN** its fields take priority over the global theme, and fields it omits fall through to the global (then Settings) values

#### Scenario: Reverts to global when the directory changes
- **WHEN** the user changes to a directory (or tab) that has no project theme
- **THEN** the global theme is restored (or the user's Settings if there is no global theme)

#### Scenario: Global Settings are never overwritten
- **WHEN** a project or global theme is applied and later cleared
- **THEN** the user's saved Settings values are unchanged, and reopening Settings shows the user's own configuration
