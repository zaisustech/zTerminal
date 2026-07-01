## ADDED Requirements

### Requirement: Liquid Glass materials
Panels (window chrome, toolbar, sidebar, cards, popovers, dialogs, inputs) SHALL
use a translucent glass material: backdrop blur with saturation, a thin white
border at ~10–15% opacity, a soft inner top highlight, and a soft drop shadow, so
each panel appears to float above the background. Glass surfaces SHALL layer
without their blur/borders visually canceling out.

#### Scenario: Panels read as floating glass
- **WHEN** any primary panel is displayed over the background
- **THEN** the background is visibly blurred through it and the panel shows a thin border, inner highlight, and drop shadow

#### Scenario: Layered translucency stays legible
- **WHEN** a glass panel (e.g. a popover) is shown over another glass panel
- **THEN** both remain distinct and their content stays legible

### Requirement: Animated mesh gradient background
The application SHALL render an animated mesh gradient background using the theme
gradient colors (defaults: blue, purple, cyan, pink, emerald) that drifts and
blends subtly to create depth. It SHALL be GPU-accelerated and SHALL not distract
from foreground content.

#### Scenario: Gradient animates subtly
- **WHEN** the app is open and Reduced Motion is off
- **THEN** the gradient colors slowly drift and blend without abrupt movement

#### Scenario: Gradient uses the theme colors
- **WHEN** the user changes the gradient colors
- **THEN** the animated background reflects the new colors

### Requirement: Consistently styled components
The application SHALL apply the glass system consistently to the terminal's chrome
components — window chrome, tab bar, bottom toolbar, buttons, inputs, and
menus/popovers — with consistent states: buttons have a soft hover glow and press
animation; the active tab shows an accent indicator; inputs show an accent focus
ring; menus and popovers appear as glass surfaces. All SHALL use rounded corners
driven by the corner-radius token. (A sidebar and card surfaces are out of scope —
a terminal window has neither.)

#### Scenario: Button hover and press
- **WHEN** the user hovers then presses a button
- **THEN** it shows a soft glow on hover and a smooth press animation on click

#### Scenario: Active tab indicator
- **WHEN** the user selects a tab
- **THEN** that tab shows an accent-tinted active indicator distinct from the others

#### Scenario: Input focus ring
- **WHEN** the user focuses a text input (e.g. the task-runner filter or a tab rename field)
- **THEN** an accent focus ring appears with a smooth transition

### Requirement: Fluid animations
The application SHALL animate UI state changes smoothly — hover, focus, window
appearance, theme switching, gradient movement, and tab selection — with primary
transitions in roughly the 200–350ms range.

#### Scenario: Theme switch is animated
- **WHEN** the user switches theme mode
- **THEN** the appearance transitions smoothly rather than snapping instantly

#### Scenario: Motion respects the transition range
- **WHEN** an interactive element changes state (hover/focus/selection)
- **THEN** the transition completes within a smooth, premium-feeling duration (~200–350ms)

### Requirement: Typography and iconography
The application SHALL use the San Francisco system font with a clear hierarchy
(large bold titles, medium section headings, comfortable body, subtle secondary
labels) and SF Symbols for icons at consistent sizes with accent tinting.

#### Scenario: Type hierarchy is distinct
- **WHEN** a view contains a title, headings, body text, and secondary labels
- **THEN** each level is visually distinguishable by size/weight/color

#### Scenario: Icons are consistent SF Symbols
- **WHEN** icons appear across the UI
- **THEN** they are SF Symbols at consistent sizes with accent-aware tinting

### Requirement: Accessibility and performance
The theme SHALL maintain sufficient contrast in every mode, support full keyboard
navigation and VoiceOver, and honor Reduced Motion by disabling or minimizing the
gradient and non-essential animations. Effects SHALL be GPU-accelerated and remain
smooth (targeting up to 120Hz on ProMotion) with low memory use.

#### Scenario: Reduced Motion is honored
- **WHEN** the system Reduced Motion setting is enabled
- **THEN** the gradient animation and non-essential transitions stop or minimize, while the app stays fully usable

#### Scenario: Keyboard and VoiceOver
- **WHEN** the user navigates with the keyboard or VoiceOver
- **THEN** all interactive controls are reachable, focusable with a visible focus state, and correctly labeled

#### Scenario: Contrast is preserved across modes
- **WHEN** the app is in Light, Dark, or System mode over the gradient
- **THEN** text and controls meet legible contrast against their glass surfaces
