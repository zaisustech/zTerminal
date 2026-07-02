import AppKit
import SwiftUI
import SwiftTerm

/// Per-tab search brain: owns the query + options, drives the pure `TerminalSearch`
/// engine over text extracted from the live buffer, manages the highlight + minimap
/// overlays on the `ZTerminalView`, scrolls the active match into view, and
/// publishes counter/validity state for the SwiftUI find bar. Debounced so typing
/// and streaming output stay responsive on large buffers.
@MainActor
final class SearchController: ObservableObject {

    // Published state for the find bar.
    @Published var isActive = false
    @Published var query = ""
    @Published var options = TerminalSearch.Options()
    @Published private(set) var total = 0
    @Published private(set) var current = 0        // 1-based active position, 0 = none
    @Published private(set) var isValidRegex = true

    // Filter mode (Chrome-DevTools-style): show only matching lines in a panel.
    @Published var filterMode = false
    @Published var severityFilter: LogSeverity? = nil   // nil = All
    @Published var invert = false
    /// Bumped whenever the snapshot is rebuilt, so the filter panel re-renders on
    /// new output even when the query/options are unchanged.
    @Published private(set) var filterRevision = 0

    /// One line in the filter panel: its original buffer-line index, text, and
    /// detected severity.
    struct FilterLine: Identifiable {
        let id: Int          // buffer-line index (stable within a snapshot)
        let text: String
        let severity: LogSeverity
    }

    /// Snapshot of every buffer row (text + severity), rebuilt on extract / new
    /// output so chip toggles and panel scrolling re-filter instantly. Severity
    /// is classified lazily (regex per line) — only when filter mode needs it.
    private var snapshot: [(text: String, severity: LogSeverity)] = []

    /// Incremental-extraction cache: scrollback rows are immutable once they
    /// scroll off screen, so only the on-screen tail (plus appended rows) needs
    /// re-translation on refresh. `cachedFirstLine` detects scrollback trimming
    /// (indices shift when the cap evicts old rows) and forces a full rebuild.
    private var cachedLines: [String] = []
    private var cachedFirstLine: String?

    /// Recent terms for the history menu (snapshot of the shared store).
    var history: [String] { SearchHistory.shared.terms }

    private var engine = TerminalSearch()
    private weak var term: ZTerminalView?
    private var highlight: SearchHighlightOverlay?
    private var minimap: SearchMinimapView?
    private var debounce: DispatchWorkItem?
    private var keyMonitor: Any?

    private let debounceInterval: TimeInterval = 0.07   // 70 ms (spec: 50–100 ms)

    /// Nonisolated so `SessionModel` (not main-actor-isolated) can own one as a
    /// stored property; all mutating work still runs on the main actor.
    nonisolated init() {}

    // MARK: Attach

    /// Bind to the session's terminal view once it exists (called from the host view).
    func attach(to term: ZTerminalView) {
        self.term = term
        term.onBufferChanged = { [weak self] in self?.scheduleRefresh() }
        term.onScroll = { [weak self] in self?.redrawOverlays() }
    }

    // MARK: Open / close

    /// ⌘F — open the find bar (or just refocus it if already open).
    func open() {
        // Search is meaningless while a full-screen program owns the alt screen.
        if term?.getTerminal().isCurrentBufferAlternate == true { return }
        isActive = true
        installOverlays()
        installKeyMonitor()
        refresh(immediate: true)
    }

    /// Esc / close button — tear down highlights and state (keeps the query text so
    /// reopening is fast; clears the visible highlighting).
    func close() {
        commitHistory()
        isActive = false
        debounce?.cancel()
        removeKeyMonitor()
        removeOverlays()
        engine.clear()
        total = 0; current = 0; isValidRegex = true
        filterMode = false; severityFilter = nil; invert = false; snapshot = []
        cachedLines = []; cachedFirstLine = nil
    }

    /// Called when the pane switches to/from the alternate screen: hide the bar
    /// while a full-screen program owns the screen.
    func handleBufferSwitch() {
        if isActive, term?.getTerminal().isCurrentBufferAlternate == true {
            close()
        }
    }

    // MARK: Query / options

    func setQuery(_ q: String) {
        query = q
        scheduleRefresh()
    }

    func setOptions(_ o: TerminalSearch.Options) {
        options = o
        refresh(immediate: true)
    }

    // MARK: Navigation

    func next()     { engine.next();     afterNavigation() }
    func previous() { engine.previous(); afterNavigation() }

    private func afterNavigation() {
        publishCounters()
        scrollToActive()
        redrawOverlays()
    }

    // MARK: Refresh pipeline

    private func scheduleRefresh() {
        // Buffer-change callbacks fire for every output chunk of every tab —
        // schedule nothing while the find bar is closed (perf: this was dead
        // WorkItem churn during streaming output).
        guard isActive else { return }
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh(immediate: false) }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Re-extract the buffer, recompute matches, update counters + overlays. When
    /// `immediate`, also scroll the (new) active match into view.
    private func refresh(immediate: Bool) {
        guard isActive, let term else { return }
        let t = term.getTerminal()
        guard !t.isCurrentBufferAlternate else { close(); return }

        let lines = extractLines(from: t)
        // Keep the filter snapshot current so chip toggles / panel scrolling
        // don't re-extract. Severity regexes only run in filter mode.
        snapshot = filterMode
            ? lines.map { ($0, LogSeverity.classify($0)) }
            : lines.map { ($0, .none) }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            engine.clear()
        } else {
            // Anchor a fresh active match near the current viewport top.
            engine.recompute(query: query, options: options, lines: lines,
                             preferActiveNear: (line: t.getTopVisibleRow(), col: 0))
        }
        publishCounters()
        redrawOverlays()
        filterRevision &+= 1        // nudge the filter panel to re-render
        if immediate && !trimmed.isEmpty && !filterMode { scrollToActive() }
    }

    /// Plain text of every buffer row (scrollback + on-screen), indexed to match the
    /// `getTopVisibleRow()` coordinate space. Per grid row (not logical line):
    /// `BufferLine.isWrapped` isn't public, and per-row keeps overlay rects exact.
    ///
    /// Incremental: only the mutable tail (the on-screen rows plus anything
    /// appended since last extraction) is re-translated; immutable scrollback
    /// rows come from the cache. Falls back to a full rebuild when the
    /// scrollback cap trims old rows (detected by the first line changing) or
    /// the buffer shrank (clear / buffer switch).
    private func extractLines(from t: Terminal) -> [String] {
        let count = t.bufferLineCount
        let rows = t.rows
        let firstNow = t.bufferLine(atIndex: 0)?.translateToString(trimRight: true) ?? ""

        let reusable = min(cachedLines.count, count) - rows   // frozen scrollback prefix
        if reusable > 0, firstNow == cachedFirstLine, count >= cachedLines.count {
            var lines = Array(cachedLines.prefix(reusable))
            lines.reserveCapacity(count)
            for i in reusable ..< count {
                lines.append(t.bufferLine(atIndex: i)?.translateToString(trimRight: true) ?? "")
            }
            cachedLines = lines
            return lines
        }

        var lines: [String] = []
        lines.reserveCapacity(count)
        for i in 0 ..< count {
            lines.append(t.bufferLine(atIndex: i)?.translateToString(trimRight: true) ?? "")
        }
        cachedLines = lines
        cachedFirstLine = firstNow
        return lines
    }

    private func publishCounters() {
        total = engine.total
        current = engine.currentPosition
        isValidRegex = engine.isValid
    }

    // MARK: Overlays

    private func installOverlays() {
        guard let term, highlight == nil else { return }
        let hl = SearchHighlightOverlay(frame: term.bounds)
        hl.term = term
        hl.autoresizingMask = [.width, .height]
        term.addSubview(hl)
        highlight = hl

        let mm = SearchMinimapView(frame: NSRect(x: term.bounds.width - SearchMinimapView.width, y: 0,
                                                 width: SearchMinimapView.width, height: term.bounds.height))
        mm.term = term
        mm.autoresizingMask = [.minXMargin, .height]
        mm.onJump = { [weak self] index in self?.jump(toBufferIndex: index) }
        term.addSubview(mm)
        minimap = mm
    }

    private func removeOverlays() {
        highlight?.removeFromSuperview(); highlight = nil
        minimap?.removeFromSuperview(); minimap = nil
    }

    private func redrawOverlays() {
        // In filter mode the panel replaces in-place highlighting, so clear the
        // overlay/minimap; otherwise draw all matches with the active one emphasized.
        guard !filterMode else { highlight?.matches = []; minimap?.matches = []; return }
        let overlayMatches = engine.matches.enumerated().map { idx, m in
            OverlayMatch(bufferIndex: m.line, colStart: m.range.lowerBound, colEnd: m.range.upperBound,
                         keyword: m.keyword, isActive: idx == engine.activeIndex)
        }
        highlight?.matches = overlayMatches
        minimap?.matches = overlayMatches
    }

    // MARK: Filter mode (log-inspector)

    /// The set of buffer-line indices that contain at least one text match.
    private var matchedLineSet: Set<Int> { Set(engine.matches.map(\.line)) }

    /// Total lines in the current snapshot (the `M` in `Showing N of M lines`).
    var totalCount: Int { snapshot.count }

    /// The lines to show in the filter panel: text predicate (query match, or its
    /// negation when inverted; vacuously true for an empty query) AND severity chip.
    func filteredLines() -> [FilterLine] {
        let hasQuery = !query.trimmingCharacters(in: .whitespaces).isEmpty
        return Self.select(snapshot: snapshot, matched: matchedLineSet,
                           hasQuery: hasQuery, invert: invert, severity: severityFilter)
    }

    /// Pure selection used by `filteredLines()` — extracted so it can be unit-tested
    /// without a live terminal.
    nonisolated static func select(snapshot: [(text: String, severity: LogSeverity)],
                                   matched: Set<Int>, hasQuery: Bool, invert: Bool,
                                   severity: LogSeverity?) -> [FilterLine] {
        var out: [FilterLine] = []
        for (i, row) in snapshot.enumerated() {
            let textOK = hasQuery ? (invert ? !matched.contains(i) : matched.contains(i)) : true
            guard textOK else { continue }
            if let sev = severity, row.severity != sev { continue }
            out.append(FilterLine(id: i, text: row.text, severity: row.severity))
        }
        return out
    }

    /// Highlight ranges (column pairs) for a given line, for the panel to draw.
    func matchRanges(forLine line: Int) -> [Range<Int>] {
        engine.matches.filter { $0.line == line }.map(\.range)
    }

    func toggleFilterMode() {
        filterMode.toggle()
        redrawOverlays()
        refresh(immediate: true)
    }

    func setSeverity(_ s: LogSeverity?) { severityFilter = s; filterRevision &+= 1 }
    func toggleInvert() { invert.toggle(); filterRevision &+= 1 }

    /// Jump the live terminal to a filtered line (click-to-jump from the panel).
    func jumpToLine(_ index: Int) {
        engine.activateNearest(line: index, col: 0)
        publishCounters()
        scrollToLine(index)
    }

    private func scrollToLine(_ index: Int) {
        guard let term else { return }
        let t = term.getTerminal()
        let rows = t.rows
        let maxTop = max(0, t.bufferLineCount - rows)
        term.scrollTo(row: min(max(0, index - rows / 2), maxTop))
        redrawOverlays()
    }

    // MARK: Scrolling

    private func scrollToActive() {
        guard let term, let m = engine.activeMatch else { return }
        let t = term.getTerminal()
        let rows = t.rows
        let topVisible = t.getTopVisibleRow()
        if m.line >= topVisible && m.line < topVisible + rows { return }   // already visible
        let maxTop = max(0, t.bufferLineCount - rows)
        let target = min(max(0, m.line - rows / 2), maxTop)
        term.scrollTo(row: target)
        redrawOverlays()
    }

    private func jump(toBufferIndex index: Int) {
        engine.activateNearest(line: index, col: 0)
        afterNavigation()
    }

    // MARK: History

    private func commitHistory() {
        SearchHistory.shared.record(query)
    }

    func useHistory(_ term: String) {
        query = term
        refresh(immediate: true)
    }

    // MARK: Key monitor (F3 / Shift+F3 while the bar is open, regardless of focus)

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isActive else { return event }
            if event.keyCode == 99 {                    // 99 = F3
                if event.modifierFlags.contains(.shift) { self.previous() } else { self.next() }
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }
}
