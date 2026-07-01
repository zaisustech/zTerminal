## Context

`project-bookmarks` already reads `.zTerminal.json` from the active tab's CWD and
renders its `bookmarks` array in the Bookmarks popover, with add/edit/delete writing
back to that file. `ThemeManager` already loads a **global** `~/.zTerminal.json` for
the theme cascade, so the global config location is an established convention — this
change reuses it for bookmarks too.

## Goals / Non-Goals

**Goals:** global bookmarks available everywhere; show them beside the current
folder's; edits target the right file; a visual icon picker.

**Non-Goals:** merging/deduping across the two files; per-bookmark scope flags;
syncing global bookmarks to a cloud; changing the `.zTerminal.json` schema.

## Decisions

### Decision: Reuse `~/.zTerminal.json` for global bookmarks
No new file or format. Global = `NSHomeDirectory()/.zTerminal.json` `bookmarks`;
Current = `<cwd>/.zTerminal.json` `bookmarks`. Both use the existing
`ZTerminalConfig` load/add/update/remove APIs, which already take a target `dir`.

### Decision: Two sections, collapsing at home
Render a **Global** section and, when `cwd != home`, a **Current** section titled with
the folder's last path component. At home the two files are identical, so only Global
shows — avoids a confusing duplicate.

### Decision: Key all mutations by directory, not the cwd
`BookmarkFormState` carries the `dir` to save into; edit/delete pass the section's
`dir`; `runFirstMatch` tries Global first, then Current. This removes the old
assumption that every bookmark lives in the cwd file.

### Decision: Self-validating icon grid
The icon chooser is a `popover` containing a `LazyVGrid` of buttons, each rendering the
SF Symbol as a preview and highlighting the current selection, with a filter field.
The candidate list is filtered once through `NSImage(systemSymbolName:)` so any symbol
missing on the running macOS is dropped rather than shown as a blank tile — this makes
it safe to grow the list freely (~180 candidates).

## Risks / Trade-offs

- **Same-named bookmark in both sections.** Both show; the sections are labeled, so
  it's clear which is which. No dedup by design.
- **Global writes touch the user's home file.** Expected — that's what "global" means;
  the file is created on first add, same as the per-project flow.
- **Icon list drift across OS versions.** Handled by the runtime availability filter;
  older macOS simply shows fewer icons.

## Migration Plan

Purely additive and backward-compatible. Existing per-project `.zTerminal.json` files
work unchanged and appear in the Current section; the Global section is empty until the
user adds a bookmark to it. Rollback = revert to the single-section popover.

## Open Questions

None.
