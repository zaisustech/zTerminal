## Context

zTerminal spawns each tab's shell itself (`/bin/zsh` or `/bin/bash`, per Settings) and
already injects a bootstrap when `colorfulShell` is on — it sources the user's `~/.zshrc`
and then adds a prompt and `ls`/git colors. Script shortcuts hook into that same bootstrap:
the app writes the mappings into the interactive shell so the **shell** does the expansion.

The alternative — watching what the user types in the terminal view and rewriting the line
before it reaches the PTY — is rejected: the app would have to re-implement line editing,
history, multi-line input, and cursor movement, and would still miss paste and here-docs.
Let the shell do what shells do.

## Goals / Non-Goals

**Goals:** a global list of `name → command` shortcuts; type the name at the prompt to run
the command; simple add/edit/delete UI in a Settings tab; persisted; robust against bad
input; zero new dependencies.

**Non-Goals:** per-project shortcuts (that is what `.zTerminal.json` Bookmarks are for —
shortcuts are global-only, resolved during review); surfacing shortcuts in the Run popover
(they are type-only, resolved during review); retroactively injecting into already-open
shells; a full alias manager (namespaces, conditional aliases); syncing to the user's real
`~/.zshrc`.

## Decisions

### Decision: Inject as real shell aliases/functions, not input interception
At shell bootstrap, emit one definition per shortcut so the shell expands it natively. This
is the crux of the feature and the reason it is reliable.

### Decision: Function form with `"$@"`, not bare `alias`
Emit a shell **function**: `zaisus() { bun run start "$@"; }`. This works identically in zsh
and bash, forwards extra arguments (`zaisus --watch` → `bun run start --watch`), and avoids
`alias`'s quirks (first-word-only expansion, non-recursion rules). Fall back to `alias` only
if a name is a valid alias token but not a valid function identifier — see validation.

### Decision: Store in `DesignTokens` (persisted settings bag)
Add `scriptShortcuts: [ScriptShortcut]` to `DesignTokens`, persisted in `UserDefaults` like
every other setting. Editing in the Scripts tab mutates `theme.tokens`, which auto-saves.

### Decision: Bootstrap ordering — our shortcuts source **after** the user's rc
Source `~/.zshrc` first, then define shortcuts, so a zTerminal shortcut wins over a
same-named user alias (confirmed during review). Document this precedence; it is the
least-surprising default for a feature whose whole point is "my shortcut runs."

### Decision: Global-only and type-only (resolved during review)
Shortcuts live solely in Settings and apply in every tab and directory — there is no
per-project override in `.zTerminal.json` (per-project named commands are already covered by
Bookmarks). Shortcuts are run only by typing the name at the prompt; they are **not** shown
in the Run popover. This keeps the two concepts cleanly separated: Bookmarks = per-project,
clicked; shortcuts = global, typed.

### Decision: Strict name validation + safe command quoting
- **Name** must match `^[A-Za-z_][A-Za-z0-9_-]*$` and must not be a shell keyword
  (`if`, `for`, `while`, `do`, `then`, `fi`, `function`, …). Empty/duplicate names are
  rejected in the UI.
- **Command** is embedded via a single here-safe quoting routine (single-quote wrapping
  with `'\''` escaping) so quotes, `$`, backticks, and newlines cannot break the definition
  or inject extra commands.

### Decision: One malformed entry must not break shell startup
Each definition is emitted independently and guarded so a bad line is skipped, not fatal —
the shell still reaches a prompt with the remaining shortcuts intact.

## Risks / Trade-offs

- **New tabs only.** Existing shells don't see edits until a new tab (mirrors
  `colorfulShell`). Mitigation: note this in the tab's help text; optionally offer a
  "reload shortcuts in this tab" action later.
- **Shadowing real commands.** A shortcut named `ls` or `cd` silently overrides the binary.
  Mitigation: warn in the UI when a name collides with a known command/builtin; still allow
  it (it is a legitimate use).
- **Overriding the user's own `~/.zshrc` aliases.** Chosen precedence (ours wins) can
  surprise; surfaced in help text. Reversible by removing the shortcut.
- **Non-standard `$SHELL` (fish, etc.).** The app only spawns zsh/bash; shortcuts are only
  guaranteed for those. Skip injection for unsupported shells rather than emit broken
  syntax.
- **Discoverability.** Users forget names. Mitigation: the Scripts tab is the canonical
  list; consider a built-in `ztscripts` helper that prints all shortcuts (future).

## Migration Plan

Additive; default is an empty list (no shortcuts, no behavior change). Existing configs
decode with `scriptShortcuts` absent → `[]`. Rollback = remove the setting and the
bootstrap block.

## Open Questions

None — the three design questions raised at proposal time were resolved during review:
type-only (no Run popover), global-only (no `.zTerminal.json` override), and zTerminal
shortcuts override same-named user rc aliases.
