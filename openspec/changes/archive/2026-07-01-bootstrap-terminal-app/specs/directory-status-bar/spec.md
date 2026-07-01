## ADDED Requirements

### Requirement: Display current working directory
The toolbar SHALL display the shell's current working directory (CWD) and SHALL
update it whenever the CWD changes. The toolbar SHALL seed the CWD from the
terminal's initial working directory at launch, so a path is shown immediately —
before the shell emits its first OSC 7 sequence.

#### Scenario: CWD shown immediately on launch
- **WHEN** the terminal starts, before the shell has emitted any OSC 7 sequence
- **THEN** the toolbar already displays the terminal's initial working directory

#### Scenario: CWD reflects a Finder-opened folder at launch
- **WHEN** the terminal is opened at a folder via Finder integration
- **THEN** the toolbar shows that folder's path immediately, without waiting for the first prompt

#### Scenario: CWD updates after cd
- **WHEN** the user runs `cd` to another directory
- **THEN** the status bar updates to show the new directory path

#### Scenario: Home is abbreviated
- **WHEN** the CWD is under the user's home directory
- **THEN** the displayed path abbreviates the home prefix as `~`

### Requirement: Track CWD via OSC 7 with a fallback
The toolbar SHALL determine the CWD by parsing OSC 7 `file://` escape sequences
emitted by the shell. When OSC 7 is unavailable, the toolbar SHALL fall back to
resolving the working directory of the PTY's foreground process group — obtained
via the tty's foreground process group id (`tcgetpgrp`) and
`proc_pidinfo(PROC_PIDVNODEPATHINFO)` — rather than always using the shell's own
pid, so it reflects `cd` performed by the foreground program.

#### Scenario: OSC 7 updates the CWD
- **WHEN** the shell emits an OSC 7 sequence reporting a new directory
- **THEN** the toolbar parses the `file://` URL and displays the decoded path

#### Scenario: Fallback resolves the foreground process CWD
- **WHEN** the shell does not emit OSC 7 and the working directory changes
- **THEN** the toolbar resolves the CWD from the tty's foreground process group and displays it

#### Scenario: Fallback query is unavailable
- **WHEN** the foreground process CWD cannot be resolved (e.g. the query is denied)
- **THEN** the toolbar retains the last known CWD rather than showing an empty or incorrect path

### Requirement: Session start time and live duration timer
The toolbar SHALL display the date and time at which the terminal session (tab)
was opened, and a duration timer that counts up in real time from that moment for
as long as the session is open.

#### Scenario: Start time recorded on open
- **WHEN** a terminal session (tab) is opened
- **THEN** the toolbar displays the session's start date and time

#### Scenario: Duration counts up
- **WHEN** a session has been open for some elapsed time
- **THEN** the toolbar shows a duration that increases at least once per second (e.g. `HH:MM:SS`)

#### Scenario: Timer is per session
- **WHEN** more than one session (tab) exists
- **THEN** each session's toolbar reflects its own start time and duration, independent of the others

### Requirement: Folder icon reveals CWD in Finder
The toolbar SHALL show a folder icon that, when clicked, reveals the current
working directory in Finder. Reveal SHALL apply only to local paths: when OSC 7
reports a non-local host (e.g. during an SSH session) or the path does not exist
locally, the folder icon SHALL be disabled or indicate the directory is not
locally revealable, rather than opening a wrong path.

#### Scenario: Click reveals a local directory
- **WHEN** the CWD is a local directory and the user clicks the folder icon
- **THEN** Finder activates and selects the current working directory (via `NSWorkspace.activateFileViewerSelecting`)

#### Scenario: Reveals the up-to-date directory
- **WHEN** the CWD has changed since launch and the user clicks the folder icon
- **THEN** Finder reveals the current directory, not the original one

#### Scenario: Remote or nonexistent path is not revealed
- **WHEN** the OSC 7 host is not the local machine (e.g. inside `ssh`), or the path does not exist locally
- **THEN** the folder icon does not open Finder to an incorrect location (it is disabled or signals non-local)
