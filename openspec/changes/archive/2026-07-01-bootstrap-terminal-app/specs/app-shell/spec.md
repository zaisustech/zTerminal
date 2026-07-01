## ADDED Requirements

### Requirement: Native macOS application window
The application SHALL launch as a native macOS `.app` bundle presenting a
resizable window that hosts the active terminal surface and, docked to the window
bottom, a directory toolbar for that terminal.

#### Scenario: Launch shows a terminal window
- **WHEN** the user opens the app
- **THEN** a window appears containing a live terminal surface and a toolbar along its bottom edge

#### Scenario: Window is resizable
- **WHEN** the user drags the window edge to resize it
- **THEN** the terminal surface reflows to the new size and the toolbar remains docked at the bottom

### Requirement: Top tab bar with multiple terminal tabs
The application SHALL present multiple terminal tabs in a **tab bar across the top
of the window** (native-terminal style). Each tab SHALL own an independent
terminal session (its own shell, PTY, CWD, start time, and duration timer). The
tab bar SHALL show each tab's title and mark the active tab, and selecting a tab
SHALL switch the displayed terminal and toolbar to that session. The user SHALL be
able to open many tabs, including **multiple tabs in the same directory**.

#### Scenario: Tabs appear in a top tab bar
- **WHEN** more than one tab is open
- **THEN** a tab bar is shown across the top of the window with one selectable entry per session, the active one visually distinct

#### Scenario: New tab inherits the current directory
- **WHEN** the user opens a new tab (e.g. Cmd+T) from a tab whose CWD is some directory
- **THEN** the new tab's shell starts in that same directory (inheriting the active tab's CWD), so multiple tabs can run in the same folder

#### Scenario: Multiple tabs in one directory are independent
- **WHEN** two tabs are open in the same directory and a program runs in one
- **THEN** the other tab is unaffected and keeps its own shell, prompt, start time, and timer

#### Scenario: Switch tabs
- **WHEN** the user selects a different tab (click or Cmd+1..9 / Cmd+Shift+[ ])
- **THEN** the displayed terminal and its toolbar (CWD, start time, duration) switch to that tab's session

#### Scenario: Reorder and title
- **WHEN** the user drags a tab in the tab bar
- **THEN** the tab order updates; each tab's title reflects its running program or directory

#### Scenario: Double-click to rename
- **WHEN** the user double-clicks a tab and types a name
- **THEN** the tab shows that custom name, it persists across `cd`/program changes, and pressing Esc or clearing it reverts to the automatic title

#### Scenario: Close a tab
- **WHEN** the user closes a tab (e.g. Cmd+W or its close control)
- **THEN** that tab's shell and PTY are terminated, the tab is removed, and closing the last tab closes the window

### Requirement: iTerm-like appearance
The application SHALL render the terminal with a monospaced font that includes
Nerd/powerline glyphs and a dark color theme, and SHALL apply ANSI/xterm
256-color and truecolor output emitted by programs. The application SHALL use a
font-fallback chain so glyphs absent from the primary font — notably color
emoji — still render via a fallback font (e.g. Apple Color Emoji).

#### Scenario: Colored output renders
- **WHEN** a program emits ANSI color escape sequences
- **THEN** the terminal displays the corresponding foreground and background colors

#### Scenario: Glyphs and wide characters render
- **WHEN** output contains powerline separators, Nerd Font icons, emoji, or CJK/wide characters
- **THEN** they render at the correct width without overlap or clipping

#### Scenario: Color emoji fall back to a color font
- **WHEN** output contains an emoji not present in the primary monospaced font
- **THEN** the emoji renders in color via the fallback font at the correct cell width

#### Scenario: Configurable font size
- **WHEN** the user changes the font size (e.g. Cmd+Plus / Cmd+Minus)
- **THEN** the terminal re-renders text at the new size and reflows the grid

### Requirement: Application menu and lifecycle
The application SHALL provide a standard macOS menu bar (app, Edit, View, Window)
and SHALL terminate cleanly, tearing down the shell process.

#### Scenario: Quit terminates the shell
- **WHEN** the user quits the app
- **THEN** the underlying shell processes and PTYs are terminated and no orphan process remains

### Requirement: Shell-exit handling
When a tab's shell process exits, the application SHALL keep the tab open,
display a clear "[process completed]" indicator, and stop that session's duration
timer, without terminating the app or other tabs. The user SHALL be able to close
or restart the session.

#### Scenario: Shell exits normally
- **WHEN** the user runs `exit` (or the shell terminates) in a tab
- **THEN** the terminal shows a "[process completed]" indicator and the tab's duration timer stops

#### Scenario: Restart a completed session
- **WHEN** the user chooses to restart a completed session
- **THEN** a new shell is spawned in that tab, starting in the tab's last known working directory, and a fresh start time and timer begin
