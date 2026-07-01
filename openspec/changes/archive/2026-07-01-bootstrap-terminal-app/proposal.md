## Why

There is no in-house macOS terminal. We rely on third-party apps (iTerm2) that we
cannot extend or brand. We want our own native terminal that feels like iTerm2 but
adds a folder-aware status bar so users always see — and can jump to — the shell's
current working directory in Finder.

## What Changes

- Introduce a new native macOS app (`zTerminal`), a `.app` bundle built with Swift + SwiftUI/AppKit.
- Embed [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) as the terminal emulator, driving a real login shell over a PTY.
- Deliver an iTerm2-like terminal surface: monospaced font, color theme, scrollback, resize/reflow, copy/paste, and keyboard handling.
- Support **code-editor-grade color**: 24-bit truecolor and 256-color, advertised via `COLORTERM=truecolor`, so syntax highlighting and rich diffs render accurately.
- Be **fully compatible with modern TUI CLI agents** (Claude Code, Codex CLI, opencode, aider, etc.): alternate screen buffer, mouse reporting, bracketed paste, focus events, OSC 8 hyperlinks, and Nerd/powerline glyph rendering.
- Add a **bottom toolbar** that continuously displays the shell's current working directory (CWD).
- Add a **folder icon** in the toolbar; clicking it reveals the CWD in Finder via `NSWorkspace.activateFileViewerSelecting`.
- Track CWD via OSC 7 escape sequences, with a `proc_pidinfo` PID→cwd fallback when the shell does not emit OSC 7.
- Show, in the toolbar, the session **start date/time** and a live **duration timer** that counts up from when the terminal (tab) was opened.
- Support **tabs**: multiple independent terminal sessions in one window, each with its own CWD, start time, and timer.
- Spawn each shell in a **configurable initial working directory** (default `$HOME`) and seed the toolbar CWD from it so the path shows immediately, before the shell emits OSC 7.
- Add **Finder integration**: right-clicking a folder (Services entry) or a Finder window background (Finder Sync extension) shows a "zTerminal" entry that opens the app with a new terminal `cd`'d to that folder, with the incoming path validated as an existing directory.
- Handle real-world edges: **Option-as-Meta** key, clean **shell-exit** behavior, **SSH-aware** Reveal-in-Finder (only reveals local paths), and font fallback so **emoji** render in color.

## Capabilities

### New Capabilities
- `app-shell`: The macOS application container — window, **tabs**, lifecycle (including shell-exit handling), menu bar, and the layout that hosts the terminal surface and the toolbar. iTerm-like appearance (font, theme, emoji-capable font fallback).
- `terminal-core`: The terminal emulator itself — spawning a login shell over a PTY in a **configurable working directory**, wiring input/output to SwiftTerm, **Option-as-Meta** key handling, spawn-failure handling, rendering, resize/reflow, copy/paste, full truecolor, and modern TUI compatibility (alternate screen, mouse, bracketed paste) for running AI CLI agents.
- `directory-status-bar`: The bottom toolbar that reports the shell's current working directory (seeded at launch), reveals the CWD in Finder (local paths only), and shows the session start date/time plus a live duration timer.
- `finder-integration`: A right-click "zTerminal" entry — Services for a selected folder, Finder Sync extension for a window background — that validates the path and opens the app with a new terminal `cd`'d to that folder.
- `attention-notifications`: The terminal bell in an unfocused tab posts a user notification and increments the Dock icon badge (cleared when the user returns), so a background agent awaiting input is noticed.

### Modified Capabilities
<!-- None — this is the initial bootstrap; no existing specs. -->

## Impact

- **New project scaffolding:** Swift Package / Xcode project, `Package.swift` or `.xcodeproj`, app entry point, `Info.plist`, entitlements.
- **New dependency:** SwiftTerm (SPM); a bundled Nerd Font.
- **Finder integration surface:** a macOS Services menu entry **and** a Finder Sync app-extension target, plus a validated custom URL scheme (`zterminal://`) to hand the folder path to the running app. The Finder Sync extension requires the app to be **code-signed** (dev-signed is sufficient for local use).
- **Testing:** a unit-test target for pure logic (OSC 7 / `file://` parsing, `~` abbreviation, URL-scheme + path validation).
- **Platform:** macOS 13+ target; requires Xcode toolchain (already installed).
- **No existing code affected** — greenfield.
