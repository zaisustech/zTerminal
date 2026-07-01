# terminal-core Specification

## Purpose
TBD - created by archiving change bootstrap-terminal-app. Update Purpose after archive.
## Requirements
### Requirement: Spawn a login shell over a PTY
The terminal SHALL start the user's login shell (from `$SHELL`, defaulting to
`/bin/zsh`) as a child process attached to a pseudo-terminal, inheriting the
user's environment. The terminal SHALL accept a configurable initial working
directory, defaulting to the user's home directory when none is provided, and
SHALL start the shell in that directory.

#### Scenario: Shell starts on launch
- **WHEN** the terminal surface initializes with no working directory specified
- **THEN** a login shell is running on a PTY, started in the user's home directory, and its prompt is displayed

#### Scenario: Shell starts in a specified directory
- **WHEN** the terminal is initialized with an initial working directory (e.g. from Finder integration)
- **THEN** the shell's current working directory is that directory when the prompt appears

#### Scenario: Environment is inherited
- **WHEN** the shell starts
- **THEN** `TERM` is set to a value SwiftTerm supports (e.g. `xterm-256color`) and the user's PATH is available

#### Scenario: Shell is selectable in Settings
- **WHEN** the user chooses zsh or bash in Settings (default zsh)
- **THEN** newly opened tabs spawn that shell, while existing tabs keep their current shell, and the choice persists across launches

### Requirement: Handle shell spawn failure
The terminal SHALL detect when the shell fails to spawn (e.g. `$SHELL` is invalid
or `exec` fails) and SHALL show a readable error in the terminal surface rather
than crashing or presenting a blank pane.

#### Scenario: Invalid shell path
- **WHEN** the configured shell cannot be executed
- **THEN** the terminal displays an error message identifying the failure and does not crash

### Requirement: Bidirectional input/output
The terminal SHALL forward keyboard input to the shell and render the shell's
output, including control sequences, in real time.

#### Scenario: Keystrokes reach the shell
- **WHEN** the user types a command and presses Return
- **THEN** the command executes in the shell and its output appears in the terminal

#### Scenario: Interactive programs work
- **WHEN** the user runs a full-screen program (e.g. `vim`, `top`)
- **THEN** the program renders correctly and responds to input, and restores the screen on exit

### Requirement: Resize propagation
The terminal SHALL propagate window/grid size changes to the PTY so programs
observe the correct number of rows and columns.

#### Scenario: Resize updates the PTY
- **WHEN** the terminal grid dimensions change
- **THEN** the PTY window size is updated (SIGWINCH) and `stty size` reports the new dimensions

### Requirement: Copy and paste
The terminal SHALL support selecting text with the mouse and copying it, and
pasting clipboard text into the shell.

#### Scenario: Copy selected text
- **WHEN** the user selects terminal text and copies (Cmd+C)
- **THEN** the selected text is placed on the system clipboard

#### Scenario: Paste text
- **WHEN** the user pastes (Cmd+V)
- **THEN** the clipboard text is sent to the shell as input

### Requirement: Quick Look the selected path
The terminal SHALL provide a Quick Look action (context menu and ⌘Y) that previews
the file referenced by the current selection, resolving shell quoting, `~`, and
paths relative to the current working directory.

#### Scenario: Preview a selected image path
- **WHEN** the user selects a file path (e.g. a dragged-in image's path) and invokes Quick Look
- **THEN** a Quick Look panel opens previewing that file

#### Scenario: Non-file selection
- **WHEN** the selection does not resolve to an existing file
- **THEN** no panel opens (and the action is absent from the context menu)

### Requirement: Drag and drop files and folders
The terminal SHALL accept files and folders dragged from Finder. On drop it SHALL
insert the dropped item's shell-escaped path(s) at the cursor (space-separated for
multiple), so paths with spaces or unicode are safe. When the Command key is held
during a folder drop, it SHALL instead open a new tab whose shell starts in that
folder. Dropped plain text SHALL be inserted as input.

#### Scenario: Drop a file inserts its escaped path
- **WHEN** the user drags a file from Finder onto the terminal
- **THEN** the file's path is inserted at the cursor, shell-escaped (quoted), followed by a space

#### Scenario: Drop multiple items
- **WHEN** the user drops several files/folders at once
- **THEN** all of their escaped paths are inserted, space-separated

#### Scenario: Command-drop a folder opens a tab there
- **WHEN** the user holds Command and drops a folder onto the terminal
- **THEN** a new tab opens with its shell started in that folder

#### Scenario: Path with spaces is safe
- **WHEN** the dropped path contains spaces or unicode
- **THEN** the inserted path is quoted so the shell treats it as a single argument

### Requirement: Clear the terminal
The terminal SHALL provide a "Clear" action bound to Cmd+K that clears the visible
screen and the scrollback buffer and leaves a fresh shell prompt.

#### Scenario: Cmd+K clears the window
- **WHEN** the user presses Cmd+K
- **THEN** the visible output and scrollback are cleared and a fresh prompt is shown

#### Scenario: Clear does not disturb the running shell
- **WHEN** the user clears while at a prompt
- **THEN** the shell process continues unaffected (no new shell is spawned)

#### Scenario: Clear from the toolbar
- **WHEN** the user clicks the trash icon in the bottom toolbar
- **THEN** the terminal clears exactly as Cmd+K does

### Requirement: Copy selected text automatically
The terminal SHALL copy selected text to the system clipboard automatically as soon
as a selection is made (copy-on-select), in addition to explicit copy.

#### Scenario: Selecting text copies it
- **WHEN** the user selects text in the terminal with the mouse
- **THEN** the selected text is placed on the system clipboard without a further keystroke

#### Scenario: Empty selection does not clobber the clipboard
- **WHEN** the user clicks without selecting any text
- **THEN** the existing clipboard contents are left unchanged

### Requirement: Right-click context menu
The terminal SHALL show a context menu on right-click (or Control-click) offering at
least Copy, Paste, Select All, Clear, and Reveal in Finder, with items enabled
according to context (e.g. Copy enabled only when text is selected).

#### Scenario: Right-click shows the menu
- **WHEN** the user right-clicks in the terminal
- **THEN** a context menu appears with Copy, Paste, Select All, Clear, and Reveal in Finder

#### Scenario: Paste from the menu
- **WHEN** the user chooses Paste from the context menu
- **THEN** the clipboard text is sent to the shell as input

### Requirement: Option-as-Meta and control keys
The terminal SHALL send the Meta/Alt prefix (ESC) for the Option key so
readline-, emacs-, vim-, and agent-style Alt bindings work, and SHALL forward
control keys (Ctrl+C → SIGINT, Ctrl+D → EOF, Ctrl+Z → SIGTSTP) to the shell. The
Option-as-Meta behavior SHALL be enabled by default and configurable.

#### Scenario: Option sends Meta
- **WHEN** the user presses Option+a (with Option-as-Meta enabled)
- **THEN** the terminal sends the ESC-prefixed sequence (e.g. `ESC a`) that programs interpret as Meta/Alt

#### Scenario: Agent newline shortcut works
- **WHEN** the user presses Option+Return (or Shift+Return) inside an AI CLI agent
- **THEN** the agent receives the newline/multiline sequence it expects rather than submitting

#### Scenario: Control-C interrupts
- **WHEN** a program is running and the user presses Ctrl+C
- **THEN** SIGINT is delivered to the foreground process

### Requirement: Scrollback
The terminal SHALL retain a scrollback buffer the user can scroll through.

#### Scenario: Scroll back through history
- **WHEN** output has scrolled past the top of the visible area and the user scrolls up
- **THEN** previously emitted lines are visible

### Requirement: Full color rendering
The terminal SHALL render 8/16 ANSI colors, the 256-color palette, and 24-bit
truecolor, and SHALL advertise truecolor support to programs by setting
`COLORTERM=truecolor` in the shell environment.

#### Scenario: Truecolor output is exact
- **WHEN** a program emits a 24-bit color escape (e.g. `ESC[38;2;R;G;Bm`)
- **THEN** the terminal displays that exact RGB color, not a palette approximation

#### Scenario: COLORTERM advertised
- **WHEN** a program checks the environment for color capability
- **THEN** `COLORTERM` is `truecolor` (or `24bit`) and `TERM` is `xterm-256color`

#### Scenario: Rich syntax highlighting renders
- **WHEN** a tool prints syntax-highlighted code or a colored diff (e.g. `bat`, `git diff --color`)
- **THEN** foreground/background colors, bold, italic, underline, and dim attributes render correctly

### Requirement: Terminal color scheme
The terminal SHALL support a selectable 16-color ANSI palette with two options,
defaulting to a vibrant **Liquid Glass** palette; **System** SHALL install a
standard xterm palette. The scheme sets only how ANSI colors *look* — it does not
enable or disable coloring itself, so programs that emit color (e.g. `ls --color`,
`git`) still render in color under either scheme. Switching schemes SHALL take
effect immediately (each fully replaces the installed palette, so switching back
from Liquid Glass reverts to the standard colors). The cursor SHALL use the theme
accent color. The choice SHALL persist.

#### Scenario: Liquid Glass palette applied
- **WHEN** the Liquid Glass scheme is selected
- **THEN** programs' ANSI colors render with the vibrant palette and the cursor uses the accent color

#### Scenario: Switch to System reverts the palette
- **WHEN** the user selects the System scheme after Liquid Glass
- **THEN** the terminal installs the standard xterm palette (default-looking colors), not the vibrant one — programs that colorize still show color, in the standard palette

### Requirement: Modern TUI compatibility
The terminal SHALL support the terminal features that full-screen TUI programs
require: the alternate screen buffer, application cursor keys, mouse event
reporting, bracketed paste mode, focus in/out reporting, and OSC 8 hyperlinks.

#### Scenario: Alternate screen restores on exit
- **WHEN** a full-screen program enters the alternate screen and later exits
- **THEN** the prior shell scrollback and screen contents are restored intact

#### Scenario: Mouse events reach the program
- **WHEN** a TUI program enables mouse reporting and the user clicks or scrolls within it
- **THEN** the program receives the corresponding mouse events

#### Scenario: Bracketed paste
- **WHEN** the user pastes multi-line text into a program that enabled bracketed paste
- **THEN** the paste is delimited with bracketed-paste markers and not executed line-by-line

#### Scenario: Scroll wheel inside the alternate screen
- **WHEN** the user scrolls the mouse wheel while a full-screen program is on the alternate screen
- **THEN** the scroll is delivered to the program (not the scrollback buffer), so it can scroll its own content

### Requirement: Runs modern AI CLI agents
The terminal SHALL run interactive AI coding CLI agents (e.g. Claude Code, Codex
CLI, opencode, aider) with correct color, layout, input, and resize behavior.

#### Scenario: Claude Code renders and responds
- **WHEN** the user runs `claude` in the terminal
- **THEN** its colored interface renders without corruption, keyboard input works, and resizing reflows its layout

#### Scenario: Another agent renders correctly
- **WHEN** the user runs another agent TUI (e.g. `codex`, `opencode`, or `aider`)
- **THEN** its full-screen interface, colors, and spinners/streaming output render correctly and it restores the screen on exit

