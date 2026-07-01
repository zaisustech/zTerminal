## 1. Model & persistence

- [x] 1.1 Add `ScriptShortcut { name: String, command: String }` (Codable, Identifiable, Equatable)
- [x] 1.2 Add `scriptShortcuts: [ScriptShortcut] = []` to `DesignTokens`, decoding-tolerant (absent → `[]`)
- [x] 1.3 Name validation helper: `^[A-Za-z_][A-Za-z0-9_-]*$`, reject shell keywords, empty, and duplicates
- [x] 1.4 Command quoting helper (single-quote wrap with `'\''` escaping) — unit-tested for quotes/`$`/backticks/newlines

## 2. Shell injection

- [x] 2.1 Extend the shell bootstrap to emit one guarded function per shortcut, **after** sourcing `~/.zshrc`
- [x] 2.2 Emit valid syntax for both zsh and bash; skip injection for unsupported `$SHELL`
- [x] 2.3 Ensure a malformed/unexpected entry is skipped, not fatal (shell still reaches a prompt)

## 3. Settings UI

- [x] 3.1 Add a **Scripts** tab to `SettingsView` (icon e.g. `text.badge.plus` / `command`)
- [x] 3.2 List rows (name + command) with add / edit / delete / reorder
- [x] 3.3 Inline validation: bad/duplicate names blocked with a clear message
- [x] 3.4 Collision warning when a name shadows a known command/builtin (non-blocking)
- [x] 3.5 Help text: applies to new tabs; precedence over `~/.zshrc` aliases

## 4. Verification

- [x] 4.1 Unit-test name validation and command quoting (injection attempts, edge chars)
- [ ] 4.2 Manual: define `zaisus → bun run start`; open a new tab; type `zaisus` → command runs; `zaisus --watch` forwards args (shell-side proven by sourcing the emitted definition in zsh+bash; GUI-typing step needs a human)
- [x] 4.3 Manual: a shortcut with quotes/`$` in the command runs correctly and does not break startup (verified via unit tests + sourcing the real rc in zsh+bash)
- [x] 4.4 Run `openspec validate script-shortcuts --strict`
