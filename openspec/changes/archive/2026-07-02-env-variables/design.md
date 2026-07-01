## Context

zTerminal spawns each tab's shell itself (`/bin/zsh` or `/bin/bash`, per Settings) in
`TerminalHostView`. It builds the child environment from `ProcessInfo.processInfo.environment`, sets
`TERM`/`COLORTERM`/`TERM_PROGRAM`, merges `ShellColor.colorEnv`, and (for zsh/bash) points the shell at
a generated rc via `ZDOTDIR` / `--rcfile` that sources the user's real `~/.zshrc` and then installs
script shortcuts. Environment variables hook into these same two seams: the pre-spawn `env` dictionary
and the generated rc. The feature mirrors `script-shortcuts` almost exactly — same model shape, same
persistence in `DesignTokens`, same "new tabs only" scope, same safe-quoting discipline.

## Goals / Non-Goals

**Goals:** a global list of `key → value` environment variables; each enabled variable is present in
the environment of programs run in new tabs; user values override same-named inherited/parent values; a
simple add/edit/delete/reorder UI in a Settings tab; persisted; robust against bad input; zero new
dependencies.

**Non-Goals:** per-project variables (that belongs to `.zTerminal.json`, out of scope here);
retroactively injecting into already-open shells; variable interpolation/expansion across entries
(`FOO=$BAR` referencing another defined entry — values are literal); secret storage/Keychain (values
are stored in plain `UserDefaults` like other settings); syncing to the user's real `~/.zshrc`.

## Decisions

### Decision: Export in the generated rc, after sourcing the user's `~/.zshrc`
Emit one `export KEY=<quoted-value>` per enabled, valid variable in the generated rc block that already
carries the script shortcuts — placed **after** `source ~/.zshrc`. This guarantees the user's value
wins over both the inherited environment and any same-named export in their rc, which is the whole point
of "override." Alternative — only setting the pre-spawn `env` dictionary — is insufficient because the
sourced `~/.zshrc` could re-export and clobber the value; the rc-level export closes that gap.

### Decision: Also seed the pre-spawn `env` dictionary (belt and suspenders)
Merge the variables into the `env` dictionary in `TerminalHostView` as well, so non-interactive
lookups and the moment before rc sourcing already see them. The rc export is authoritative for
precedence; the dictionary seed keeps behavior sane for shells/paths that skip the generated rc.

### Decision: Store in `DesignTokens` (persisted settings bag)
Add `envVars: [EnvVar]` to `DesignTokens`, persisted in `UserDefaults` like every other setting, with a
decoding-tolerant default (absent → `[]`) so older saved settings keep loading. Editing in the
Environment tab mutates `theme.tokens`, which auto-saves — identical to `scriptShortcuts`.

### Decision: `EnvVar { key, value, enabled }` with a stable UUID id
`enabled` lets the user keep a variable in the list without injecting it (e.g. toggle a
`DEBUG` flag on/off) — cheaper than delete/re-add. A stable `id: UUID` keeps SwiftUI list rows steady
while the key is being edited, matching `ScriptShortcut`.

### Decision: Strict key validation + safe value quoting
- **Key** must match `^[A-Za-z_][A-Za-z0-9_]*$` (POSIX env-name rules) and be unique in the list.
  Empty/duplicate/illegal keys are rejected in the UI.
- **Value** is embedded via the existing single-quote wrapping routine (`'` → `'\''`), reused from
  `ScriptShortcut.shellQuote`, so quotes, `$`, backticks, and newlines are literal and cannot break the
  `export` or inject commands.

### Decision: One malformed entry must not break shell startup
Each `export` is emitted independently and guarded (skip invalid/duplicate/disabled entries) so a bad
line is skipped, not fatal — the shell still reaches a prompt with the remaining variables intact,
mirroring the script-shortcuts guarantee.

### Decision: Global-only, new-tabs-only
Variables live solely in Settings and apply to every new tab regardless of directory. Existing shells
are unaffected until a new tab opens (same limitation as `scriptShortcuts`/`colorfulShell`), surfaced in
the tab's help text.

## Risks / Trade-offs

- **New tabs only.** Existing shells don't see edits until a new tab. → Note it in the tab's help text;
  optionally add a "reload in this tab" action later.
- **Overriding critical variables** (`PATH`, `HOME`, `SHELL`). A bad override could break the shell
  environment. → Non-blocking shadowing warning in the UI; user stays in control (a legitimate use).
- **Plain-text storage.** Values (including API keys) sit in `UserDefaults`, not Keychain. → Documented
  non-goal; secret storage is a possible future enhancement.
- **Non-standard `$SHELL` (fish, etc.).** The app only spawns zsh/bash; for unsupported shells, fall
  back to the pre-spawn `env` dictionary seed and skip emitting shell-specific `export` syntax.
- **Literal values only.** `FOO=$BAR` won't expand `$BAR` at define time (it's quoted literally). →
  Documented non-goal; keeps quoting safe and predictable.

## Migration Plan

Additive; default is an empty list (no variables, no behavior change). Existing configs decode with
`envVars` absent → `[]`. Rollback = remove the setting, the rc export block, and the dictionary seed.

## Open Questions

- Should `enabled` ship in v1 or be deferred to keep the first cut minimal? (Leaning: ship it — it is a
  one-field addition and clearly useful.)
- Should the shadowing warning special-case protected keys (`PATH`, `HOME`) with a stronger caution
  than a generic "overrides inherited value" message? (Resolve during review.)
