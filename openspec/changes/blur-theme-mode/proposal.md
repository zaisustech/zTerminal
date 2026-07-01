## Why

Light and Dark are opaque. Users want a distinctive **Blur** look where the
animated Liquid Glass gradient shows *through* the terminal itself — colorful text
floating on glass. This is a mode of its own, not a light/dark variant, and
completes the premium identity.

## What Changes

- Add **Blur** as a fourth theme mode alongside System / Light / Dark.
- In Blur mode the terminal background is **translucent** so the window's animated
  mesh gradient is visible behind the text; the vibrant ANSI palette keeps output
  colorful. Other modes remain opaque.
- Selectable from the Appearance theme cards; persisted; applied live.

## Capabilities

### New Capabilities
- `blur-theme-mode`: A translucent "Blur" terminal appearance mode that reveals the animated gradient behind the terminal content.

### Modified Capabilities
<!-- Extends the archived `theme-system` capability; no delta against it here. -->

## Impact

- `AppearanceMode` gains a `.glass` case (label "Blur"); `effectiveTerminalBackground`
  returns a translucent color in that mode.
- `TerminalHostView` clears the container/layer and sets the terminal non-opaque in Blur.
- No new dependencies.
