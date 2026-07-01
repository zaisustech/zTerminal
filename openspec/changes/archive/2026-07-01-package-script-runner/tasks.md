## 1. Task-source model

- [x] 1.1 Define `RunTask` (display name, raw command, resolved run command) and a `TaskSource` protocol
- [x] 1.2 Implement `PackageManager` detection (packageManager field → lockfile → default npm) as a pure, unit-tested function
- [x] 1.3 Implement `PackageJSONTaskSource`: parse the CWD's `package.json` scripts into `RunTask`s; handle malformed JSON and empty scripts

## 2. Toolbar Run action

- [x] 2.1 Add a Run icon to the top toolbar bound to the active session's CWD
- [x] 2.2 Show it only when a `package.json` exists in the CWD; update reactively on CWD change

## 3. Run popover (UI)

- [x] 3.1 Build a glass popover listing scripts with name + command preview
- [x] 3.2 Add a filter field; support ↑/↓ navigation, Enter (run here), ⌘Enter (new tab)
- [x] 3.3 Empty-scripts state offers "Install dependencies"; malformed-JSON state shows an inline error
- [x] 3.4 Accessibility: focus states, VoiceOver labels, ⌘-click affordance discoverable
- [x] 3.5 Re-scan `package.json` on open; optionally watch the file while the popover is open

## 4. Execution

- [x] 4.1 Determine idle-vs-busy via the PTY foreground process group vs. the shell pid
- [x] 4.2 Run in the current tab when idle and no ⌘ modifier (write command + newline safely)
- [x] 4.3 Extend the "open at path" seam to also accept an initial command; open a new tab (same dir) that runs the script
- [x] 4.4 Route busy shells and ⌘-activation to the new-tab path; inform the user which path was taken

## 6. Multi-ecosystem task sources

- [x] 6.1 Define `TaskSource` protocol + `TaskGroup`; registry runs all sources against the CWD
- [x] 6.2 Refactor Node (package.json) into a `TaskSource` returning a group (keep manager selection)
- [x] 6.3 Cargo source (`Cargo.toml`) → run/build/test/check/clippy/fmt
- [x] 6.4 Maven (`pom.xml`) and Gradle (`build.gradle`/`gradlew`, prefer wrapper) → Spring Boot run/build/test
- [x] 6.5 Python source: `manage.py` (Django) → runserver/migrate/test; else `pyproject.toml`/pytest
- [x] 6.6 Go (`go.mod`) and Make (`Makefile`, parse targets) sources
- [x] 6.7 Popover renders grouped sections; visibility = any source matched
- [x] 6.8 Unit tests for each source's detection + task list

## 5. Verification

- [x] 5.1 Unit tests: package-manager detection across lockfiles + `packageManager` field; script parsing incl. malformed/empty
- [x] 5.2 Manual pass against every spec scenario (icon visibility, detection, run here/new tab, ⌘, filter/keyboard, refresh)
- [x] 5.3 Run `openspec validate package-script-runner` and fix any issues
