## ADDED Requirements

### Requirement: Keep the Mac awake while working
The application SHALL provide a Keep Awake setting with modes Off, While Busy, and
Always. When Always is selected the application SHALL hold an idle-system-sleep
assertion continuously; when While Busy is selected it SHALL hold the assertion
only while at least one tab is running a foreground program, releasing it when all
tabs are idle at a prompt; when Off it SHALL hold no assertion. The setting SHALL
persist across launches and SHALL be reachable from both Settings and a menu command.

#### Scenario: Always keeps the system awake
- **WHEN** Keep Awake is set to Always
- **THEN** the system does not idle-sleep while the app runs (the display may still sleep), regardless of terminal activity

#### Scenario: While Busy tracks activity
- **WHEN** Keep Awake is set to While Busy and a tab starts a long-running program
- **THEN** the assertion is held; and **WHEN** all tabs return to an idle prompt, the assertion is released

#### Scenario: Off holds nothing
- **WHEN** Keep Awake is Off
- **THEN** the app holds no sleep assertion and normal system sleep applies

#### Scenario: Persists and is toggleable
- **WHEN** the user changes the mode in Settings or via the menu command and relaunches
- **THEN** the previously selected mode is restored
