# markdown-performance Specification

## ADDED Requirements

### Requirement: Instant rendering of large documents
The preview SHALL render documents of 5,000+ lines with the visible viewport painted within 500ms of load on typical hardware, using incremental/deferred rendering (and virtualized layout if necessary) for off-screen content.

#### Scenario: Large README loads instantly
- **WHEN** a 5,000-line Markdown file is opened
- **THEN** the first screenful is visible within 500ms and scrolling through the document stays smooth (no multi-frame hitches)

### Requirement: Block-level incremental updates
When content changes, the preview SHALL re-render only the changed blocks: unchanged blocks keep their DOM nodes, already-rendered images do not reload, and already-rendered Mermaid diagrams and math do not re-render.

#### Scenario: Single-block edit
- **WHEN** one paragraph changes in a large previewed file
- **THEN** only that paragraph's element is replaced; images and diagrams elsewhere do not flicker or refetch

### Requirement: Flicker-free token streaming
During token-by-token streaming, the preview SHALL update without flashing, without scroll jumps, and while keeping partially complete constructs stable — an unclosed code fence renders as an open code block, and a partially written heading/table renders progressively without corrupting earlier content.

#### Scenario: Streaming heading grows naturally
- **WHEN** the stream appends `## Authent`, then `ication` token-by-token
- **THEN** the heading text grows in place with no flash and no reflow of earlier blocks

#### Scenario: Unclosed fence during streaming
- **WHEN** the stream has emitted ```typescript and several code lines but not the closing fence
- **THEN** the content renders as a highlighted code block that extends as lines arrive

#### Scenario: Reader scroll position respected
- **WHEN** the user has scrolled up to read earlier content while streaming continues below
- **THEN** the viewport does not move; auto-follow to the bottom occurs only when the user is already at the bottom

### Requirement: Bounded update cadence
Streaming updates SHALL be coalesced so the renderer performs at most one render pass per display frame regardless of token arrival rate, keeping the UI responsive.

#### Scenario: High-frequency tokens coalesced
- **WHEN** tokens arrive faster than 60/sec
- **THEN** rendering batches them per frame and input (scrolling, search) remains responsive
