## ADDED Requirements

### Requirement: Notify when a background tab needs attention
The application SHALL treat the terminal bell as an attention signal: when a tab
rings the bell while it is not the active, focused tab, the application SHALL post
a user notification identifying that tab and SHALL increment the Dock icon badge
count. When the tab is the active, focused one, no notification is posted.

#### Scenario: Bell in an unfocused tab notifies
- **WHEN** a program (e.g. an AI CLI awaiting confirmation) rings the bell in a tab that is not active/focused
- **THEN** a user notification is posted naming that tab and the Dock icon badge count increases

#### Scenario: Bell in the focused tab does not nag
- **WHEN** the bell rings in the tab the user is currently viewing (app active, tab active)
- **THEN** no notification is posted and the badge is not incremented

### Requirement: Clear the badge on return
The application SHALL clear a tab's pending-attention state — updating the Dock
badge accordingly — when that tab becomes the active, focused tab (via selection
or app activation).

#### Scenario: Returning clears the badge
- **WHEN** the user activates the app or selects a tab that had pending attention
- **THEN** that tab's contribution to the Dock badge count is removed (and the badge hides when the count reaches zero)
