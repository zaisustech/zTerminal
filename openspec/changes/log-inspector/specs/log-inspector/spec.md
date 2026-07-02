## ADDED Requirements

### Requirement: Filter mode toggle
The find bar SHALL provide a **Filter** toggle that switches between highlight mode (matches
highlighted in place) and **filter mode** (only matching lines shown in a panel). The toggle
SHALL share the same query, options, and match index as highlight mode — switching modes
SHALL NOT require re-typing or re-running the search. Turning filter mode off SHALL restore
the normal terminal view.

#### Scenario: Enter filter mode
- **WHEN** the user has a query and enables the Filter toggle
- **THEN** a filter panel appears over the terminal showing only the lines that match, and the in-place highlighting is replaced by the panel

#### Scenario: Leave filter mode
- **WHEN** the user disables the Filter toggle
- **THEN** the panel closes and the normal terminal view (with highlight-mode behavior) is restored, with no change to buffer contents

#### Scenario: Mode switch preserves the query
- **WHEN** the user toggles between highlight and filter mode
- **THEN** the current query, options, and active match are retained across the switch

### Requirement: Show only matching lines with original line numbers
In filter mode the panel SHALL list every line whose text matches the query — and only those
lines — each showing its **original line number** and the matched text highlighted. When the
query is cleared the panel SHALL show the full set of lines (subject to any active severity
chip). Filtering SHALL be a read-only projection and SHALL NOT modify or discard buffer
contents.

#### Scenario: Filter collapses to matching lines
- **WHEN** the user enters `database` in filter mode over a buffer containing many lines
- **THEN** only the lines containing `database` are listed, each labeled with its original line number, with the match highlighted

#### Scenario: Original line numbers preserved
- **WHEN** matching lines are non-contiguous in the buffer (e.g. lines 120 and 340)
- **THEN** the panel shows those original line numbers, not renumbered 1..N

#### Scenario: Clearing the query restores full output
- **WHEN** the user clears the query in filter mode
- **THEN** the panel shows all lines again (or all lines of the active severity), and disabling filter mode shows the intact terminal

### Requirement: Visible-line count
The panel SHALL display a count of the form **`Showing N of M lines`**, where N is the number
of currently visible (filtered) lines and M is the total number of lines in the buffer
snapshot.

#### Scenario: Count reflects the filter
- **WHEN** a filter reduces 18,532 buffer lines to 12 matching lines
- **THEN** the panel shows `Showing 12 of 18,532 lines`

### Requirement: Click a filtered line to jump
Clicking a line in the filter panel SHALL scroll the live terminal to that line and make it
the active match, keeping the panel and the terminal in sync.

#### Scenario: Jump to a filtered line
- **WHEN** the user clicks a line in the filter panel
- **THEN** the live terminal scrolls so that line is visible and it becomes the active match

### Requirement: Severity chips
The panel SHALL provide quick severity chips — **All, Error, Warning, Info, Debug, Trace** —
that further filter the visible lines by a log level auto-detected from each line's text.
Selecting **All** SHALL apply no level filter. A specific chip SHALL show only lines detected
as that level. Chips SHALL compose with the text query (both must match).

#### Scenario: Filter by severity
- **WHEN** the user selects the **Error** chip
- **THEN** only lines detected as error-level are shown (intersected with any active text query)

#### Scenario: All chip clears the level filter
- **WHEN** the user selects the **All** chip
- **THEN** no level filter is applied and lines of every severity are eligible

#### Scenario: Severity detection is best-effort
- **WHEN** a line contains a recognizable level token (e.g. `ERROR`, `[warn]`, `level=info`)
- **THEN** it is classified accordingly; lines with no recognizable token are treated as unclassified and excluded by any specific (non-All) chip

### Requirement: Invert filter
The panel SHALL provide an **Invert** toggle that shows the lines that do **not** match the
text query (a negative filter), while any active severity chip still applies.

#### Scenario: Invert hides matching lines
- **WHEN** the user enters `heartbeat` and enables Invert
- **THEN** the panel shows every line that does NOT contain `heartbeat`

#### Scenario: Invert composes with severity
- **WHEN** Invert is on with a query and the **Error** chip is selected
- **THEN** the panel shows error-level lines that do NOT match the query

### Requirement: Refresh on new output
While filter mode is active and new output arrives, the panel SHALL refresh its snapshot so
newly matching lines appear and the count updates, without the user re-running the filter.

#### Scenario: New matching output appears
- **WHEN** the terminal prints a new line matching the active filter while the panel is open
- **THEN** that line appears in the panel and the `N of M` count updates
