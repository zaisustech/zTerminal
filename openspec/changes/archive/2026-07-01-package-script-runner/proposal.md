## Why

Developers constantly re-run project scripts (`dev`, `build`, `test`, `lint`).
When zTerminal is sitting in a Node project, it already knows the folder — it can
surface those scripts one click away instead of making the user remember and type
`npm run …`. This makes zTerminal feel project-aware and premium.

## What Changes

- Generalize from "npm scripts" to a **project task runner**: the Run icon appears
  when the CWD is recognized by **any** task source — Node (`package.json`), Rust
  (`Cargo.toml`), Java/Spring Boot (Maven `pom.xml` / Gradle), Python (Django
  `manage.py`, `pyproject.toml`, pytest), Go (`go.mod`), and `Makefile` — and lists
  that ecosystem's runnable tasks. Multiple ecosystems in one repo are grouped.
- When the current working directory contains a `package.json`, show a **Run**
  icon in the top toolbar (hidden otherwise; reactive to CWD changes).
- Clicking it opens a **glass popover** listing the project's runnable scripts,
  each showing its name and the underlying command.
- **Detect the package manager** from the lockfile / `packageManager` field
  (bun, pnpm, yarn, npm) and run scripts with it.
- **Run a script in the current tab** when the shell is idle at a prompt; run in a
  **new tab** (same folder) when the shell is busy — and always when the user
  **⌘-clicks** (or presses ⌘Enter).
- Popover is **searchable and keyboard-navigable** (filter, ↑/↓, Enter = run here,
  ⌘Enter = new tab) and accessible.
- Handle edges: malformed `package.json` (error, no crash), no `scripts` (offer
  **Install dependencies**), and live refresh when the file or CWD changes.
- Model the feature as a set of pluggable **task sources** (one per ecosystem)
  behind a common protocol, so new ecosystems drop in without UI changes.

## Capabilities

### New Capabilities
- `package-script-runner`: A toolbar Run action that detects the project's build system(s) in the CWD — Node, Rust, Java (Maven/Gradle), Python, Go, Make — and lists each ecosystem's runnable tasks, running a chosen one in the current tab or a new tab. (Node additionally offers package-manager selection.)

### Modified Capabilities
<!-- None as deltas: this builds on `terminal-core` (tabs, initial working
     directory, running a command in a session) and `directory-status-bar` (CWD
     tracking), which are not yet synced to openspec/specs/. Reconcile when
     bootstrap-terminal-app is archived. -->

## Impact

- **Depends on:** CWD tracking (`directory-status-bar`), tabs + configurable
  initial directory (`app-shell`/`terminal-core`), and the ability to run a
  command in a session (reuses the "open at path" seam, extended to also run a command).
- **New modules:** `Tasks/` — a `TaskSource` protocol, a `PackageJSONTaskSource`,
  a `PackageManager` detector, and the Run popover view.
- **Filesystem:** reads `package.json` and lockfiles in the CWD; watches for changes.
- **Safety:** scripts run only on explicit user action; commands are previewed;
  nothing auto-runs on detection.
