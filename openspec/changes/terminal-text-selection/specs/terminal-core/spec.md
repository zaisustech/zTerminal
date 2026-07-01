## MODIFIED Requirements

### Requirement: Copy and paste
The terminal SHALL let the user select text with the mouse and copy it, and SHALL paste clipboard text into the shell. Selection SHALL support click-drag for a range, double-click for a word, and triple-click for a line, and SHALL work at the shell prompt. Selected text SHALL be copyable via Cmd+C and the right-click Copy item. When a running program has enabled mouse reporting, holding Option (⌥) while dragging SHALL force local text selection instead of forwarding the mouse events to the program. The terminal view SHALL take focus on click so selection and copy are routed to it.

#### Scenario: Select text with a drag at the prompt
- **WHEN** the user clicks and drags across text at the shell prompt
- **THEN** the dragged-over text is selected (highlighted)

#### Scenario: Word and line selection
- **WHEN** the user double-clicks a word (or triple-clicks a line)
- **THEN** that word (or line) is selected

#### Scenario: Copy selected text
- **WHEN** the user selects terminal text and copies (Cmd+C or the right-click Copy item)
- **THEN** the selected text is placed on the system clipboard

#### Scenario: Paste text
- **WHEN** the user pastes (Cmd+V)
- **THEN** the clipboard text is sent to the shell as input

#### Scenario: Select over a program that enabled mouse reporting
- **WHEN** a program has enabled mouse reporting and the user Option-drags across text
- **THEN** the text is selected locally instead of the drag being sent to the program
