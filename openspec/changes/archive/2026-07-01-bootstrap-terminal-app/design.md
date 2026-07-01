## Context

Greenfield native macOS terminal. Building a VT100/xterm emulator from scratch is
a large undertaking, so we embed **SwiftTerm** (Miguel de Icaza), a mature Swift
terminal-emulation library that ships an AppKit `LocalProcessTerminalView` which
already spawns a child process over a PTY and renders output. Our own code is the
chrome: the window, the appearance, and the folder-aware status bar.

The distinguishing feature is a bottom status bar that always shows the shell's
CWD and reveals it in Finder on click. The hard part is knowing the CWD reliably.

## Goals / Non-Goals

**Goals:**
- Native `.app` that feels like iTerm2 for everyday use (font, colors, scrollback, copy/paste).
- A bottom bar showing the live CWD and a folder icon that reveals it in Finder.
- Reliable CWD tracking that works with a standard zsh/bash setup.

**Non-Goals (deferred to later changes):**
- Split panes within a tab (tabs are in scope; splits are not).
- Full preferences UI, profiles, and theme editor.
- Search, hotkey window, tmux integration, ligatures, GPU renderer.
- Notarization / Gatekeeper distribution (a dev signature — needed for the Finder Sync extension — is in scope; notarized distribution is not).

**In scope for the bootstrap:** tabs (each an independent session), a Finder Sync
app-extension (for the window-background case), Option-as-Meta, shell-exit
handling, emoji font fallback, and a unit-test target for pure logic.

## Decisions

### Decision: Use SwiftTerm's `LocalProcessTerminalView`
Rationale: it already implements PTY spawning, SIGWINCH resize, selection, and
rendering. Alternative — write our own emulator or wrap xterm.js in a WKWebView —
was rejected: far more work and worse native feel for no benefit here.

### Decision: SPM-based Xcode project targeting macOS 13+
Rationale: SwiftTerm is distributed via SPM; macOS 13 gives us modern SwiftUI +
AppKit interop and `NSWorkspace` APIs. App entry via SwiftUI `App` with an
`NSViewRepresentable` wrapping the terminal view (AppKit) hosted in a SwiftUI
`VStack` above the status bar.

### Decision: Layout = SwiftUI `VStack { TerminalView; Toolbar }`, tabbed
The terminal (AppKit view, bridged) fills available space; the toolbar is a
fixed-height SwiftUI view at the bottom. Keeps chrome in SwiftUI, emulation in AppKit.

### Decision: Top tab bar over a `SessionModel` list
The window owns an ordered list of `SessionModel`s and an `activeSessionID`, shown
as a **tab bar across the top of the window** (native-terminal style). Each
`SessionModel` holds its own PTY-backed terminal, CWD state, `startedAt`, and
timer. The active session's terminal + toolbar are shown below the tab bar. We use
a custom glass tab strip (not native `NSWindow` tabs) so the per-tab bottom toolbar
stays glued to its session and the tab bar can adopt the Liquid Glass look.
Standard shortcuts: Cmd+T new tab, Cmd+W close, Cmd+1..9 / Cmd+Shift+[ ] switch;
tabs are drag-reorderable and titled by running program / directory. Closing the
last tab closes the window; a closed tab's shell/PTY is torn down immediately.

### Decision: New tab inherits the active tab's CWD
Cmd+T seeds the new `SessionModel`'s `initialDirectory` from the **active tab's
current CWD** (resolved from its live CWD state, falling back to that tab's
`initialDirectory`, then `$HOME`). This gives Terminal.app-style "open another tab
here" and lets multiple tabs run in one folder. Finder integration and the script
runner instead pass an explicit directory; both funnel through the same
`initialDirectory` seam.

### Decision: Initial working directory is a session parameter
`SessionModel` takes an `initialDirectory` (default `$HOME`). The shell is spawned
with its cwd set to that directory (not `cd`'d after start — avoids shell-quoting
issues and works before the prompt). The toolbar's CWD is seeded from
`initialDirectory` so it renders immediately, before the first OSC 7. This is the
single seam Finder integration uses to open at a folder (fixes launch-CWD and
"open at path").

### Decision: CWD tracking via OSC 7, with `proc_pidinfo` fallback
Primary: parse OSC 7 (`ESC ] 7 ; file://host/path ST`). We hook SwiftTerm's
terminal-delegate/`hostCurrentDirectoryUpdated` (SwiftTerm surfaces OSC 7 as
`hostCurrentDirectory`). Most shells need a one-line precmd hook to emit OSC 7;
we ship a shell snippet and, if not present, fall back.
Fallback: poll the shell child PID's CWD via `proc_pidinfo(PROC_PIDVNODEPATHINFO)`
(or walk to the foreground process group). Alternatives considered: parsing `cd`
commands from input (fragile — misses `pushd`, scripts, subshells) — rejected.

### Decision: Reveal in Finder via `NSWorkspace`, local paths only
`NSWorkspace.shared.activateFileViewerSelecting([url])` for a path that exists;
this selects the folder in its parent. Read the CWD from shared state at click
time so it is always current. **SSH guard:** OSC 7 carries `file://HOST/path`; we
only enable reveal when `HOST` is empty, `localhost`, or the local hostname, and
the path exists locally — otherwise the folder icon is disabled. This prevents
revealing a remote path that doesn't exist on this Mac.

### Decision: CWD fallback uses the tty foreground process group
When OSC 7 is absent, "the shell's pid" is wrong once a foreground program `cd`s
internally. We resolve the tty's foreground process group with `tcgetpgrp(fd)` and
query that pid's cwd via `proc_pidinfo(PROC_PIDVNODEPATHINFO)`. Polled on a low
cadence (e.g. ~500 ms) while OSC 7 is unseen; if the query is denied we keep the
last known CWD. OSC 7 remains strongly preferred and disables polling once seen.

### Decision: URL-scheme + path validation (security)
The `zterminal://open?path=...` scheme is reachable by any app/website, so the
handler treats input as untrusted: percent-decode, reject non-`file` inputs,
`URL(fileURLWithPath:).resolvingSymlinksInPath()`, confirm it exists and
`isDirectory`, else ignore. The Services/Finder-Sync paths funnel through the same
validated entry point. Single-instance: an already-running app handles the URL and
opens a new tab; it does not launch a second process.

### Decision: Truecolor + modern TUI compatibility as a first-class goal
The app must run AI coding agents (Claude Code, Codex CLI, opencode, aider),
which are full-screen TUIs relying on 24-bit color, the alternate screen buffer,
mouse reporting, and bracketed paste. SwiftTerm already implements xterm-level
emulation (alt screen, 256/truecolor, mouse, bracketed paste, focus events, OSC 8
hyperlinks), so the work is (a) exporting the right environment — `TERM=xterm-256color`
and `COLORTERM=truecolor` — so programs *emit* truecolor, and (b) verifying each
agent renders without corruption. Rationale for env: many tools downgrade to 16
colors unless `COLORTERM` signals truecolor. Alternative — write custom SGR
handling — unnecessary; SwiftTerm covers it. We pin the SwiftTerm version and
treat "runs the named agents cleanly" as an explicit acceptance test.

### Decision: Ship a Nerd Font + color-emoji fallback
Agent TUIs and powerline prompts use Nerd Font icons and box-drawing glyphs.
Bundle a Nerd Font (e.g. a patched monospace) as the default so icons and
powerline separators render out of the box; users can override later. A single
Nerd Font has **no color emoji**, so configure a font-fallback chain (primary
Nerd Font → Apple Color Emoji → system) so emoji render in color at the correct
cell width. SwiftTerm handles grapheme/wide-cell width.

### Decision: Option-as-Meta and control keys
Enable Option-as-Meta by default (configurable): Option+key sends `ESC`-prefixed
input so readline/emacs/vim and agent bindings (e.g. Claude Code's Option+Return
newline) work. Ctrl+C/D/Z pass through the PTY as SIGINT/EOF/SIGTSTP. Scroll-wheel
events are routed to the program when the alternate screen is active, and to
scrollback otherwise.

### Decision: Shell-exit keeps the tab, offers restart
On child-process exit we don't kill the tab; we render a "[process completed]"
line, stop the session timer, and offer restart (respawn in the tab's last known
directory with a fresh start time). Matches iTerm's default and keeps output
readable. Spawn failures render an inline error rather than a blank pane.

### Decision: Per-session timer driven by a Timer publisher
Each session records `startedAt` (a wall-clock timestamp captured when the tab
opens). A 1 Hz `Timer.publish` (SwiftUI) recomputes `now - startedAt` and formats
`HH:MM:SS`. The timer lives on the session's view model so multiple tabs are
independent. Start time is formatted with `DateFormatter` in the user's locale.
Alternative — a background thread ticking a shared clock — rejected as overkill.

### Decision: Two Finder surfaces — Services (selection) + Finder Sync (background)
Services and Finder Sync solve different cases and we ship both:
- **Services** (`NSServices` in `Info.plist`, `NSSendTypes` = file URLs) handles a
  right-click on a **selected** folder. Simple, no extra process. This satisfies
  the user's primary ask.
- **Finder Sync app-extension** handles a right-click on the **window background**
  (Services cannot read the frontmost window's folder). The extension contributes
  a menu item and forwards the displayed folder. It needs a separate extension
  target and a code signature; a local dev signature is enough. If the extension
  is not enabled, the Services path still works (graceful degradation).

Both funnel to the same validated "open at path" entry point (URL scheme /
in-process call) with single-instance activation.

### Decision: Unit-test the pure logic
OSC 7 `file://` parsing, percent-decoding, `~` abbreviation, SSH host detection,
and URL-scheme/path validation are pure functions and the most bug-prone parts.
Put them behind small testable helpers and cover them in an XCTest target;
terminal rendering and Finder wiring stay as manual acceptance checks.

## Risks / Trade-offs

- **OSC 7 not emitted by default** → Ship a documented shell hook (zsh `chpwd`/precmd, bash `PROMPT_COMMAND`); rely on `proc_pidinfo` fallback so the bar still works without it.
- **`proc_pidinfo` needs the right PID / sandbox** → Track the shell child PID from SwiftTerm; run the app un-sandboxed for the bootstrap (sandbox + entitlements deferred with distribution).
- **SwiftTerm API drift** → Pin a SwiftTerm version in `Package.swift`.
- **CWD path with symlinks / spaces / unicode** → Percent-decode the OSC 7 `file://` URL and resolve via `URL(fileURLWithPath:)`; pass the resolved `URL` to `NSWorkspace`.
- **SSH / remote CWD** → OSC 7 host guard; disable reveal for non-local hosts (a remote path won't exist locally).
- **URL scheme abuse** → Validate/canonicalize the path (exists + isDirectory + local file) before spawning; ignore anything else.
- **Finder Sync extension needs signing** → Requires a dev signature and user approval in System Settings; Services path degrades gracefully if the extension is off.
- **`proc_pidinfo` denied under hardened runtime** → Fall back to last-known CWD; OSC 7 is the primary path anyway.
- **Split panes** → Out of scope; tabs are in scope for the bootstrap.

## Migration Plan

Greenfield — no migration. Rollback = discard the change; nothing else depends on it.

## Open Questions

- Exact SwiftTerm version/tag to pin (and which Nerd Font to bundle + its license).
- Whether to auto-install the OSC 7 shell hook on first run or just document it.
- Reveal behavior: reveal-and-select in parent (default) vs. open the folder in a new Finder window.
- "Open at path" targeting: new tab in the frontmost window (default) vs. new window when none exists.
- Signing identity for the Finder Sync extension (ad-hoc/dev vs. Developer ID).
