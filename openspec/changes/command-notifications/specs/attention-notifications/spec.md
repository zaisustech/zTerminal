## ADDED Requirements

### Requirement: Capture command boundaries and exit status via shell integration
The application SHALL inject shell integration into the spawned shell that marks when a
foreground command starts and finishes, carrying the command's exit code, so the app can
determine each command's duration and success/failure. These marks SHALL NOT appear in the
rendered terminal output, and SHALL be injected only for supported shells.

#### Scenario: Command result is captured
- **WHEN** a command runs to completion in a tab with shell integration active
- **THEN** the application knows the command's duration and its exit code

#### Scenario: Marks are invisible
- **WHEN** the shell emits the integration marks
- **THEN** they are consumed by the app and not shown in the terminal

### Requirement: Notify when a long command finishes in a background tab
The application SHALL post a notification when a foreground command finishes in a tab that is not the currently focused tab and its duration is at least the configured threshold, stating the command, its duration, and whether it succeeded or failed, and SHALL update the Dock badge (cleared on return, as with the bell). A command that finishes in the focused tab, or shorter than the threshold, SHALL NOT notify.

#### Scenario: Long command finishes while away
- **WHEN** a command that ran longer than the threshold finishes in an unfocused tab
- **THEN** a notification reports the command, its duration, and success or failure

#### Scenario: Focused tab does not notify
- **WHEN** a command finishes in the currently focused tab
- **THEN** no finish notification is posted

#### Scenario: Short command is ignored
- **WHEN** a command shorter than the threshold finishes in an unfocused tab
- **THEN** no finish notification is posted

### Requirement: Annotate commands with exit status and duration
The application SHALL display a compact indicator of the last command's exit status
(success/failure) and its elapsed duration.

#### Scenario: Success and failure are distinguishable
- **WHEN** a command exits with status 0 versus non-zero
- **THEN** the indicator distinguishes success from failure and shows the elapsed time

### Requirement: Configurable finish-notification threshold
The application SHALL provide a setting to enable/disable finish notifications and to set
the minimum duration ("long command" threshold) that triggers them.

#### Scenario: Adjust the threshold
- **WHEN** the user changes the threshold in Settings
- **THEN** only commands at least that long trigger finish notifications

#### Scenario: Disable the feature
- **WHEN** the user turns finish notifications off
- **THEN** no finish notifications are posted (the terminal bell behavior is unaffected)
