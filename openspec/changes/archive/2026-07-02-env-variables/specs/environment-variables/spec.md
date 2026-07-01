## ADDED Requirements

### Requirement: Manage environment variables in a Settings tab
The application SHALL provide an **Environment** tab in the Settings window where the user can
add, edit, delete, and reorder **environment variables**. Each variable SHALL have a `key` (the
variable name), a `value` (its contents), and an `enabled` flag. The list SHALL be persisted with
the user's other settings and available across launches.

#### Scenario: Add a variable
- **WHEN** the user opens the Environment tab and adds a variable with key `NODE_ENV` and value `development`
- **THEN** the variable is saved and appears in the list, and persists after the app restarts

#### Scenario: Edit, delete, and reorder
- **WHEN** the user edits a variable's key or value, deletes it, or reorders the list
- **THEN** the change is persisted and reflected in the list

#### Scenario: Disable without deleting
- **WHEN** the user toggles a variable's `enabled` flag off
- **THEN** the variable is retained in the list but is not injected into new tabs

### Requirement: Inject variables into new terminal tabs
The application SHALL inject every enabled, valid environment variable into the shell it spawns for a
new tab, such that programs run in that tab observe the variable in their environment. Injection SHALL
use the shell the application already spawns (via `export` in the shell bootstrap it controls); the
application SHALL NOT require the user to edit `~/.zshrc`.

#### Scenario: Program sees the injected variable
- **WHEN** a `NODE_ENV → development` variable is enabled and the user opens a new tab and runs `echo $NODE_ENV`
- **THEN** the tab prints `development`

#### Scenario: Applies to new tabs
- **WHEN** the user adds or edits a variable while tabs are open
- **THEN** the variable is available in newly opened tabs (existing shells are unaffected until a new tab is opened)

### Requirement: Override inherited environment values
A defined environment variable SHALL take precedence over a same-named value inherited from the
application's parent-process environment, so the user's value is what programs in the tab observe. The
override SHALL also win over a same-named value exported by the user's shell rc.

#### Scenario: User value overrides an inherited value
- **WHEN** the parent environment already defines `EDITOR=vi` and the user defines `EDITOR → nvim`
- **THEN** a new tab observes `EDITOR` as `nvim`

#### Scenario: Override wins over the shell rc
- **WHEN** the user's `~/.zshrc` exports `PAGER=less` and the user defines `PAGER → bat`
- **THEN** a new tab observes `PAGER` as `bat`

### Requirement: Validate keys and safely embed values
The application SHALL validate each variable `key` and safely quote each `value` before injecting it
into the shell. A `key` SHALL match `^[A-Za-z_][A-Za-z0-9_]*$` and SHALL be unique within the list;
invalid or duplicate keys SHALL be rejected in the editor with a clear message. A `value` SHALL be
embedded so that quotes, `$`, backticks, and newlines cannot break the shell definition or inject
additional commands. A single malformed or unexpected entry SHALL NOT prevent the shell from reaching
a prompt.

#### Scenario: Invalid or duplicate key is rejected
- **WHEN** the user enters an empty key, a key with spaces or illegal characters (e.g. `MY-VAR` or `2FOO`), or a key already in the list
- **THEN** the editor blocks it with a clear validation message and does not save it

#### Scenario: Value with special characters is embedded safely
- **WHEN** a variable's value contains quotes, `$`, or backticks (e.g. `a'b"c $(whoami) \`date\``)
- **THEN** the tab exports exactly that literal value, and the special characters neither break shell startup nor execute as commands

#### Scenario: A bad entry does not break the shell
- **WHEN** one variable entry is malformed
- **THEN** the remaining variables are still exported and the tab still reaches a working prompt

### Requirement: Warn when a variable shadows an inherited value
The application SHALL warn the user, without blocking, when a `key` matches a variable already present
in the inherited environment, since the injected variable will override it.

#### Scenario: Shadowing warning
- **WHEN** the user defines a variable whose key already exists in the inherited environment (e.g. `PATH` or `HOME`)
- **THEN** the editor shows a non-blocking warning that it will override the inherited value, and still allows saving
