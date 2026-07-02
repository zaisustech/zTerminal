## ADDED Requirements

### Requirement: Open a sticky find bar with ⌘F
The terminal SHALL provide a find bar opened with **⌘F** for the active session, presenting
a search field, the search-option toggles, a live match counter, next/previous controls, and
a close control. The bar SHALL remain visible and anchored (sticky) while the buffer scrolls.
Pressing **Esc** SHALL close the bar and clear all search highlighting.

The find bar SHALL also be openable from an **Edit ▸ Search** menu item (⌘F) and from a
**search button in the bottom toolbar** (a configurable toolbar item), both targeting the
active terminal session.

#### Scenario: Open the find bar
- **WHEN** the user presses ⌘F in a terminal pane
- **THEN** a find bar appears, anchored to the pane and focused for text entry

#### Scenario: Open from the Edit menu
- **WHEN** the user chooses Edit ▸ Search
- **THEN** the find bar opens for the active terminal session (same as ⌘F)

#### Scenario: Open from the toolbar button
- **WHEN** the user clicks the search (magnifying-glass) button in the bottom toolbar
- **THEN** the find bar opens for the active terminal session

#### Scenario: Bar stays put while scrolling
- **WHEN** the find bar is open and the user scrolls the buffer
- **THEN** the bar remains visible and anchored rather than scrolling away with the content

#### Scenario: Close the find bar
- **WHEN** the user presses Esc while the find bar is open
- **THEN** the bar closes and all search highlights are cleared

### Requirement: Real-time debounced search over the full scrollback
The find bar SHALL search the entire buffer — the visible grid and the scrollback, not only
the on-screen rows — and SHALL update matches in real time as the user types, debounced by
50–100 ms so typing stays responsive on large buffers. Matches SHALL recompute when new
output arrives while the bar is open.

#### Scenario: Match found in scrollback
- **WHEN** the user types a query that occurs on a line that has scrolled above the visible area
- **THEN** the match is found and reported without the user having to scroll to it first

#### Scenario: Results update while typing
- **WHEN** the user is typing a query
- **THEN** matches and the counter update within a debounce window as each character is entered, without stalling input

#### Scenario: Counter updates with new output
- **WHEN** new output arrives that contains the query while the bar is open
- **THEN** the total match count updates to include the new match

### Requirement: Highlight all matches with a distinct active-match color
The find bar SHALL highlight **every** occurrence of the query in the buffer and SHALL render
the current/active match in a **distinct color** from the other matches. It SHALL display a
current-match counter in the form `Current: n / total` (e.g. `4 / 15`). When there are no
matches, no highlights SHALL be shown and the counter SHALL indicate zero matches.

#### Scenario: All matches highlighted
- **WHEN** a query matches multiple lines in view and in scrollback
- **THEN** every occurrence is highlighted, and the active occurrence is shown in a different color from the rest

#### Scenario: Counter reflects position and total
- **WHEN** matches exist and the active match changes
- **THEN** the counter shows the active match's 1-based index and the total (e.g. `4 / 15`)

#### Scenario: No matches
- **WHEN** the query occurs nowhere in the buffer
- **THEN** no highlights are shown and the counter indicates zero matches

### Requirement: Navigate between matches by keyboard
The find bar SHALL move to the next match on **Return** and **F3**, and to the previous match
on **Shift+Return** and **Shift+F3**, wrapping around at the ends. **↑ / ↓** SHALL also move
to the previous / next match. Each move SHALL update the active-match highlight and counter
and SHALL scroll the active match into view.

#### Scenario: Jump to next and previous
- **WHEN** the user presses Return (then Shift+Return) with multiple matches present
- **THEN** the active match advances to the next match (then returns to the previous one), the view scrolls to it, and the counter reflects the new index

#### Scenario: F3 mirrors Return
- **WHEN** the user presses F3 / Shift+F3
- **THEN** the active match advances / retreats exactly as with Return / Shift+Return

#### Scenario: Wrap around
- **WHEN** the active match is the last one and the user presses Return
- **THEN** the active match wraps to the first match

#### Scenario: Auto-scroll to active match
- **WHEN** the active match is outside the visible area
- **THEN** the view scrolls so the active match is visible

### Requirement: Case, regex, and whole-word options
Search SHALL default to case-insensitive substring matching and SHALL offer three toggles:
**case-sensitive**, **regular-expression**, and **whole-word**. An invalid regular expression
SHALL be handled without error by reporting an invalid / zero-match state, clearing highlights,
and leaving the buffer view unchanged.

#### Scenario: Case-sensitive toggle
- **WHEN** the user enables the case-sensitive toggle and searches for `Error`
- **THEN** only exact-case `Error` occurrences match, not `error`

#### Scenario: Whole-word toggle
- **WHEN** the user enables the whole-word toggle and searches for `err`
- **THEN** `err` matches only as a standalone word, not inside `error` or `stderr`

#### Scenario: Regex search
- **WHEN** the user enables the regex toggle and searches for `err(or|no)`
- **THEN** substrings matching the pattern are treated as matches

#### Scenario: Invalid regex is safe
- **WHEN** the regex toggle is on and the query is not a valid expression
- **THEN** the field indicates an invalid / zero-match state, highlights are cleared, and the buffer view is unchanged

### Requirement: Multi-keyword search with per-keyword colors
When regex is off, the find bar SHALL treat a space-separated query as multiple independent
keywords, SHALL highlight each keyword in a **different color**, and SHALL make the match
counter and next/previous navigation span the union of all keywords' matches in buffer order.
When regex is on, the query SHALL be treated as a single pattern (spaces literal).

#### Scenario: Each keyword gets its own color
- **WHEN** the user searches `database error timeout` with regex off
- **THEN** occurrences of `database`, `error`, and `timeout` are each highlighted in a distinct color

#### Scenario: Navigation spans all keywords
- **WHEN** multiple keywords match across the buffer and the user presses Return repeatedly
- **THEN** navigation steps through every keyword's matches in buffer order and the counter totals them all

#### Scenario: Regex query keeps spaces literal
- **WHEN** the regex toggle is on and the query contains a space
- **THEN** the query is compiled as one pattern and the space is matched literally, not split into keywords

### Requirement: Search history
The find bar SHALL remember recent committed search queries (most-recent-first, de-duplicated,
capped) across sessions and SHALL let the user re-use a previous query from the bar.

#### Scenario: Recent query is remembered
- **WHEN** the user runs a search and later reopens the find bar
- **THEN** the previously searched term is available to re-select from the search history

#### Scenario: History de-duplicates and caps
- **WHEN** the user searches the same term again, or exceeds the history cap
- **THEN** the term moves to the most-recent position without duplication, and the oldest entries are dropped beyond the cap

### Requirement: Scrollbar minimap match markers
The find bar SHALL display markers along the scrollbar (a minimap gutter) indicating where
matches occur in the buffer, SHALL emphasize the active match's marker, and SHALL scroll to a
match when its marker is clicked.

#### Scenario: Markers show match locations
- **WHEN** a query has matches spread through the scrollback
- **THEN** markers appear along the scrollbar at positions proportional to where the matches occur

#### Scenario: Click a marker to jump
- **WHEN** the user clicks a marker
- **THEN** the view scrolls to that location and the nearest match becomes the active match

#### Scenario: Active marker is emphasized
- **WHEN** the active match changes
- **THEN** the marker for the active match is visually emphasized relative to the others

### Requirement: Alternate-screen programs own their own search
The find bar SHALL be unavailable for a pane while a full-screen program has switched that
pane to the alternate screen, and it SHALL become available again when the program exits and
the normal screen is restored.

#### Scenario: Find is unavailable inside a full-screen program
- **WHEN** a program such as `vim` or `less` is on the alternate screen and the user presses ⌘F
- **THEN** the app's find bar does not take over, letting the program handle its own search

#### Scenario: Find returns after the program exits
- **WHEN** the full-screen program exits and the shell prompt returns
- **THEN** ⌘F opens the find bar over the restored scrollback

### Requirement: Per-tab search state
Each tab SHALL retain its own find state — query, options, and active match — so that
switching tabs preserves each tab's search independently.

#### Scenario: Search state is preserved per tab
- **WHEN** the user runs a search in tab A, switches to tab B, and returns to tab A
- **THEN** tab A's query, options, and active match are still in effect
