# Project: zTerminal

A native macOS terminal emulator that replicates the look and feel of iTerm2,
with a folder-aware status bar at the bottom of the window.

## Goal

Own, native macOS terminal app — not a wrapper. Fast, native, and deeply
integrated with the macOS desktop (Finder, colors, fonts).

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI shell + AppKit (NSViewRepresentable) where native behavior is needed
- **Terminal emulator:** [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (VT100/xterm, PTY)
- **Build:** Swift Package Manager / Xcode; target macOS 13+
- **Distribution:** `.app` bundle (later: notarized/signed)

## Signature Features

- iTerm-like terminal: tabs, splits, color themes, configurable font, scrollback.
- **Bottom status bar** showing the shell's current working directory (CWD).
- A **folder icon** in the status bar; tapping it reveals the CWD in Finder
  (`NSWorkspace.activateFileViewerSelecting`).

## Conventions

- CWD is tracked via OSC 7 escape sequences emitted by the shell, with a PID/cwd
  fallback via `proc_pidinfo` when OSC 7 is unavailable.
- Keep terminal-emulation concerns in SwiftTerm; app owns chrome (bar, tabs, prefs).
