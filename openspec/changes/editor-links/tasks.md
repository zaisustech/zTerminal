## 1. Editor launcher

- [ ] 1.1 `EditorLauncher`: resolve a token against a CWD, accept only existing files
- [ ] 1.2 Parse a trailing `:line[:col]` suffix (pure + unit-tested)
- [ ] 1.3 Per-editor launch templates (VS Code, Cursor, Xcode) + custom `{file}/{line}/{col}` template; `open -a` fallback

## 2. Terminal click routing

- [ ] 2.1 On ⌘-click, get the token under the pointer (OSC 8 hyperlink when present, else path heuristic)
- [ ] 2.2 Route file tokens to `EditorLauncher`; open at the parsed line/col

## 3. UI

- [ ] 3.1 Add an "Open in editor" button to `BottomToolbar` (opens the CWD)
- [ ] 3.2 Add an `editor` setting to `DesignTokens` (tolerant-decoded) + a Settings control

## 4. Verification

- [ ] 4.1 `swift build`
- [ ] 4.2 Unit-test suffix parsing and CWD-relative resolution (existing vs missing files)
- [ ] 4.3 Manual: cmd-click `path:line` from build output opens the editor at that line; the status-bar button opens the CWD
- [ ] 4.4 Run `openspec validate editor-links --strict`
