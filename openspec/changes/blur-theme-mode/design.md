## Context

The window already renders an animated mesh gradient behind a floating glass panel;
the terminal normally paints an opaque background over it. Blur mode makes the
terminal translucent so that gradient shows through.

## Goals / Non-Goals

**Goals:** a distinct translucent mode; legible colorful text; live switching.
**Non-Goals:** per-tab transparency; a transparency slider (fixed alpha for now).

## Decisions

### Decision: `.glass` case on `AppearanceMode`, `colorScheme` → dark
Blur is dark-based for contrast, so its SwiftUI `colorScheme` maps to `.dark`.
`isGlass` distinguishes it for background handling.

### Decision: Translucent background via `effectiveTerminalBackground`
`ThemeManager.effectiveTerminalBackground` returns `terminalBackground` at ~0.20
alpha in Blur, opaque otherwise. `TerminalHostView` applies it, sets the terminal
layer non-opaque, and clears the inset container so the panel material + gradient
behind show through.

### Decision: Fixed alpha (0.20)
Chosen for readable contrast over the gradient. A user-adjustable transparency
already exists for the window chrome; terminal-glass alpha is fixed to keep text legible.

## Risks / Trade-offs

- **SwiftTerm may fill its own opaque background** → if bleed-through doesn't show,
  fall back to compositing the gradient behind a fully-transparent terminal layer.
- **Legibility over bright gradient areas** → 0.20 alpha keeps a dark scrim; revisit if needed.

## Open Questions

- Should Blur expose a transparency slider like the window chrome?
