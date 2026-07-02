## ADDED Requirements

### Requirement: Capture executed commands via shell integration
The application SHALL capture the text of every command executed in a session by extending
the OSC 133 shell integration so the command text is emitted with the command-start marker
(from zsh `preexec`'s argument and bash's `$BASH_COMMAND`), transport-encoded so multiline
and quoted commands survive intact. Capture SHALL be independent of the shell's own history
file and SHALL degrade to no capture (never to an error) when the integration is not loaded.

#### Scenario: A run command is captured
- **WHEN** the user runs a command at the prompt
- **THEN** that command's exact text is recorded in the command history store

#### Scenario: Multiline or quoted command
- **WHEN** the executed command contains quotes, spaces, or newlines
- **THEN** the recorded text preserves the command exactly as executed

### Requirement: Global, persisted, de-duplicated history store
The application SHALL maintain a single command history shared across all tabs and windows,
persisted to disk so it survives app restarts, capped to a maximum size, and de-duplicated
most-recent-wins: re-running an identical command SHALL move it to the front rather than
create a duplicate. A freshly opened tab SHALL have access to the existing history.

#### Scenario: Shared across tabs and persisted
- **WHEN** the user runs a command in one tab, then opens a new tab (or restarts the app)
- **THEN** that command is present in history and available to the new tab

#### Scenario: Re-running de-duplicates
- **WHEN** the user runs a command that is already in history
- **THEN** the history contains a single entry for it, moved to the most-recent position

#### Scenario: Cap enforced
- **WHEN** the number of stored commands would exceed the cap
- **THEN** the oldest entries are trimmed so the store stays within the cap

### Requirement: Commands can be excluded from history
The application SHALL NOT record empty commands, its own internal shell-integration helper
commands, or any command the user enters with a leading space (matching the shell convention
for opting a command out of history).

#### Scenario: Leading-space opt-out
- **WHEN** the user runs a command typed with a leading space
- **THEN** the command executes but is not added to the history store

#### Scenario: Internal helpers are not recorded
- **WHEN** the shell integration runs its own internal helper commands
- **THEN** those commands do not appear in the history store

### Requirement: Inline ghost autosuggestion at the prompt
The terminal SHALL display, while the shell is idle at the prompt and the user has typed at
least one character, the most recent history entry that begins with the typed text as dim
ghost text showing the remaining suffix after the cursor. The suggestion SHALL update on each
keystroke and SHALL disappear when no history entry matches the typed prefix. The ghost text
SHALL be a visual overlay only and SHALL NOT be sent to the shell unless accepted.

#### Scenario: Suggestion appears while typing
- **WHEN** the user types a prefix that matches the start of a recent command
- **THEN** the remaining characters of that command are shown as dim ghost text after the cursor

#### Scenario: Most-recent match wins
- **WHEN** more than one history entry begins with the typed prefix
- **THEN** the suggestion shown is the most recently used matching entry

#### Scenario: No match hides the suggestion
- **WHEN** the typed prefix matches no history entry
- **THEN** no ghost text is shown

#### Scenario: Suggestion is not committed until accepted
- **WHEN** a ghost suggestion is visible and the user has not accepted it
- **THEN** the shell's line buffer contains only what the user actually typed (the ghost is not sent)

### Requirement: Accept the suggestion with Tab, else fall through to shell completion
When a ghost suggestion is visible and the shell is idle at the prompt, pressing **Tab** SHALL
fill the remaining suggested text into the prompt. When no ghost suggestion is visible,
pressing **Tab** SHALL be forwarded to the shell so its native completion behaves exactly as
it does without this feature.

#### Scenario: Tab accepts the visible suggestion
- **WHEN** a ghost suggestion is visible and the user presses Tab
- **THEN** the prompt line is completed to the full suggested command

#### Scenario: Tab falls through when there is no suggestion
- **WHEN** no ghost suggestion is visible and the user presses Tab
- **THEN** the keystroke reaches the shell and triggers its own completion

### Requirement: Suppress suggestions when they cannot be trusted
The terminal SHALL NOT show a ghost suggestion while the shell is busy running a command,
while a full-screen program owns the alternate screen, or when the current input line cannot
be determined.

#### Scenario: No suggestion while a program is running
- **WHEN** a command is running (the shell is not idle at the prompt)
- **THEN** no ghost suggestion is shown

#### Scenario: No suggestion inside a full-screen program
- **WHEN** a full-screen program (e.g. `vim`) is on the alternate screen
- **THEN** no ghost suggestion is shown over its interface
