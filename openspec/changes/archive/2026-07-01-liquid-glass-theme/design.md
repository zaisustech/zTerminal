## Context

zTerminal is a SwiftUI + AppKit macOS app (see `bootstrap-terminal-app`). This
change layers a premium **Liquid Glass** visual identity and a theme manager on
top. A working reference mockup (animated mesh gradient, glass panels, live theme
customizer) validates the direction; this design translates it to native SwiftUI.

## Goals / Non-Goals

**Goals:**
- A cohesive glass design system applied to every component.
- Light/Dark/System modes plus live, persisted customization of design tokens.
- Smooth, GPU-accelerated visuals (up to 120Hz), Reduced-Motion aware, accessible.

**Non-Goals:**
- Per-tab or per-profile themes (single app-wide theme for now).
- A full theme marketplace / import-export of themes.
- Terminal color-scheme editing (ANSI palette) — tracked separately from chrome theming.

## Decisions

### Decision: Central `ThemeManager` (ObservableObject) + `DesignTokens`
A single `ThemeManager` (injected via `@EnvironmentObject`) holds the current
`DesignTokens` (accent, gradient colors, glassOpacity, blur, cornerRadius,
windowTransparency, animationSpeed) and the mode. Views read tokens through the
environment so changes apply live. Rationale: one source of truth, trivial live
updates, easy persistence. Alternative — scattered `@AppStorage` per view —
rejected (hard to keep consistent, no single reset).

### Decision: Materials via SwiftUI + `NSVisualEffectView`
Use SwiftUI `.background(.ultraThinMaterial)` / `.regularMaterial` where it
suffices, and an `NSVisualEffectView` (via `NSViewRepresentable`) for window-level
vibrancy. A reusable `.glass(_:)` view modifier applies material + token-driven
border, inner highlight, shadow, and corner radius. Rationale: native materials
are GPU-accelerated and match Apple's look; the modifier keeps every panel
consistent.

### Decision: Animated mesh gradient via `MeshGradient` (macOS 15+) with fallback
Prefer SwiftUI `MeshGradient` (macOS 15+) animated with a `TimelineView`; on
macOS 13–14 fall back to drifting blurred radial-gradient blobs (`Canvas` or
layered gradients) — the same technique as the mockup. Animation duration derives
from the animation-speed token. Rationale: `MeshGradient` is purpose-built and
cheap on the GPU; the fallback keeps the deployment target at 13.

### Decision: System mode via `NSApp.effectiveAppearance` / `colorScheme`
System mode observes the effective appearance and updates tokens' derived
neutrals live. Explicit Light/Dark override the window's `appearance`. Rationale:
matches "follow macOS appearance" with no relaunch.

### Decision: Persistence in `UserDefaults` via a Codable snapshot
`DesignTokens` + mode encode to a single Codable value stored in `UserDefaults`
(key `theme.settings`), written on change (debounced) and loaded at launch.
"Reset to defaults" clears it. Rationale: small, structured, atomic; a settings
file is unnecessary at this size.

### Decision: Reduced Motion & performance
Honor `accessibilityReduceMotion`: freeze the gradient and drop non-essential
transitions. Keep animations in the 200–350ms band with `.easeOut`/spring. Avoid
stacking many large `backdrop`-blur layers; cap blur radius and reuse one
background layer behind the window rather than blurring per card where possible.
Target ProMotion 120Hz; profile with Instruments (Core Animation, Metal).

## Risks / Trade-offs

- **Blur/vibrancy is expensive when over-layered** → One shared background + a bounded blur token; measure on Intel + Apple Silicon.
- **`MeshGradient` requires macOS 15** → Feature-detect; blurred-blob fallback for 13–14.
- **Glass over a busy gradient hurts contrast** → Enforce a minimum surface opacity floor and text-contrast check at token extremes.
- **Terminal legibility vs. transparency** → Keep the terminal text layer opaque enough; window-transparency token affects chrome, not the glyph contrast.
- **Reduced Motion / accessibility regressions** → Include them in the acceptance pass, not as an afterthought.

## Migration Plan

Additive and greenfield-adjacent: applies over the bootstrap UI. Rollback =
disable the theme layer (fall back to a plain window). No data migration.

## Follow-ups (deferred)

- **Instruments profiling** (Core Animation / Metal) to confirm smooth 120Hz on
  ProMotion and low memory was not run in this environment; track as a
  performance-verification follow-up on real hardware.

## Open Questions

- Minimum deployment target: stay macOS 13 (with fallback) vs. raise to 15 for native `MeshGradient`?
- Should window-transparency affect the terminal background or only the chrome?
- Ship a small set of curated presets in addition to free-form tokens?
