## Context

`BottomToolbar` already has a reveal-in-Finder button using
`NSWorkspace.activateFileViewerSelecting`, and each `SessionModel` tracks its CWD via
OSC 7. This change adds the editor counterpart: resolve a token to a real file and hand
it to an editor, plus a status-bar button for the directory.

## Goals / Non-Goals

**Goals:** cmd-click a path (with optional `:line:col`) to open it in the editor; an
"Open in editor" button for the CWD; a configurable editor; safe path resolution.

**Non-Goals:** a full LSP/jump-to-symbol; editing in-app; guessing the editor from file
type; opening remote paths.

## Decisions

### Decision: Resolve against the tab CWD, only link real files
A clicked token is resolved as absolute, or relative to `session.cwd`, then accepted only
if the file exists. This makes relative paths from build output (`src/foo.ts:10`) work and
avoids turning arbitrary words into links.

### Decision: Parse a trailing `:line[:col]`
Strip and parse a `:line` or `:line:col` suffix (the common compiler/test format) and pass
it to the editor's line flag. A path with no suffix opens at the top.

### Decision: `EditorLauncher` with per-editor templates
Known editors map to launch commands — VS Code `code -g {file}:{line}:{col}`, Cursor
`cursor -g …`, Xcode `xed --line {line} {file}` (falls back to `open -a Xcode`) — plus a
**custom command template** using `{file}`/`{line}`/`{col}` placeholders. Missing CLIs fall
back to `open -a <App>`.

### Decision: Editor stored in Settings, tolerant-decoded
Add an `editor` field to `DesignTokens`, decoded with the existing tolerant decoder
(absent → a sensible default such as VS Code, falling back to `open`).

## Risks / Trade-offs

- **CLI not installed** (`code` not on PATH) → fall back to `open -a`, which can't jump to a
  line; surface a one-time hint in Settings.
- **Ambiguous token boundaries** — path detection under the pointer can over/under-select;
  prefer OSC 8 hyperlinks when the program emits them, else a conservative heuristic.
- **Spaces in paths** — resolve the whole clicked token and quote when launching.

## Migration Plan

Additive; default editor with an `open`-based fallback so it works with zero config.
Rollback = remove the click handler, the button, and the setting.

## Open Questions

- Should plain URLs also be cmd-clickable here, or is that already handled by the terminal
  view? (If not handled, fold URL-open into the same click routing.)
