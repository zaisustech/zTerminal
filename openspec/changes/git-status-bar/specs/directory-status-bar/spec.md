## ADDED Requirements

### Requirement: Show git branch and state in the status bar
When the active tab's current directory is inside a git work tree, the status bar SHALL
show the current branch (or a short commit SHA when HEAD is detached), a dirty indicator
when there are uncommitted changes, and ahead/behind counts relative to the upstream when
one is configured.

#### Scenario: Branch and dirty state
- **WHEN** the active tab's CWD is a git repo with uncommitted changes on branch `main`
- **THEN** the status bar shows `main` with a dirty indicator

#### Scenario: Ahead/behind vs upstream
- **WHEN** the current branch is 2 commits ahead and 1 behind its upstream
- **THEN** the status bar shows ahead/behind counts (e.g. ↑2 ↓1)

#### Scenario: Detached HEAD
- **WHEN** HEAD is detached
- **THEN** the status bar shows a short commit SHA instead of a branch name

### Requirement: Refresh git state on directory change and command completion
The git segment SHALL refresh when the working directory changes and when a foreground
command finishes (the shell returns to its prompt), without periodic polling.

#### Scenario: Updates after a commit
- **WHEN** the user commits or pulls and the shell returns to the prompt
- **THEN** the git segment updates to reflect the new state (e.g. dirty clears, ahead/behind changes)

#### Scenario: Updates on directory change
- **WHEN** the user changes into a different repository
- **THEN** the git segment updates to that repository's branch and state

### Requirement: Quick git actions from the status bar
Clicking the git segment SHALL present quick actions (at least status, pull, push, stash,
fetch) that run in the tab using the standard run semantics (current tab when idle, a new
tab when busy).

#### Scenario: Run a quick action
- **WHEN** the user clicks the git segment and chooses "pull" while the shell is idle
- **THEN** `git pull` runs in the current tab

### Requirement: Hide the git segment outside a repository
When the active tab's current directory is not inside a git work tree, the status bar SHALL
NOT show a git segment.

#### Scenario: Non-repo directory
- **WHEN** the CWD is not part of any git repository
- **THEN** no git segment is shown and the bar appears as it does without this feature
