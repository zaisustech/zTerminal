## ADDED Requirements

### Requirement: Track where prompt input begins
The application SHALL extend the OSC 133 shell integration to emit a prompt-end (`B`) marker,
and SHALL record the cursor column and row at that marker so the current prompt input can be
read as the buffer text from that column to the cursor. When no prompt-end marker has been
seen for the current line, or the cursor is not on the recorded prompt row, the input line
SHALL be treated as unresolved.

#### Scenario: Prompt-end marker records the input column
- **WHEN** the shell renders a prompt and emits the prompt-end marker
- **THEN** the application records the column at which the user's input will begin

#### Scenario: Unresolved input hides suggestions
- **WHEN** no prompt-end marker is available for the current line (e.g. a prompt that rebuilds itself each render)
- **THEN** no ghost suggestion is shown

### Requirement: Complete package.json script names for the detected package manager
The terminal SHALL show, while the shell is idle at the prompt, a dim ghost-text suffix
completing a `package.json` script name from the current directory when the typed command word
is a package manager **detected for that directory** (from the lockfile — `bun.lockb`/`bun.lock`,
`pnpm-lock.yaml`, `yarn.lock`, `package-lock.json` — or the `packageManager` field) and the
cursor is in a script position for that manager: `<manager> run <partial>` for any manager, and
additionally the bare `<manager> <partial>` for managers that run scripts without `run`
(bun, pnpm, yarn — but not npm). The suggestion SHALL be the most-relevant script that has the
typed partial as a prefix and is strictly longer than it, showing only the remaining characters
after the cursor. Preferred scripts (e.g. `dev`, `start`) SHALL rank first when the partial is
empty. When the command word is not a detected manager, no script matches, or the position is
not a script slot, no suggestion SHALL be shown.

#### Scenario: Completing a script for the project's manager
- **WHEN** a `yarn.lock` project has a `dev` script and the user has typed `yarn de`
- **THEN** the remaining `v` is shown as dim ghost text (yarn runs scripts without `run`)

#### Scenario: npm requires `run`
- **WHEN** a `package-lock.json` project has a `build` script and the user has typed `npm run bu`
- **THEN** the remaining `ild` is shown; typing `npm bu` shows nothing (npm has no bare script run)

#### Scenario: Suggestions respect the lockfile
- **WHEN** the project's lockfile indicates yarn and the user has typed `bun run d`
- **THEN** no ghost suggestion is shown (bun is not the detected manager)

#### Scenario: Empty partial suggests a preferred script
- **WHEN** the user has typed `bun run ` (trailing space) in a bun project with `dev` and `build`
- **THEN** the ghost suggests `dev` (a preferred name ranked first)

#### Scenario: No suggestion outside a script slot
- **WHEN** the user has typed `bun install ` or `bun run dev ` or a non-manager command
- **THEN** no ghost suggestion is shown

#### Scenario: No suggestion when nothing matches
- **WHEN** the user has typed `bun run zz` and no script name begins with `zz`
- **THEN** no ghost suggestion is shown

### Requirement: Accept the suggestion with Tab, else fall through to shell completion
When a ghost suggestion is visible and the shell is idle at the prompt, pressing **Tab** SHALL
fill the remaining suggested text into the prompt (sent to the shell). When no ghost suggestion
is visible, pressing **Tab** SHALL reach the shell unchanged so its native completion behaves
exactly as without this feature. The ghost text SHALL be a visual overlay only and SHALL NOT
be sent to the shell unless accepted.

#### Scenario: Tab accepts the visible suggestion
- **WHEN** a ghost suggestion is visible and the user presses Tab
- **THEN** the prompt line is completed to the full suggested command

#### Scenario: Tab falls through when there is no suggestion
- **WHEN** no ghost suggestion is visible and the user presses Tab
- **THEN** the keystroke reaches the shell and triggers its own completion

#### Scenario: Suggestion is not committed until accepted
- **WHEN** a ghost suggestion is visible and the user has not accepted it
- **THEN** the shell's line buffer contains only what the user actually typed

### Requirement: Suppress suggestions when they cannot be trusted
The terminal SHALL NOT show a ghost suggestion while the shell is busy running a command,
while a full-screen program owns the alternate screen, or when the current input line cannot
be determined. The suggestion SHALL update as the user types and SHALL be repositioned or
hidden as the terminal content scrolls, resizes, or switches buffers.

#### Scenario: No suggestion while a command runs
- **WHEN** a command is running (the shell is not idle at the prompt)
- **THEN** no ghost suggestion is shown

#### Scenario: No suggestion inside a full-screen program
- **WHEN** a full-screen program (e.g. `vim`) is on the alternate screen
- **THEN** no ghost suggestion is shown over its interface

### Requirement: Pluggable suggestion sources
The suggestion engine SHALL consult an ordered list of suggestion sources and use the first
source that returns a non-empty suffix, so that additional sources (e.g. command history) can
reuse the same overlay and accept behavior without changing the overlay.

#### Scenario: First matching source wins
- **WHEN** more than one source could suggest for the current input
- **THEN** the suffix from the earliest source in the list is shown
