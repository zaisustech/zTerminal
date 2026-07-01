## Why

zTerminal's signature is a **folder-aware bottom status bar**. For developers, the folder
is almost always a git repo — and the thing you most want at a glance is the repo's state:
which branch, is it dirty, am I ahead/behind the remote. Today that only lives in the
shell prompt (branch only) and requires running `git status` by hand. Making the status
bar **repo-aware** is the natural next step for its identity.

## What Changes

- Show, in the bottom status bar when the CWD is inside a git repo:
  - the **current branch** (or short SHA when detached),
  - a **dirty indicator** when there are uncommitted changes,
  - **ahead/behind** counts vs the upstream (e.g. ↑2 ↓1).
- **Refresh** the git state when the working directory changes and when a foreground
  command finishes (returns to the prompt), so it stays current after commits/pulls.
- Clicking the git segment opens a **quick actions** menu: git status, pull, push, stash,
  fetch, and reveal — each running in the tab using the existing run semantics.
- The git segment is **hidden** when the CWD is not a repository.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `directory-status-bar`: The status bar gains a git segment (branch, dirty, ahead/behind) that refreshes on CWD change and command completion, with a quick-actions menu; hidden outside a repo.

## Impact

- **New module:** `GitStatus` — computes branch/dirty/ahead-behind via `git` plumbing for a
  directory, off the main thread, debounced.
- **`SessionModel`/status bar:** a published `gitStatus`, recomputed on CWD change and on
  return-to-idle; a git segment view in `BottomToolbar` with a quick-actions menu.
- No new external dependencies (shells out to the user's `git`).
