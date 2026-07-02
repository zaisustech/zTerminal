## 1. Tree model

- [x] 1.1 `FileNode` (url, name, isDirectory, `iconName`; lazily-populated `children: [FileNode]?`) — Identifiable/ObservableObject (`Sources/zTerminal/FileExplorer/FileNode.swift`)
- [x] 1.2 `FileTreeModel` (ObservableObject): root; `load(_:)` reading `FileManager.contentsOfDirectory` off-main, publishing on main; children cached per node
- [x] 1.3 Sorting (folders first, then case-insensitive name) + hidden-files filter (dotfiles + `.git`/`node_modules`/`.build`… gated by toggle) — pure `FileTree.arrange`, unit-tested
- [x] 1.4 Re-root when the active tab's `cwd` changes (`SidebarRootUpdater` observes the active `SessionModel.cwd`; keyed by session id → also re-roots on tab switch); `setRoot` ignores non-directory / unchanged paths
- [x] 1.5 `refresh()` — clear caches, reload the root + re-expand still-present expanded nodes. *(Optional live FS watch not implemented; Refresh + CWD-reload is the contract, as speced.)*

## 2. Sidebar UI

- [x] 2.1 `FileExplorerSidebar` — header (root name + Refresh + hidden-files eye toggle) and a lazy recursive tree, Liquid Glass (`.ultraThinMaterial`)
- [x] 2.2 Rows: disclosure for folders, icon + name; single-click expands folder / selects file, double-click opens; lazy child load on expand. *(Keyboard tree-nav ↑/↓/←/→ deferred — mouse + double-click/Enter-via-open covered; follow-up.)*
- [x] 2.3 Row context menu: Open / Open in New Tab (folders), Reveal in Finder, Copy Path
- [x] 2.4 `onOpenFile(url)` hook (phase 1: `NSWorkspace.open`; left for phase-2 code viewer to intercept)

## 3. Layout & wiring

- [x] 3.1 Leading sidebar column in `RootView` inside the glass panel (`HStack { FileExplorerColumn (if visible); VStack{ TabBar; terminal; toolbar } }`, glass wraps both)
- [x] 3.2 Persisted `sidebarVisible` (default false) + `sidebarWidth` (clamped 160…460) via `@AppStorage`; draggable resize handle; toggle animates
- [x] 3.3 Toggle: **⌘⌥B** menu item ("Toggle File Explorer") + a `ToolbarItemKind.sidebar` button in the bottom toolbar (both post `.toggleSidebar`)
- [x] 3.4 Feed the tree from the active `SessionModel.cwd`; folder "Open in New Tab" via `WindowRouter.openInNewTab`; reveal via `NSWorkspace`

## 3b. Follow-up additions

- [x] 3b.1 **Folder pin** — header pin button; while pinned `setRoot` ignores CWD changes (`FileTreeModel.togglePin`/`isPinned`), unpin resumes following the CWD
- [x] 3b.2 **Drag row → terminal** — tree rows are `.onDrag` file-URL providers; dropping on the terminal inserts the shell-escaped path (reuses the terminal's existing Finder-drop handling)
- [x] 3b.3 **Fix: auto-load** — the tree now observes the root `FileNode` (`SidebarTree`) so it renders as soon as children load, instead of spinning until a sidebar toggle recreated the view
- [x] 3b.4 **Pin to Top (favorites)** — folder context-menu "Pin to Top"/"Remove from Pinned"; a persistent Pinned section at the top rendering each pin as its **own expandable tree** (browse in place, no re-root). Header pin renamed to a **lock** to disambiguate
- [x] 3b.5 **Fix: window-drag** — `isMovableByWindowBackground = false` so dragging a tree row / reordering a tab no longer moves the whole window
- [x] 3b.6 **Fix: sidebar left-clipping** — `.frame(width:alignment:.leading)` + `.clipped()` + fill-height so long file names truncate on the right instead of centering and spilling off the window's left edge (VS Code-style fixed panel)
- [x] 3b.7 **Pinned = explore in place** — pinned folders render as their own expandable `FileNode` trees (browse without changing the workspace root), instead of re-rooting on click
- [x] 3b.8 **Home button + back-to-workspace** — header 🏠 unlocks + re-roots to the active tab's CWD (`FileTreeModel.workspacePath`/`goToWorkspace`), so the original tree is always reachable after pinning/locking
- [x] 3b.9 **Window-drag region** — `WindowDragHandle` behind the tab bar restores dragging the window from empty chrome (after background-drag was disabled for content)
- [x] 3b.10 **Collapse All** — header button (`FileTreeModel.collapseAll`) collapses every expanded folder to the top level (VS Code-style); root + pinned stay visible

## 4. Verification

- [x] 4.1 `swift build` — green
- [x] 4.2 Unit tests: `FileTreeTests` (5) — folders-first ordering, hidden-default filtering, show-hidden, case-insensitive sort, empty
- [ ] 4.3 **Manual/GUI QA** — needs the app run (blocked here by the multi-display/Spaces screenshot issue): ⌘⌥B toggles + persists; tree folders-first with icons; expand lazily loads; `cd` re-roots; tab switch re-roots; Refresh picks up disk changes; hidden-files eye; context-menu actions; resize persists
- [x] 4.4 `openspec validate file-explorer --strict`
