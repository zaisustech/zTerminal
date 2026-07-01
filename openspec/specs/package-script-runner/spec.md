# package-script-runner Specification

## Purpose
TBD - created by archiving change package-script-runner. Update Purpose after archive.
## Requirements
### Requirement: Show the Run action for recognized projects
The application SHALL show a Run action in the toolbar when — and only when — the
active tab's current working directory is recognized by at least one task source,
and SHALL update this visibility reactively as the CWD changes.

#### Scenario: Run icon appears in a recognized project
- **WHEN** the active tab's CWD contains a recognized manifest (e.g. `package.json`, `Cargo.toml`, `pom.xml`, `build.gradle`, `go.mod`, `manage.py`, `pyproject.toml`, or `Makefile`)
- **THEN** a Run icon is shown in the toolbar

#### Scenario: Run icon hidden elsewhere
- **WHEN** the CWD contains no recognized manifest
- **THEN** the Run icon is not shown

#### Scenario: Visibility follows CWD changes
- **WHEN** the user changes directory into or out of a recognized project
- **THEN** the Run icon appears or disappears accordingly

### Requirement: Detect multiple ecosystems and group tasks
The application SHALL support multiple task sources — Node, Rust (Cargo),
Java/Spring Boot (Maven and Gradle), Python (Django/pyproject/pytest), Go, and
Makefile — each contributing runnable tasks with the exact command they run. When
a directory matches more than one ecosystem, the popover SHALL group tasks by
source.

#### Scenario: Rust project lists cargo tasks
- **WHEN** the CWD contains `Cargo.toml`
- **THEN** the popover lists cargo tasks (e.g. `cargo run`, `cargo build`, `cargo test`)

#### Scenario: Spring Boot / Java project lists build tasks
- **WHEN** the CWD contains `pom.xml` (Maven) or `build.gradle`/`gradlew` (Gradle)
- **THEN** the popover lists the corresponding tasks (e.g. `mvn spring-boot:run` or `./gradlew bootRun`)

#### Scenario: Multiple ecosystems are grouped
- **WHEN** the CWD matches more than one ecosystem (e.g. a repo with both `package.json` and `Cargo.toml`)
- **THEN** the popover shows a separate group per source, each with its tasks

### Requirement: List runnable scripts with detected package manager
When the Run action is opened, the application SHALL read the `scripts` from the
active project's `package.json` and present them in a popover, each showing the
script name and its underlying command. It SHALL detect the package manager from
the lockfile or the `packageManager` field (bun, pnpm, yarn, or npm) and use it to
form the run command.

#### Scenario: Scripts are listed with previews
- **WHEN** the user opens the Run popover in a project with scripts
- **THEN** each script is listed with its name and the command it runs

#### Scenario: Package manager is detected
- **WHEN** the project has a `pnpm-lock.yaml` (or `yarn.lock`, `bun.lock*`, `package-lock.json`, or a `packageManager` field)
- **THEN** the run command uses the corresponding manager (e.g. `pnpm run <script>`)

#### Scenario: Multiple managers offer a choice
- **WHEN** more than one manager is detected (e.g. both `yarn.lock` and `package-lock.json`)
- **THEN** the popover shows a segmented control to pick the manager, defaulting to the preferred one, and the run commands follow the selection

#### Scenario: Malformed package.json
- **WHEN** the `package.json` cannot be parsed
- **THEN** the popover shows a clear error and the app does not crash

#### Scenario: No scripts present
- **WHEN** the `package.json` has no `scripts`
- **THEN** the popover indicates there are no scripts and offers an "Install dependencies" action

### Requirement: Run a selected script
The application SHALL run a selected script using the detected package manager. It
SHALL run in the current tab when that tab's shell is idle at a prompt, and in a
new tab (in the same working directory) when the shell is busy, informing the user
which occurred.

#### Scenario: Run in the current tab when idle
- **WHEN** the user selects a script and the current tab is idle at a prompt
- **THEN** the run command is executed in the current tab and appears in its scrollback

#### Scenario: Run in a new tab when busy
- **WHEN** the user selects a script while the current tab is running another program
- **THEN** a new tab opens in the same directory and the script runs there, so the busy shell is not disturbed

### Requirement: Run in a new tab on modifier-activate
The application SHALL run the selected script in a new tab (in the same working
directory) when the user activates it with the Command modifier (⌘-click or
⌘Enter), regardless of whether the current tab is idle.

#### Scenario: Command-click opens a new tab
- **WHEN** the user ⌘-clicks a script (or presses ⌘Enter on it)
- **THEN** a new tab opens in the project directory and runs the script there

#### Scenario: New tab shows its own session
- **WHEN** a script runs in a new tab
- **THEN** that tab has its own CWD, start time, and duration timer (per the toolbar), suitable for long-running dev servers

### Requirement: Searchable, keyboard-navigable, accessible popover
The Run popover SHALL be a glass popover that supports filtering by typing,
keyboard navigation (arrow keys to move, Enter to run in the current tab, ⌘Enter to
run in a new tab), and SHALL be fully accessible (focus states, VoiceOver labels).
It SHALL reflect changes to `package.json` when reopened.

#### Scenario: Filter scripts
- **WHEN** the user types in the popover's filter field
- **THEN** the script list narrows to matching scripts

#### Scenario: Keyboard run
- **WHEN** the user highlights a script with the arrow keys and presses Enter (or ⌘Enter)
- **THEN** the script runs in the current tab (or a new tab for ⌘Enter)

#### Scenario: Reflects updated scripts
- **WHEN** the `package.json` scripts change and the user reopens the popover
- **THEN** the updated list of scripts is shown

