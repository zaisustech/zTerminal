## ADDED Requirements

### Requirement: Blur is a distinct theme mode
The application SHALL offer a Blur theme mode alongside System, Light, and Dark,
selectable from the Appearance theme cards and persisted across launches. Blur is
its own mode and SHALL NOT be treated as a Light/Dark variant.

#### Scenario: Selecting Blur
- **WHEN** the user selects the Blur theme card
- **THEN** the app switches to Blur mode and restores it on the next launch

### Requirement: Translucent terminal reveals the gradient
In Blur mode the terminal background SHALL be translucent so the window's animated
mesh gradient is visible behind the terminal content, while text remains legible
and colorful (the vibrant ANSI palette still applies). In non-Blur modes the
terminal background SHALL be opaque.

#### Scenario: Gradient shows through in Blur
- **WHEN** Blur mode is active
- **THEN** the animated gradient is visible behind the terminal text and colored output still renders clearly

#### Scenario: Opaque in other modes
- **WHEN** the mode is System, Light, or Dark
- **THEN** the terminal background is opaque (no gradient bleed-through)

#### Scenario: Live switch
- **WHEN** the user switches into or out of Blur while a terminal is open
- **THEN** the terminal background updates immediately without needing a new tab
