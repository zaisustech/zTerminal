## ADDED Requirements

### Requirement: Open a searchable command palette with ⌘K
The application SHALL provide a command palette opened with **⌘K** that presents a filter
field and a list of actions, filters the list as the user types (fuzzy match), and closes
on Escape or after an action is activated.

#### Scenario: Open and filter
- **WHEN** the user presses ⌘K and types part of an action's name
- **THEN** the palette opens and the list narrows to fuzzy-matching actions

#### Scenario: Dismiss
- **WHEN** the user presses Escape (or activates an action)
- **THEN** the palette closes

### Requirement: Aggregate actions from existing sources
The palette SHALL aggregate actions from: Global and Current-folder bookmarks, script
tasks detected in the current directory, the user's script shortcuts, open tabs, recent
directories, and app commands (new tab, open Settings, reveal in Finder, clear, restart).
When the filter is empty, actions SHALL be grouped by category; while filtering, they
SHALL be shown as a single ranked list.

#### Scenario: Actions from multiple sources
- **WHEN** the palette opens in a project with bookmarks, detected tasks, and shortcuts defined
- **THEN** items from each source appear, grouped by category

#### Scenario: Ranked results while searching
- **WHEN** the user types a query
- **THEN** matching items across all categories are shown in one list ranked by match quality

### Requirement: Activate actions with keyboard, honoring run semantics
The palette SHALL be fully keyboard-navigable (arrows to move, Return to activate,
⌘Return for a new tab). Activating a runnable action SHALL run it in the current tab when
the shell is idle, and in a new tab when the shell is busy or the user used ⌘Return.
Activating a tab action SHALL switch to that tab.

#### Scenario: Run in current vs new tab
- **WHEN** the user activates a runnable action with Return while the shell is idle
- **THEN** it runs in the current tab; **and WHEN** activated with ⌘Return (or the shell is busy), it runs in a new tab

#### Scenario: Switch tabs
- **WHEN** the user activates a tab action
- **THEN** the application switches to that tab

### Requirement: Track and jump to recent directories
The application SHALL maintain a persisted, de-duplicated, capped list of recently visited
directories (updated as the working directory changes) and expose them in the palette so
the user can jump the active tab (or a new tab) to a recent directory.

#### Scenario: Recent directory appears and is navigable
- **WHEN** the user has visited a directory and later opens the palette
- **THEN** that directory appears under recent directories, and activating it changes the working directory accordingly
