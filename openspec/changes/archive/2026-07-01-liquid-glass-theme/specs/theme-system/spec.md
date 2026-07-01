## ADDED Requirements

### Requirement: Theme modes (Light, Dark, System)
The application SHALL provide three theme modes — Light, Dark, and System — and
SHALL apply the selected mode across the entire UI. In System mode the app SHALL
follow the macOS appearance and update live when it changes.

#### Scenario: Switch to Light or Dark
- **WHEN** the user selects Light or Dark
- **THEN** the entire interface adopts that appearance immediately

#### Scenario: System mode follows macOS
- **WHEN** the mode is System and macOS switches between light and dark appearance
- **THEN** the app updates its appearance to match without a relaunch

### Requirement: Customizable design tokens
The application SHALL let the user customize the primary accent color, the
gradient colors, glass opacity, blur intensity, corner radius, window
transparency, and animation speed, and SHALL apply each change live to the UI.

#### Scenario: Accent color applies everywhere
- **WHEN** the user picks a new accent color
- **THEN** accent-tinted elements (active indicators, focus rings, primary buttons) update to the new color

#### Scenario: Continuous token adjusts live
- **WHEN** the user drags a slider for glass opacity, blur, corner radius, window transparency, or animation speed
- **THEN** the affected surfaces update in real time as the value changes

#### Scenario: Terminal font and background are customizable
- **WHEN** the user picks a different monospaced font, font size, or terminal background color in Settings
- **THEN** the terminal re-renders with the chosen font/size and background, and the choice persists across launches

#### Scenario: Values stay within safe bounds
- **WHEN** any token is set to its minimum or maximum
- **THEN** the UI remains legible and usable (e.g. text contrast and hit targets are preserved)

### Requirement: Persist settings across launches
The application SHALL persist all theme settings (mode, accent, gradient, and each
token) and SHALL restore them on the next launch.

#### Scenario: Settings survive relaunch
- **WHEN** the user customizes the theme and later relaunches the app
- **THEN** the app restores the previously chosen mode, accent, and token values

#### Scenario: Reset to defaults
- **WHEN** the user chooses "Reset to defaults"
- **THEN** all theme settings return to their default values and persist
