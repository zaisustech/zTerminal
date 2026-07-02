## 1. Editor launcher

- [x] 1.1 `EditorLauncher.resolve(token:cwd:)` — absolute/relative-to-CWD, accepts only existing files (`Sources/zTerminal/Support/EditorLauncher.swift`)
- [x] 1.2 `parseSuffix` for trailing `:line[:col]` (pure, unit-tested)
- [x] 1.3 Per-editor invocations (VS Code/Cursor `-g`, Xcode `xed --line`) + custom `{file}/{line}/{col}` template; `open`/`open -a` fallback when the CLI is missing

## 2. Terminal click routing

- [x] 2.1 On ⌘-click, `ZTerminalView.tokenAt(point:)` maps the point to a cell (via `cellSize`) and extracts the whitespace-delimited token; consumes the event
- [x] 2.2 `TerminalHostView` routes the token → `EditorLauncher.resolve` → `open` at the parsed line/col using the configured editor. *(OSC 8 hyperlink payloads: heuristic covers build output; explicit-link fast path is a follow-up.)*

## 3. UI

- [x] 3.1 `ToolbarItemKind.editor` "Open in editor" button in `BottomToolbar` (opens the CWD via `EditorLauncher.openDirectory`)
- [x] 3.2 `DesignTokens.editor` + `editorCommand` (tolerant-decoded) + a Settings → Terminal → Editor picker (+ custom-command field)

## 4. Verification

- [x] 4.1 `swift build` — green
- [x] 4.2 `EditorLauncherTests` (10) — suffix parsing, CWD-relative resolution (existing vs missing), CLI invocations, custom-template substitution
- [ ] 4.3 **Manual/GUI QA** — needs the app run (blocked here by the multi-display/Spaces screenshot issue): ⌘-click `path:line` from build output opens the editor at that line; toolbar button opens the CWD; custom command works; missing-CLI falls back
- [x] 4.4 `openspec validate editor-links --strict`
