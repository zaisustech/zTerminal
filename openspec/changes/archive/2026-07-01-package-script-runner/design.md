## Context

zTerminal knows the active tab's CWD (via OSC 7 / fallback). When that folder is a
Node project, we can surface its `package.json` scripts as one-click actions in the
toolbar. This design keeps the feature project-aware, safe, and extensible to
other manifests later.

## Goals / Non-Goals

**Goals:**
- Zero-friction running of project scripts with the correct package manager.
- Safe execution: preview commands, never auto-run, don't corrupt a busy shell.
- Extensible task-source model so non-Node manifests can plug in later.

**Non-Goals:**
- A full task manager / runner history / output parsing.
- Editing scripts or `package.json`.
- Non-Node task sources in this change (design leaves room; not implemented now).

## Decisions

### Decision: `TaskSource` protocol with one source per ecosystem
Define `protocol TaskSource { func detect(in dir) -> TaskGroup? }`, where a
`TaskGroup` has a title (e.g. "Cargo", "Maven", "Node · pnpm") and `[RunTask]`
(name, command preview, and the command to run). A registry runs every source
against the CWD and the popover renders each returned group as a section.
Concrete sources:
- **Node** (`package.json`): scripts via detected manager(s); keeps manager selection.
- **Cargo** (`Cargo.toml`): `cargo run/build/test/check/clippy/fmt`.
- **Maven** (`pom.xml`): `mvn spring-boot:run/test/package/clean install`.
- **Gradle** (`build.gradle`/`.kts`/`gradlew`): `./gradlew bootRun/build/test` (uses the wrapper when present).
- **Python**: `manage.py` → Django (`runserver/migrate/test`); else `pyproject.toml`/pytest.
- **Go** (`go.mod`): `go run ./... / build ./... / test ./... / vet ./...`.
- **Make** (`Makefile`): parse target names → `make <target>`.
Rationale: the toolbar/popover bind to groups and don't care about the source, so
new ecosystems are one small type. Each detector is a pure function → unit-tested.

### Decision: Package-manager detection order
Resolve the manager by: (1) `packageManager` field in `package.json` (corepack),
then (2) lockfile — `bun.lockb`/`bun.lock` → bun, `pnpm-lock.yaml` → pnpm,
`yarn.lock` → yarn, `package-lock.json`/`npm-shrinkwrap.json` → npm — else default
npm. Run command is `<mgr> run <script>` (npm/pnpm/yarn/bun all accept this; also
allow bare `<mgr> <script>` for lifecycle names). Rationale: matches whatever the
repo actually uses. The detector is a pure function → unit-tested.

### Decision: Detection uses the CWD's package.json (nearest-at-CWD)
Read `package.json` in the active tab's CWD. Rationale: matches the user's mental
model ("this folder"). A future option can walk up to the nearest ancestor for
monorepos; noted as an open question, not built now.

### Decision: Idle-vs-busy execution, and the new-tab path
Determine idle by comparing the PTY foreground process group to the shell's own
pid (shell in foreground ⇒ idle at prompt). If idle and no ⌘ modifier: write the
command + newline into the current session (bracketed-paste-safe). If busy, or
⌘-activated: open a new tab seeded with the project directory **and an initial
command to run** — extending the bootstrap "open at path" seam to also accept an
initial command. Rationale: injecting into a busy shell corrupts input and can't
interrupt a running program; dev servers want their own tab anyway.

### Decision: Reactive visibility + change watching
The Run action's visibility binds to the active session's CWD (already observable).
Re-scan `package.json` when the popover opens; optionally watch the file via a
lightweight `DispatchSource` while the popover is open. Rationale: cheap, and
avoids stale script lists without constant polling.

### Decision: Safety
Never execute on detection — only on explicit activation. Show the underlying
command in each row so the user sees what will run. Parse `package.json` defensively
(bad JSON → inline error). Missing manager binary is surfaced by the shell when the
command runs (we don't silently swallow it).

## Risks / Trade-offs

- **Idle detection wrong → command injected into a busy shell** → Conservative default: when unsure, use a new tab. ⌘ always forces a new tab.
- **Monorepo: CWD has no package.json but an ancestor does** → For now the icon is simply hidden; ancestor-walk is a future option (open question).
- **Package manager not installed** → The run command fails visibly in the shell; acceptable and clear.
- **File watching cost** → Only watch while the popover is open; otherwise scan on open.

## Migration Plan

Additive. Rollback = hide the Run action. No data migration. Depends on
bootstrap-terminal-app capabilities being in place (tabs, CWD, session command run).

## Open Questions

- Monorepo: should detection walk up to the nearest ancestor `package.json`, and/or read workspace packages?
- Should we show npm lifecycle scripts (`preinstall`, `postinstall`) or only user scripts?
- Offer a "favorites"/recent-scripts ordering, or keep declaration order?
