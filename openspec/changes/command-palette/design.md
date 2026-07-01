## Context

Every source the palette needs already exists: `TaskRunner.detect(in:)` returns grouped
tasks, `ScriptShortcut` lists global shortcuts, `ZTerminalConfig.load(in:)` reads
bookmarks (home + cwd), `WindowModel.sessions` holds open tabs, and OSC 7 already tracks
CWD per session. The palette is an aggregation + presentation layer, not new plumbing.

## Goals / Non-Goals

**Goals:** one ⌘K surface; fuzzy find across all runnable/navigable things; keyboard-only
operation; consistent run semantics with the existing popovers.

**Non-Goals:** a plugin/action API; remote or SSH targets; editing bookmarks from the
palette (that stays in the Bookmarks popover); command history search (separate feature).

## Decisions

### Decision: Aggregate at open time from existing providers
Build the item list when the palette opens (cheap; the popovers already do synchronous
detection). Each `PaletteItem` carries a category, title, subtitle (the command or path),
icon, and an `activate(newTab:)` closure so the palette needs no knowledge of how each
source runs.

### Decision: Reuse the run semantics
Activating a runnable item calls the same path the popovers use: current tab when
`session.isIdleAtPrompt`, else a new tab; ⌘Return forces a new tab. Directory items jump
the active tab (or open a new tab in that dir); tab items call `WindowModel.select`.

### Decision: Fuzzy ranking with recency bias
Subsequence fuzzy match on the title (+ category as a weak field), ranked by score; ties
and empty query fall back to a most-recently-used ordering. Group headers shown when the
query is empty; a flat ranked list when searching.

### Decision: Recent directories store
Maintain a capped (e.g. 20), de-duplicated, persisted list of visited directories,
appended on CWD change. Powers the "recent directories" category and is independent of
the shell's own history.

## Risks / Trade-offs

- **Item list staleness** — rebuilt each open, so it always reflects the current CWD and
  tabs; no live subscription needed.
- **⌘K collision** — some programs use ⌘K (e.g. clear in some shells). Palette binds at
  the app/window level; document it, allow rebinding later if requested.
- **Large task lists** — ranking caps the visible results; the filter narrows quickly.

## Migration Plan

Purely additive. No persisted schema changes except the new recent-directories list
(absent → empty). Rollback = remove the palette and its keybinding.

## Open Questions

- Should command history (past shell commands) be a palette category too, or a separate
  ⌘R feature? (Leaning separate.)
