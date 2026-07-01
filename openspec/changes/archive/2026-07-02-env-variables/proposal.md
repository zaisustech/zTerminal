## Why

Developers routinely need per-tool environment variables — `OPENAI_API_KEY`, `NODE_ENV=development`,
`AWS_PROFILE`, `EDITOR` — available in every terminal without editing `~/.zshrc` or exporting them by
hand each session. zTerminal spawns each tab's shell itself and already injects script shortcuts into
that shell, but there is no UI to define environment variables that every new tab inherits, nor a way to
deliberately override a value the parent process already exports.

## What Changes

- Add an **Environment** tab to Settings (⌘,) alongside Appearance, Terminal, and Scripts.
- Let the user define **environment variables**: a `key` (e.g. `NODE_ENV`) mapped to a `value`
  (e.g. `development`), edited as add / edit / delete / reorder rows.
- **Inject** each variable into the shell zTerminal spawns for a new tab, so programs run in that tab
  see them — using the same shell-bootstrap path that already installs colors and script shortcuts.
- Support **override**: a defined variable takes precedence over a same-named value inherited from
  zTerminal's parent process environment (user-controlled — the whole point is "my value wins").
- Validate `key` names (POSIX `^[A-Za-z_][A-Za-z0-9_]*$`) and safely quote each `value` so quotes,
  `$`, backticks, and newlines cannot break shell startup or inject commands.
- Warn (non-blocking) when a `key` shadows a variable already present in the inherited environment.
- Variables are **global** (persisted in Settings, applied to every new tab), distinct from per-project
  `.zTerminal.json`.

## Capabilities

### New Capabilities
- `environment-variables`: User-defined global environment variables (key → value), edited in a Settings **Environment** tab and injected into each new shell zTerminal spawns, with user-controlled override of inherited values.

### Modified Capabilities
<!-- None. The existing app-shell Settings surface gains a tab; no behavior of an existing capability changes. -->

## Impact

- **New model:** `EnvVar { key, value, enabled }` and a `[EnvVar]` field on the persisted settings bag
  (`DesignTokens`), decoding-tolerant (absent → `[]`).
- **New UI:** an `EnvironmentSettings` tab in `SettingsView` (add / edit / delete / reorder rows, with
  inline validation and a shadowing warning).
- **Shell init:** extend the existing shell bootstrap (`ShellColor.makeZDotDir` / `makeBashRC` and the
  env assembly in `TerminalHostView`) to `export` each valid variable **after** sourcing the user's rc,
  so it overrides both the inherited environment and same-named rc exports.
- **Scope:** applies to **new** tabs; existing shells are unaffected until a new tab is opened
  (same limitation as `scriptShortcuts` and `colorfulShell`).
- No new external dependencies.
