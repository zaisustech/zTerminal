## 1. Theme foundation

- [x] 1.1 Define `DesignTokens` (accent, gradient colors, glassOpacity, blur, cornerRadius, windowTransparency, animationSpeed) as a Codable value with defaults
- [x] 1.2 Build `ThemeManager` (ObservableObject) holding tokens + mode; inject via `@EnvironmentObject`
- [x] 1.3 Persist to `UserDefaults` (debounced write, load at launch); implement "Reset to defaults"

## 2. Appearance modes

- [x] 2.1 Implement Light / Dark / System modes; explicit modes set the window `appearance`
- [x] 2.2 System mode observes `NSApp.effectiveAppearance` / `colorScheme` and updates live with no relaunch
- [x] 2.3 Animate the theme-switch transition (~250–300ms)

## 3. Liquid Glass materials

- [x] 3.1 Add a reusable `.glass()` view modifier: material + token-driven border (~10–15% white), inner highlight, drop shadow, corner radius
- [x] 3.2 Wrap the window in an `NSVisualEffectView` for window-level vibrancy
- [x] 3.3 Verify layered glass (popover over panel) stays legible and blur doesn't cancel out

## 4. Animated mesh gradient

- [x] 4.1 Implement the background with SwiftUI `MeshGradient` (macOS 15+) animated via `TimelineView`
- [x] 4.2 Add a blurred-radial-blob fallback for macOS 13–14
- [x] 4.3 Drive drift speed from the animationSpeed token; feed gradient colors from tokens

## 5. Component styling

- [x] 5.1 Buttons: glass surface, soft hover glow, smooth press animation, rounded corners
- [x] 5.4 Inputs: frosted fields with an accent focus ring and smooth transitions
- [x] 5.5 Menus/popovers and dialogs/sheets: glass with blur, rounded edges, subtle enter/exit animations
- [x] 5.6 Apply glass to the existing window chrome, bottom toolbar, and tab strip

## 6. Customization UI

- [x] 6.1 Build an Appearance settings surface: mode segmented control, accent swatches + custom color, gradient color pickers
- [x] 6.2 Add sliders for glass opacity, blur, corner radius, window transparency, animation speed — bound live to tokens
- [x] 6.3 Enforce safe bounds so extremes keep contrast and hit targets usable

## 7. Typography & icons

- [x] 7.1 Define the SF type scale (title / heading / body / secondary) as reusable text styles
- [x] 7.2 Standardize SF Symbols usage (sizes, accent tinting)

## 8. Accessibility & performance

- [x] 8.1 Honor `accessibilityReduceMotion` (freeze gradient, minimize transitions)
- [x] 8.2 Verify keyboard navigation + visible focus states and VoiceOver labels across all controls
- [x] 8.3 Verify contrast in Light/Dark/System at token extremes

## 9. Verification

- [x] 9.1 Manual pass against every spec scenario (modes, live tokens, persistence/reset, glass, gradient, components, animations, a11y)
- [x] 9.2 Run `openspec validate liquid-glass-theme` and fix any issues
