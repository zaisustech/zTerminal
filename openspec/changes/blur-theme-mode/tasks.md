## 1. Mode

- [x] 1.1 Add `.glass` (label "Blur") to `AppearanceMode`; `colorScheme` → dark; `isGlass` flag
- [x] 1.2 Add `effectiveTerminalBackground` (translucent in Blur, opaque otherwise)

## 2. Rendering

- [x] 2.1 In Blur, set the terminal non-opaque + translucent bg and clear the inset container
- [x] 2.2 Apply live on mode change (make + updateNSView), keeping the vibrant ANSI palette

## 3. UI

- [x] 3.1 Add a Blur theme card to the Appearance section

## 4. Verification

- [x] 4.1 Run `openspec validate blur-theme-mode`
- [ ] 4.2 Manual: Blur shows the gradient through the terminal with legible colored text; other modes stay opaque
