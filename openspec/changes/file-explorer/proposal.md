## Why

zTerminal shows the current directory in the status bar and can reveal it in Finder, but
there's no way to *see the project's file tree* without leaving for Finder or running `ls`.
Developers expect a VS Code-style **file explorer sidebar**: a collapsible tree of the
working directory that stays in sync as they `cd` around, with quick actions to open, reveal,
and refresh. This makes the app feel like a real dev environment rather than a bare terminal,
and sets up phase 2 (a code viewer — files opened from the tree render in a syntax-highlighted
tab).

## What Changes

- Add a **collapsible left sidebar** (show/hide, ⌘⌥B or a toolbar button) that renders the
  active tab's directory as a **file tree** — folders expand/collapse, files listed, sorted
  folders-first then alphabetically, with type icons.
- A **header** on the sidebar with the root folder name and a **Refresh** button that
  re-reads the tree from disk.
- The tree's **root follows the active tab's current directory** — when the shell `cd`s (via
  the existing OSC 7 CWD tracking) or the user switches tabs, the sidebar **re-roots and
  reloads** to that directory. Only **directory** roots load (a non-directory CWD is ignored).
- **Lazy loading**: a folder's children are read only when it's first expanded, so opening a
  large project is instant; expansion state is remembered while the root is unchanged.
- **Row actions**: click a file → open it (phase 1: reveal in Finder / open with default app;
  phase 2 will open it in the code viewer); click a folder → expand/collapse; right-click →
  Reveal in Finder, Copy path, Open in new tab (for folders), Refresh.
- **Hidden files** toggle (dotfiles off by default). Respect basic ignores (`.git`, common
  build dirs) behind the hidden-files toggle.
- Styled with the existing Liquid Glass chrome; sidebar width is draggable and persisted.

## Capabilities

### New Capabilities
- `file-explorer`: A collapsible VS Code-style sidebar showing the active tab's directory as a
  lazily-loaded, refreshable file tree that follows the shell's CWD, with open/reveal/new-tab
  row actions and a hidden-files toggle.

### Modified Capabilities
- `app-shell`: the window layout gains a leading sidebar column (collapsible) beside the
  existing tab bar + terminal + toolbar stack.

## Impact

- **New UI:** a `FileExplorerSidebar` (SwiftUI, `List`/`OutlineGroup` or an `NSOutlineView`
  wrapper for large trees) + a `FileNode` model, hosted in a leading column in `RootView`
  inside the glass panel. A show/hide toggle (menu ⌘⌥B + toolbar button) and a persisted
  width + visibility.
- **New logic:** a `FileTreeModel` that reads directory contents off the main thread, caches
  per-folder children, and re-roots when the active session's `cwd` changes (observing the
  existing OSC 7 tracking) or the active tab changes.
- **Reuses:** `WindowModel.active`/`sessions` + `SessionModel.cwd`, the Reveal-in-Finder and
  open-in-new-tab plumbing (`WindowRouter`), and the theme chrome.
- **No new external dependencies** (FileManager + FSEvents/`DispatchSource` for optional
  auto-refresh; manual Refresh covers the baseline).

## Non-Goals

- Editing files or a code viewer — that's the phase-2 `code-editor` change (files opened from
  the tree will hand off to it once it exists; until then they reveal/open externally).
- Drag-to-move/rename/delete file operations, multi-root workspaces, and git decoration
  (changed/untracked badges) — possible follow-ups, out of scope here.
- Live file-system watching is optional/best-effort; the guaranteed path is the Refresh button
  + reload on CWD change.
