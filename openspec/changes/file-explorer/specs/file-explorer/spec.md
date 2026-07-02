## ADDED Requirements

### Requirement: Collapsible file-explorer sidebar
The window SHALL provide a left sidebar that can be shown or hidden via a keyboard shortcut
(⌘⌥B) and a toolbar button. Its visibility and width SHALL persist across launches, and its
width SHALL be adjustable by dragging its trailing edge (clamped to a sensible range). The
sidebar SHALL be hidden by default.

#### Scenario: Toggle the sidebar
- **WHEN** the user presses ⌘⌥B (or clicks the sidebar toolbar button)
- **THEN** the sidebar shows if hidden and hides if shown, and the choice persists across launches

#### Scenario: Resize the sidebar
- **WHEN** the user drags the sidebar's trailing edge
- **THEN** its width changes within the allowed range and the new width persists

### Requirement: Show the working directory as a file tree
When visible, the sidebar SHALL display the active tab's current directory as a tree: folders
that expand/collapse and files as leaves, sorted folders-first then case-insensitively by
name, each with a type-appropriate icon. A header SHALL show the root folder's name.

#### Scenario: Render the tree
- **WHEN** the sidebar is shown for a tab whose working directory is a folder with files and subfolders
- **THEN** the folder's contents appear as a tree, folders first then files, each with an icon, under a header showing the root folder name

#### Scenario: Expand a folder
- **WHEN** the user clicks a collapsed folder row
- **THEN** the folder expands and its children are shown; clicking again collapses it

### Requirement: Lazy loading of folder contents
A folder's children SHALL be read from disk only when the folder is first expanded (not
eagerly for the whole tree), so opening a large project is responsive. Directory reads SHALL
happen off the main thread.

#### Scenario: Large project opens instantly
- **WHEN** the sidebar roots at a directory containing many nested folders
- **THEN** only the top level is read initially, and deeper folders are read when expanded

### Requirement: Root follows the active tab's working directory
The tree's root SHALL track the active tab's current directory: when the shell changes
directory (tracked via OSC 7) or the user switches tabs, the sidebar SHALL re-root and reload
to that directory. Only directories SHALL be used as a root; a non-directory or unchanged path
SHALL be ignored.

#### Scenario: Reload on cd
- **WHEN** the shell in the active tab changes into a different directory
- **THEN** the sidebar re-roots to that directory and shows its contents

#### Scenario: Reload on tab switch
- **WHEN** the user switches to another tab in a different directory
- **THEN** the sidebar re-roots to the newly active tab's directory

#### Scenario: Non-directory CWD ignored
- **WHEN** the tracked path is not an existing directory
- **THEN** the sidebar keeps its current root rather than clearing or erroring

### Requirement: Collapse all folders
The sidebar header SHALL provide a **Collapse All** control that collapses every expanded
folder back to the top level (the root and pinned folders remain visible, their subtrees
closed).

#### Scenario: Collapse all
- **WHEN** several folders are expanded and the user clicks Collapse All
- **THEN** all expanded folders collapse to the top level

### Requirement: Refresh
The sidebar header SHALL provide a Refresh control that re-reads the tree from disk, reflecting
files added, removed, or renamed since it was last loaded, preserving which folders are
expanded where they still exist.

#### Scenario: Refresh picks up changes
- **WHEN** files are added or removed on disk and the user clicks Refresh
- **THEN** the tree updates to match the current directory contents

### Requirement: Row actions
Clicking a folder SHALL expand/collapse it; opening a file (double-click or Enter) SHALL open
it (in phase 1, via the system default app or Reveal in Finder). A right-click context menu
SHALL offer at least Reveal in Finder, Copy path, and — for folders — Open in new tab.

#### Scenario: Open a file
- **WHEN** the user double-clicks a file row
- **THEN** the file is opened (phase 1: system default / reveal), via a hook a later code viewer can intercept

#### Scenario: Open a folder in a new tab
- **WHEN** the user right-clicks a folder and chooses Open in new tab
- **THEN** a new terminal tab opens at that folder

#### Scenario: Reveal and copy path
- **WHEN** the user chooses Reveal in Finder or Copy path from a row's context menu
- **THEN** the item is revealed in Finder, or its absolute path is copied to the clipboard

### Requirement: Lock the root folder
The sidebar header SHALL provide a **lock** control. When locked, the tree SHALL keep its
current root folder and SHALL ignore working-directory changes (it stays on the chosen
folder); when unlocked, it SHALL resume following the active tab's CWD.

#### Scenario: Lock keeps the folder
- **WHEN** the user locks the current folder and then `cd`s elsewhere in the terminal
- **THEN** the tree stays on the locked folder rather than re-rooting

#### Scenario: Unlock resumes following the CWD
- **WHEN** the user unlocks
- **THEN** the tree re-roots to the active tab's current directory and follows it again

### Requirement: Pin folders to the top
A folder's context menu SHALL offer **Pin to Top** (and **Remove from Pinned** when already
pinned). Pinned folders SHALL appear in a persistent **Pinned** section at the top of the
sidebar as their own **expandable trees** — the user browses their files in place WITHOUT
changing the workspace root. The pinned set SHALL persist across launches.

#### Scenario: Pin a folder
- **WHEN** the user right-clicks a folder and chooses Pin to Top
- **THEN** the folder appears in the Pinned section at the top of the sidebar, and persists across launches

#### Scenario: Explore a pinned folder in place
- **WHEN** the user expands a folder in the Pinned section and opens files within it
- **THEN** its subtree is browsable and files open, while the main tree's root (the active tab's directory) is unchanged

#### Scenario: Unpin
- **WHEN** the user chooses Remove from Pinned on a pinned folder
- **THEN** it disappears from the Pinned section

### Requirement: Drag a file to the terminal
Rows in the tree SHALL be draggable, and dropping a dragged file onto the terminal SHALL
insert that file's path (shell-escaped), the same as dragging a file from Finder.

#### Scenario: Drag inserts the path
- **WHEN** the user drags a file from the sidebar and drops it on the terminal
- **THEN** the file's shell-escaped path is inserted at the prompt

### Requirement: Hidden files toggle
The sidebar SHALL hide dotfiles and common noise directories (e.g. `.git`, `node_modules`,
`.build`) by default, and SHALL provide a toggle to show them. The toggle SHALL persist.

#### Scenario: Show hidden files
- **WHEN** the user enables the hidden-files toggle
- **THEN** dotfiles and previously hidden directories become visible in the tree

#### Scenario: Hidden by default
- **WHEN** the sidebar first loads a directory
- **THEN** dotfiles and common noise directories are not shown until the toggle is enabled
