## 1. Project scaffolding

- [x] 1.1 Create Xcode macOS app project `zTerminal` (SwiftUI lifecycle), target macOS 13+, in the repo root
- [x] 1.2 Add SwiftTerm as an SPM dependency and pin a specific version tag; bundle a Nerd Font
- [x] 1.3 Configure `Info.plist` / entitlements and a dev code-signing identity (needed for the Finder Sync extension); app icon placeholder
- [x] 1.4 Add an XCTest target for pure-logic unit tests
- [x] 1.5 Confirm the empty app builds and launches an empty window (`xcodebuild` / run)

## 2. Terminal core (terminal-core)

- [x] 2.1 Wrap SwiftTerm `LocalProcessTerminalView` in an `NSViewRepresentable` for SwiftUI
- [x] 2.2 Spawn the login shell from `$SHELL` (default `/bin/zsh`), inheriting env, `TERM=xterm-256color`
- [x] 2.3 Make the initial working directory a session parameter (default `$HOME`); spawn the shell with cwd set to it
- [x] 2.4 Handle spawn failure (invalid `$SHELL` / exec fails) with an inline error, not a crash or blank pane
- [x] 2.5 Verify bidirectional I/O: type commands, run `vim`/`top`, confirm render + restore
- [x] 2.6 Verify resize propagation (SIGWINCH) — `stty size` reflects the grid
- [x] 2.7 Wire copy/paste (Cmd+C / Cmd+V) to the system clipboard
- [x] 2.8 Enable Option-as-Meta (configurable) and verify Ctrl+C/D/Z pass through as SIGINT/EOF/SIGTSTP
- [x] 2.9 Confirm scrollback works and shell/PTY tear down cleanly on quit
- [x] 2.10 Clear action (Cmd+K): erase scrollback (`ESC[3J`) + redraw prompt (Ctrl+L), no new shell
- [x] 2.11 Copy-on-select: auto-copy the selection to the clipboard (skip when empty)
- [x] 2.12 Right-click context menu: Copy, Paste, Select All, Clear, Reveal in Finder
- [x] 2.13 Drag & drop: insert shell-escaped paths for dropped files/folders; Cmd-drop a folder opens a new tab there
- [x] 2.14 Shell selectable in Settings (zsh/bash, default zsh); applies to new tabs, persisted
- [x] 2.15 Bell attention: unfocused-tab bell posts a notification + Dock badge count; clears on return
- [x] 2.16 Quick Look (context menu + ⌘Y) previews the file referenced by the selection
- [x] 2.17 Bottom toolbar trash icon clears the window (same as ⌘K)

## 3. Appearance & color (app-shell + terminal-core)

- [x] 3.1 Set the bundled Nerd Font as default monospace; configure a fallback chain (→ Apple Color Emoji → system); apply a dark theme
- [x] 3.2 Export `TERM=xterm-256color` and `COLORTERM=truecolor`; verify a truecolor test (e.g. `printf '\e[38;2;255;100;0mX\e[0m'`) shows exact RGB
- [x] 3.3 Verify 256-color palette, bold/italic/underline/dim attributes, and colored diffs (`git diff --color`, `bat`)
- [x] 3.4 Verify powerline separators, Nerd Font icons, color emoji (via fallback), and CJK/wide chars render at correct width
- [x] 3.5 Implement font-size change (Cmd+Plus / Cmd+Minus) with grid reflow
- [x] 3.7 Liquid Glass ANSI color scheme (selectable; accent cursor) via `installColors`
- [x] 3.6 Add standard menu bar (app, Edit, View, Window) and clean quit that terminates all shells

## 3b. TUI agent compatibility (terminal-core)

- [x] 3b.1 Verify alternate screen buffer enter/exit restores prior scrollback
- [x] 3b.2 Verify mouse reporting, bracketed paste, focus in/out, and OSC 8 hyperlinks
- [x] 3b.3 Route scroll-wheel to the program when the alternate screen is active (not to scrollback)
- [x] 3b.4 Acceptance: run `claude` (Claude Code) — colors, input, Option+Return newline, streaming, and resize all correct, screen restored on exit
- [x] 3b.5 Acceptance: run at least one more agent (`codex` / `opencode` / `aider`) and confirm clean rendering

## 4. Bottom toolbar (directory-status-bar)

- [x] 4.1 Build a fixed-height SwiftUI toolbar docked below the terminal in a `VStack`
- [x] 4.2 Add an observable `SessionModel`; display the CWD with `~` home abbreviation
- [x] 4.3 Seed the toolbar CWD from the session's initial directory so a path shows immediately (before first OSC 7)
- [x] 4.4 Track CWD via SwiftTerm's OSC 7 / `hostCurrentDirectory` delegate callback (parse `file://host/path`)
- [x] 4.5 Implement the fallback: resolve the tty foreground pgid via `tcgetpgrp`, query cwd via `proc_pidinfo`; keep last-known on failure
- [x] 4.6 Document (and optionally auto-install) the OSC 7 shell hook (zsh `chpwd`, bash `PROMPT_COMMAND`)
- [x] 4.7 Add the folder icon; on click call `NSWorkspace.activateFileViewerSelecting` with the current CWD URL
- [x] 4.8 Disable/flag the folder icon when the OSC 7 host is non-local (SSH) or the path is not a local directory
- [x] 4.9 Verify path handling: spaces, unicode, symlinks (percent-decode `file://`, resolve via `URL`)
- [x] 4.10 Record `startedAt` on session open; show formatted start date/time in the toolbar
- [x] 4.11 Drive a 1 Hz `Timer.publish`; show a live `HH:MM:SS` duration counting up from `startedAt`
- [x] 4.12 Ensure the start time and timer are per-session (each tab independent); stop the timer when the shell exits

## 5. Tabs & session lifecycle (app-shell)

- [x] 5.1 Model a window as an ordered list of `SessionModel` + `activeSessionID`; render a **top tab bar** (glass), active tab distinct, titled by program/dir
- [x] 5.2 New tab (Cmd+T) **inherits the active tab's current CWD** (fallback: its initialDirectory, then `$HOME`) so multiple tabs open in the same folder
- [x] 5.3 Switch tabs (click, Cmd+1..9, Cmd+Shift+[ ]); close a tab (Cmd+W, close control) tearing down its shell/PTY; closing the last tab closes the window
- [x] 5.4 Drag-to-reorder tabs in the tab bar
- [x] 5.7 Double-click a tab to rename it (custom title overrides auto; Esc/empty reverts)
- [x] 5.5 On shell exit, keep the tab, show "[process completed]", stop the timer, and offer restart (respawn in last-known dir with fresh start time)
- [x] 5.6 Verify each tab shows its own CWD, start time, and duration independently, incl. two tabs in the same directory

## 6. Finder integration (finder-integration)

- [x] 6.1 Add a validated "open at path" entry point: register `zterminal://open?path=...`; percent-decode, canonicalize (`resolvingSymlinksInPath`), require existing local directory, else ignore
- [x] 6.2 Wire "open at path" to open a new tab seeded with that initial directory; single-instance activation (reuse the running app)
- [x] 6.3 Register a macOS Services entry "zTerminal" in `Info.plist` accepting selected folder file URLs → forwards to 6.1
- [x] 6.4 Add a Finder Sync app-extension target contributing a "zTerminal" background/context item that forwards the displayed folder → 6.1
- [x] 6.5 Verify: right-click a selected folder (Services) and a window background (Finder Sync) each open a terminal in that folder
- [x] 6.6 Verify graceful degradation when the Finder Sync extension is disabled (Services still works)
- [x] 6.7 Verify folders with spaces/unicode open correctly, and that a bogus/nonexistent/`file`-only path is rejected

## 7. Unit tests (pure logic)

- [x] 7.1 Test OSC 7 `file://host/path` parsing incl. percent-decoding, empty host, and non-local host detection
- [x] 7.2 Test `~` home abbreviation and URL-scheme + path validation (reject non-dir / non-existent / non-`file`)

## 8. Verification

- [x] 8.1 Manual pass against every spec scenario (launch seed + cd updates toolbar, reveal-in-finder local-only, SSH disables reveal, timer per tab, tabs open/switch/close, shell-exit + restart, right-click opens at folder, truecolor + emoji + agents render clean)
- [x] 8.2 Run `openspec validate bootstrap-terminal-app` and fix any issues
- [x] 8.3 Write a short README with build/run instructions, dev-signing + Finder Sync enable steps, the OSC 7 hook snippet, and how the "zTerminal" entries work
