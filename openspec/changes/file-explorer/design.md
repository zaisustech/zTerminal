## Context

zTerminal is a SwiftUI shell around an AppKit terminal. `RootView` lays out a floating glass
panel: `VStack { TabBar; terminal ZStack; BottomToolbar }`. Each tab is a `SessionModel` whose
`cwd` is kept live via OSC 7 (with a proc-info fallback); `WindowModel.active` is the focused
tab. Reveal-in-Finder and open-in-new-tab already exist (`SessionModel.revealInFinder`,
`WindowRouter.openInNewTab`). The sidebar is a **read layer over the file system** driven by
the active tab's `cwd` — no new shell or terminal plumbing.

## Goals / Non-Goals

**Goals:** a collapsible left sidebar with a lazily-loaded file tree rooted at the active
tab's CWD; a header + Refresh; auto re-root/reload when the CWD changes or the active tab
switches (directories only); folders-first sorting + type icons; row actions
(open/reveal/new-tab); hidden-files toggle; persisted width + visibility; Liquid Glass styling.

**Non-Goals:** editing/viewing file contents (phase-2 `code-editor`); rename/move/delete;
multi-root; git status decoration; guaranteed live FS watching (manual Refresh + CWD reload is
the contract).

## Decisions

### Decision: Sidebar is a leading column in the glass panel
Wrap the existing panel content in an `HStack { FileExplorerSidebar (if visible); Divider;
VStack{ TabBar; terminal; toolbar } }`. The sidebar lives *inside* the glass panel so it
shares the frosted chrome and rounded clip. Visibility + width are `@AppStorage`/token-backed
and animate on toggle. This keeps `RootView`'s existing structure intact — the terminal column
is unchanged; the sidebar is additive.

### Decision: `FileTreeModel` re-roots on active CWD, not on every session
A single `FileTreeModel` (owned by the window) tracks the **active** tab's `cwd`. It observes
`WindowModel.activeID` and the active `SessionModel.cwd` (both `@Published`); when either
changes to a valid directory, it re-roots and loads the top level. A non-directory or
unchanged path is ignored (so noisy CWD updates don't thrash). One model (not per-tab) matches
the single visible sidebar and avoids N watchers.

### Decision: Lazy, cached children read off the main thread
`FileNode` holds `url`, `isDirectory`, and lazily-populated `children` (nil = not yet loaded).
Expanding a folder reads its contents on a background queue (`FileManager.contentsOfDirectory`
with resource keys) and publishes back on main. Children are cached per node for the life of
the root; Refresh clears caches and reloads expanded nodes. This keeps opening a large repo
instant — only expanded folders are read.

### Decision: Sorting, icons, hidden files
Sort each level **folders first, then case-insensitive name**. Icons via `NSWorkspace.icon(
forFile:)` or SF Symbols by extension (folder, swift, js, json, md, image, …). Dotfiles and
common noise (`.git`, `node_modules`, `.build`) are hidden unless the **hidden-files toggle**
is on. The toggle is a sidebar-header control, persisted.

### Decision: Row actions and open behavior
- Folder row: expand/collapse on click; disclosure triangle mirrors state.
- File row: single click selects; double click / Enter **opens** it. Phase 1 opens via
  `NSWorkspace.open` (default app) or Reveal-in-Finder; a hook (`onOpenFile(url)`) is left so
  phase-2 `code-editor` can intercept text/code files and open them in a viewer tab instead.
- Context menu: Reveal in Finder, Copy path, Open in new tab (folders → `WindowRouter`),
  Refresh (folder subtree).

### Decision: Refresh + optional live watch
The header **Refresh** button is the guaranteed reload (clears caches, re-reads expanded
nodes). Optionally, a best-effort `DispatchSource`/FSEvents watch on the root auto-refreshes on
change; if unavailable it silently degrades to manual Refresh. CWD change always reloads
regardless.

### Decision: Persist visibility + width
Sidebar `isVisible` (default off, so existing users are unaffected) and `width` (clamped, e.g.
160…420) persist via `@AppStorage`. Toggle via **⌘⌥B** (menu item) and a toolbar button.

## Risks / Trade-offs

- **Huge directories** — reading a folder with tens of thousands of entries can stall. Mitigate
  with background reads + lazy expansion; if needed later, cap/paginate a level and show a
  "N more…" affordance. Log any cap rather than silently truncating.
- **CWD thrash** — rapid `cd`s emit many OSC 7 updates. Debounce re-root and skip when the
  resolved directory is unchanged.
- **Tree vs. live FS drift** — without watching, the tree can go stale; the Refresh button and
  CWD-reload bound the staleness, and it's documented as the contract.
- **Symlink loops / permission errors** — don't follow directory symlinks into cycles; treat
  unreadable dirs as empty leaves rather than erroring.

## Migration Plan

Additive. New sidebar + model + a leading column in `RootView`, a menu item, a toolbar button,
and persisted `sidebarVisible`/`sidebarWidth`. Default hidden, so nothing changes until the
user opens it. Rollback = remove the column + model + toggles.

## Open Questions

- Sidebar on the left only, or user-movable to the right? (Leaning: left, like VS Code.)
- Should the tree root be pinnable (stay on a chosen folder) instead of always following CWD?
  (Leaning: follow CWD by default, add an optional pin later.)
- Git decoration (M/U badges) now or as a follow-up? (Leaning: follow-up; reuse `Git.status`.)
