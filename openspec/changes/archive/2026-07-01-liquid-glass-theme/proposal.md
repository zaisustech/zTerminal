## Why

zTerminal should feel like a premium, first-party macOS app the moment it opens.
A distinctive **Liquid Glass** visual identity — translucent materials over an
animated mesh gradient, with a full theme manager — differentiates it, follows
Apple's current design language, and makes the app immediately impressive.
(Reference mockup: an interactive Liquid Glass preview of zTerminal.)

## What Changes

- Introduce a **Liquid Glass** design system: translucent surfaces with backdrop
  blur, thin ~10–15% white borders, inset highlights, and soft drop shadows, so
  every panel floats above the background.
- Add an **animated mesh gradient** background (blue/purple/cyan/pink/emerald)
  that drifts subtly, GPU-accelerated, and honors Reduced Motion.
- Add a **theme manager**: Light, Dark, and System (follows macOS appearance).
- Add **customization**: primary accent, gradient colors, glass opacity, blur
  intensity, corner radius, window transparency, and animation speed — **persisted**
  across launches.
- Restyle **all components** (window/toolbar, sidebar, buttons, cards, inputs,
  menus/popovers, dialogs) to the glass system with fluid 200–350ms animations.
- Establish **typography** (San Francisco hierarchy), **SF Symbols** iconography,
  and **accessibility** (contrast, keyboard nav, VoiceOver, Reduced Motion).

## Capabilities

### New Capabilities
- `theme-system`: Theme modes (Light/Dark/System following macOS), user-customizable design tokens (accent, gradient, glass opacity, blur, corner radius, window transparency, animation speed), and persistence across launches.
- `liquid-glass-ui`: The visual layer — glass materials, animated mesh gradient background, consistently styled components, fluid animations, SF typography/iconography, and accessibility.

### Modified Capabilities
<!-- None as deltas: the bootstrap specs are not yet synced to openspec/specs/, so
     there is no base to diff against. The `app-shell` "iTerm-like appearance"
     requirement is superseded in spirit by `liquid-glass-ui`; reconcile when
     bootstrap-terminal-app is archived. -->


## Impact

- **New modules:** `Theme/` (ThemeManager, DesignTokens, GlassStyle view modifiers), `Background/` (animated mesh gradient view), a Settings/Appearance surface.
- **Rendering:** relies on macOS materials (`NSVisualEffectView` / SwiftUI `.background(.ultraThinMaterial)`), Metal/Core Animation for the gradient; must stay smooth at up to 120Hz (ProMotion) with low memory.
- **Persistence:** design tokens stored in `UserDefaults` (or a codable settings file).
- **Cross-cutting:** touches every view; `app-shell` appearance requirement is updated.
