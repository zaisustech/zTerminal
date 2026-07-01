## ADDED Requirements

### Requirement: Bookmarks task source and per-task icons
The runner SHALL include a task source backed by the project's `.zTerminal.json`
bookmarks, recognized separately from the manifest-based ecosystems so it can back a
dedicated bookmark action distinct from the play/Run action. Runnable tasks MAY carry an
optional icon (an SF Symbol) and icon color that the popover displays; tasks without an
icon SHALL render as before.

#### Scenario: Bookmarks are separable from script-shortcuts
- **WHEN** a directory matches both `.zTerminal.json` and a build manifest
- **THEN** the runner can report bookmark tasks and manifest tasks independently, so each backs its own toolbar action

#### Scenario: Icons render for tasks that define them
- **WHEN** a task defines an icon (and optionally a color)
- **THEN** the popover row shows that icon in its color; tasks without an icon are unaffected
