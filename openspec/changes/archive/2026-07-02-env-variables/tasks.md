## 1. Model & persistence

- [x] 1.1 Add `EnvVar { id: UUID, key: String, value: String, enabled: Bool }` (Codable, Identifiable, Equatable), tolerant decode (missing `id` → fresh UUID, missing `enabled` → `true`)
- [x] 1.2 Add `envVars: [EnvVar] = []` to `DesignTokens`, decoding-tolerant (absent → `[]`), and include it in the `CodingKeys` / `init(from:)` merge
- [x] 1.3 Key validation helper: `^[A-Za-z_][A-Za-z0-9_]*$`, reject empty and duplicates; `duplicateKeys(in:)` helper
- [x] 1.4 Reuse/verify the single-quote value-quoting routine (`'` → `'\''`) — shared with `ScriptShortcut.shellQuote`
- [x] 1.5 Shadowing helper: `shadowsInheritedEnv(key)` — true when the key exists in `ProcessInfo.processInfo.environment`

## 2. Shell injection

- [x] 2.1 Emit one guarded `export KEY=<quoted-value>` per enabled, valid, unique variable, **after** sourcing `~/.zshrc`, in the generated rc (`ShellColor.makeZDotDir` / `makeBashRC`) — add an `envBlock(for:)` builder mirroring `ScriptShortcut.shellBlock`
- [x] 2.2 Seed the pre-spawn `env` dictionary in `TerminalHostView` with the same variables (belt-and-suspenders; rc export remains authoritative for precedence)
- [x] 2.3 Emit valid syntax for both zsh and bash; for unsupported `$SHELL` fall back to the `env` dictionary seed only
- [x] 2.4 Ensure a malformed/duplicate/disabled entry is skipped, not fatal (shell still reaches a prompt)

## 3. Settings UI

- [x] 3.1 Add an **Environment** tab to `SettingsView` (icon e.g. `terminal.fill` / `list.bullet.rectangle`)
- [x] 3.2 List rows (key + value + enabled toggle) with add / edit / delete / reorder
- [x] 3.3 Inline validation: bad/duplicate keys blocked with a clear message
- [x] 3.4 Shadowing warning when a key matches an inherited env var (non-blocking)
- [x] 3.5 Help text: applies to new tabs; overrides inherited and rc values

## 4. Verification

- [x] 4.1 Unit-test key validation, duplicate detection, and value quoting (injection attempts, special chars, newlines)
- [x] 4.2 Unit-test `envBlock(for:)` output: skips invalid/duplicate/disabled entries; emits after the rc source
- [x] 4.3 Manual: define `NODE_ENV → development`; open a new tab; `echo $NODE_ENV` prints `development`
- [x] 4.4 Manual: define `EDITOR → nvim` when parent env has `EDITOR=vi`; new tab shows the override wins
- [x] 4.5 Manual: a value with quotes/`$`/backticks exports literally and does not break startup or run commands (verified via unit tests + sourcing the emitted rc in zsh+bash)
- [x] 4.6 Run `openspec validate env-variables --strict`
