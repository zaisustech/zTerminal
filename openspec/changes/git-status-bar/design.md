## Context

The status bar already tracks the CWD per `SessionModel` (OSC 7 + fallback) and knows when
a tab is idle at the prompt (`isIdleAtPrompt`, used by keep-awake and the script runner).
Those two signals are exactly the refresh triggers a git segment needs.

## Goals / Non-Goals

**Goals:** at-a-glance branch + dirty + ahead/behind in the bar; stays current after
commits/pulls; one-click common git actions; zero cost outside a repo.

**Non-Goals:** a full git GUI (diffs, staging, history); bundling libgit2; per-file
decorations; background polling on a timer.

## Decisions

### Decision: Compute via `git` plumbing, off-main, debounced
Run cheap plumbing in the CWD: `git rev-parse --abbrev-ref HEAD` (branch; `--short HEAD`
when detached), `git status --porcelain` (dirty = any output), and
`git rev-list --left-right --count @{upstream}...HEAD` (behind/ahead) when an upstream
exists. Run on a background queue; debounce rapid CWD changes; cache per directory.

### Decision: Refresh on CWD change and on return-to-idle
Recompute when `session.cwd` changes and when the tab transitions busy → idle (a command
finished — likely a commit/checkout/pull). No periodic polling, so an idle tab costs
nothing.

### Decision: Hidden outside a repo
When `git rev-parse` reports the directory is not in a work tree, publish `nil` and render
no git segment — the bar looks exactly as it does today for non-repo folders.

### Decision: Quick actions reuse run semantics
The click menu runs `git status`/`pull`/`push`/`stash`/`fetch` through the same
current-tab-when-idle / new-tab-when-busy path the popovers use, so long operations don't
clobber a busy shell.

## Risks / Trade-offs

- **Cost in huge repos** — `git status` can be slow; debounce + background queue + only-on-
  change/idle keeps it off the hot path. Could add a size guard later.
- **Detached HEAD / no upstream** — show short SHA / omit ahead-behind gracefully.
- **git not installed** — segment simply never appears.
- **Staleness between refreshes** — acceptable; the return-to-idle trigger catches the
  common cases (commit, checkout, pull) right after they happen.

## Migration Plan

Additive and self-contained; no persisted state. Rollback = remove the git segment and its
computation.

## Open Questions

- Should there be a manual refresh affordance (e.g. click-to-refresh) for the rare case a
  repo changes without a command running in the tab (external tool, another terminal)?
