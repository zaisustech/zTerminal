## 1. Git status computation

- [x] 1.1 `GitStatus` model (branch/detached SHA, dirty bool, ahead/behind ints, isRepo)
- [x] 1.2 Compute via `git` plumbing for a directory, on a background queue, debounced + cached
- [x] 1.3 Handle detached HEAD (short SHA) and no-upstream (omit ahead/behind) gracefully

## 2. Wiring & refresh

- [x] 2.1 Publish `gitStatus` on `SessionModel`; recompute on CWD change
- [x] 2.2 Recompute on busy → idle transition (a command finished)
- [x] 2.3 Publish nil (hide segment) when the directory is not a git work tree

## 3. UI

- [x] 3.1 Git segment in `BottomToolbar`: branch, dirty indicator, ahead/behind
- [x] 3.2 Click → quick actions menu (status/pull/push/stash/fetch/reveal) using existing run semantics

## 4. Verification

- [x] 4.1 `swift build`
- [x] 4.2 Unit-test the porcelain/ahead-behind parsing (dirty vs clean, detached, no upstream)
- [ ] 4.3 Manual: segment shows branch+dirty in a repo, updates after a commit/pull, hidden outside a repo
- [x] 4.4 Run `openspec validate git-status-bar --strict`
