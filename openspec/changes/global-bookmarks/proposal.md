## Why

`project-bookmarks` gave each folder a `.zTerminal.json` with its own bookmarks. But
many favorite commands aren't project-specific — `cd ~/work`, a personal deploy
script, `claude` — and retyping them (or copying a `.zTerminal.json` into every repo)
defeats the point. Users want **global bookmarks** that follow them into every folder,
shown alongside the current project's.

While extending the popover, the icon chooser also needed to become usable: the old
`Menu`-based picker rendered as a plain **text list** of SF Symbol names with no
preview, and offered only ~18 icons.

## What Changes

- Split the Bookmarks popover into two labeled sections:
  - **Global** — backed by `~/.zTerminal.json`, available in every directory.
  - **Current** (titled with the folder name) — backed by the active tab's
    `.zTerminal.json`.
- Each section has its **own "Add to …" button**; add/edit/delete write to that
  section's file. When the tab's directory *is* home (both would be the same file),
  the popover collapses to a single Global section.
- Filtering narrows both sections; **Return** runs the first visible bookmark
  (Global first, then Current).
- Replace the text-list icon `Menu` with a **searchable grid of rendered icon
  previews** that highlights the selection and only offers symbols available on the
  running system, and expand the candidate set from ~18 to ~180.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `project-bookmarks`: Bookmarks gain a global scope (`~/.zTerminal.json`) shown as a Global section beside the current folder's; the add/edit/delete flow targets the chosen section's file; the icon chooser becomes a visual, filterable grid of previews.

## Impact

- **`RunPopover`:** bookmarks now render two sections (`bookmarkSection(title:dir:)`);
  `BookmarkFormState` carries the target `dir`; add/edit/delete/`runFirstMatch` are
  keyed by directory instead of assuming the cwd.
- **`RunPopover` (`BookmarkForm`):** new `IconGridPicker` popover; the candidate icon
  list is filtered through `NSImage(systemSymbolName:)` so unavailable symbols never
  render as blanks.
- No config-format change: it reuses the existing `.zTerminal.json` `bookmarks` array,
  now also read from `~/.zTerminal.json`.
- No new external dependencies.
