## 1. Global + Current sections

- [x] 1.1 Load bookmarks from `~/.zTerminal.json` (Global) and `<cwd>/.zTerminal.json` (Current) via existing `ZTerminalConfig` APIs
- [x] 1.2 Render two labeled sections in the Bookmarks popover; collapse to Global-only when `cwd == home`
- [x] 1.3 Title the Current section with the folder's last path component
- [x] 1.4 Filter narrows both sections; `runFirstMatch` runs the first visible bookmark (Global first)

## 2. Section-targeted add / edit / delete

- [x] 2.1 Add a `dir` to `BookmarkFormState`; per-section "Add to …" button writes to that section's file
- [x] 2.2 Edit and delete operate on the bookmark's own section directory (not the cwd)

## 3. Visual icon picker

- [x] 3.1 Replace the text-list `Menu` with an `IconGridPicker` popover of rendered previews + selection highlight + name filter
- [x] 3.2 Expand the candidate icon set (~18 → ~180), filtered through `NSImage(systemSymbolName:)` so unavailable symbols never render blank

## 4. Verification

- [x] 4.1 `swift build`
- [x] 4.2 Verified all candidate symbols resolve on this macOS via `NSImage(systemSymbolName:)`
- [ ] 4.3 Manual: Global + Current sections appear; add to each writes the right file; edit/delete target the right file; icon grid shows previews and filters
- [x] 4.4 Run `openspec validate global-bookmarks --strict`
