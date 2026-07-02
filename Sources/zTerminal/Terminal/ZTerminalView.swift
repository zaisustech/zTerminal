import AppKit
import SwiftTerm
import Quartz

/// `LocalProcessTerminalView` plus: copy-on-select, a right-click context menu,
/// a Clear (Cmd+K) action, and Quick Look of the selected path.
final class ZTerminalView: LocalProcessTerminalView {

    // Don't let dragging inside the terminal move the (frameless) window — that
    // would hijack text selection. The chrome (tab bar/toolbar) stays draggable.
    override var mouseDownCanMoveWindow: Bool { false }

    /// Called when the folder should be revealed (wired by the host view).
    var onReveal: (() -> Void)?

    /// Provides the session's CWD so relative paths in the selection can resolve.
    var currentDirectory: (() -> String)?

    private var quickLookURL: URL?

    /// Called when folders are dropped while the Command key is held — the host
    /// opens a new tab at the (first) folder instead of inserting the path.
    var onOpenFolders: (([URL]) -> Void)?

    /// Called when Markdown files are dropped (no Command key) — the host opens
    /// them in the preview instead of inserting shell paths.
    var onOpenMarkdown: (([URL]) -> Void)?

    /// Called when the terminal bell rings (a program wants attention).
    var onBell: (() -> Void)?

    /// Called when buffer content changes (new output / buffer switch) — the search
    /// controller re-extracts and re-indexes matches.
    var onBufferChanged: (() -> Void)?

    /// Called when the view scrolls — the search overlay re-projects match rects
    /// for the new visible window (no re-index needed).
    var onScroll: (() -> Void)?

    /// Called on ⌘-click with the whitespace-delimited token under the pointer and
    /// the session CWD, so the host can resolve + open it in an editor.
    var onCommandClickToken: ((_ token: String, _ cwd: String) -> Void)?

    /// The whitespace-delimited token under a point in the terminal, or nil.
    /// Maps the point to a cell via `cellSize`, reads that row's text, and expands
    /// left/right over non-space characters.
    func tokenAt(point: NSPoint) -> String? {
        let cell = cellSize
        guard cell.width > 0, cell.height > 0 else { return nil }
        let t = getTerminal()
        let col = Int(point.x / cell.width)
        let visibleRow = Int((bounds.height - point.y) / cell.height)
        guard visibleRow >= 0, visibleRow < t.rows,
              let line = t.getLine(row: visibleRow) else { return nil }
        let chars = Array(line.translateToString(trimRight: true))
        guard col >= 0, col < chars.count else { return nil }
        let separators: Set<Character> = [" ", "\t", "\u{0}", "\"", "'", "(", ")", "[", "]", "<", ">", "|"]
        guard !separators.contains(chars[col]) else { return nil }
        var lo = col, hi = col
        while lo > 0, !separators.contains(chars[lo - 1]) { lo -= 1 }
        while hi < chars.count - 1, !separators.contains(chars[hi + 1]) { hi += 1 }
        let token = String(chars[lo...hi]).trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }

    // MARK: Inline ghost autosuggestion

    /// Produces the dim suffix to show at the cursor (set by the host view).
    var suggestionEngine: SuggestionEngine?

    /// True when the shell (not a program) owns the tty — a suggestion is only
    /// trustworthy at an idle prompt (wired to `SessionModel.isIdleAtPrompt`).
    var isIdleAtPrompt: (() -> Bool)?

    /// Prompt-end position recorded from OSC 133;B: the column where input begins
    /// and the absolute scrollback row it is on. Nil until the first marker.
    private var promptCol: Int?
    private var promptAbsRow: Int?

    /// The suffix currently drawn (what Tab would accept); nil when hidden.
    private var currentSuffix: String?
    private var keyMonitor: Any?

    private lazy var ghostView: GhostTextView = {
        let v = GhostTextView(frame: .zero)
        v.isHidden = true
        addSubview(v)
        return v
    }()

    // MARK: Bell → attention
    override func bell(source: Terminal) {
        super.bell(source: source)   // keep default bell behavior
        onBell?()
    }

    // MARK: Text selection over mouse-reporting programs

    /// SwiftTerm forwards drags to the running program (and skips text selection)
    /// whenever that program has enabled mouse reporting — with no built-in bypass,
    /// and its `mouseDown`/`mouseUp` are not open for overriding. So we watch mouse
    /// events with a local monitor (which fires *before* the view handles them) and,
    /// while Option (⌥) is held over this terminal, temporarily disable mouse
    /// reporting so the built-in local text selection runs. Matches Terminal.app /
    /// iTerm2; the prior setting is restored on mouse-up.
    private var savedMouseReporting: Bool?
    private var mouseMonitor: Any?

    /// Install the Option-drag selection monitor. Called once from the host view.
    func installSelectionMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self, self.eventTargetsSelf(event) else { return event }
            if event.type == .leftMouseDown {
                // ⌘-click a file path → hand the token to the editor launcher.
                if event.modifierFlags.contains(.command),
                   let handler = self.onCommandClickToken,
                   let token = self.tokenAt(point: self.convert(event.locationInWindow, from: nil)) {
                    handler(token, self.currentDirectory?() ?? NSHomeDirectory())
                    return nil   // consume — don't start a selection
                }
                self.window?.makeFirstResponder(self)   // route selection + ⌘C here
                if event.modifierFlags.contains(.option) {
                    self.savedMouseReporting = self.allowMouseReporting
                    self.allowMouseReporting = false
                }
            } else if let saved = self.savedMouseReporting {   // leftMouseUp
                self.allowMouseReporting = saved
                self.savedMouseReporting = nil
            }
            return event
        }
    }

    /// True when a mouse event lands inside this terminal's window and bounds.
    private func eventTargetsSelf(_ event: NSEvent) -> Bool {
        guard let win = window, event.window === win else { return false }
        let p = convert(event.locationInWindow, from: nil)
        return bounds.contains(p)
    }

    // MARK: Ghost autosuggestion — prompt tracking, rendering, Tab accept

    /// OSC 133;B — snapshot the prompt-end position synchronously so we know where
    /// the user's input begins on the current line.
    func notePromptEnd() {
        let t = getTerminal()
        let loc = t.getCursorLocation()
        promptCol = loc.x
        promptAbsRow = loc.y + t.buffer.yDisp
        scheduleGhostRefresh()
    }

    /// Recompute the ghost from the live buffer and reposition it, or hide it when
    /// a suggestion can't be trusted (busy shell, alternate screen, or an input
    /// line we can't resolve). Genuinely coalesced: `rangeChanged` fires for every
    /// output chunk, so at most ONE refresh is in flight per runloop turn (perf:
    /// this used to enqueue unboundedly during streaming output).
    private var ghostRefreshPending = false
    private func scheduleGhostRefresh() {
        guard !ghostRefreshPending else { return }
        ghostRefreshPending = true
        DispatchQueue.main.async { [weak self] in
            self?.ghostRefreshPending = false
            self?.refreshGhost()
        }
    }

    private func refreshGhost() {
        let t = getTerminal()
        guard suggestionEngine != nil,
              (isIdleAtPrompt?() ?? true),
              !t.isCurrentBufferAlternate,
              let pc = promptCol, let pr = promptAbsRow
        else { return hideGhost() }

        let loc = t.getCursorLocation()
        // Only the single prompt row is tracked; a wrapped/moved cursor → hide.
        guard loc.y + t.buffer.yDisp == pr, pc <= loc.x, let line = t.getLine(row: loc.y)
        else { return hideGhost() }

        let input = line.translateToString(trimRight: true, startCol: pc)
        let cwd = currentDirectory?() ?? NSHomeDirectory()
        guard let suffix = suggestionEngine?.suffix(forInput: input, cwd: cwd), !suffix.isEmpty
        else { return hideGhost() }

        let caret = caretFrame
        guard caret.width > 0, caret.height > 0 else { return hideGhost() }
        ghostView.font = font
        ghostView.text = suffix
        ghostView.frame = CGRect(x: caret.minX, y: caret.minY,
                                 width: caret.width * CGFloat(suffix.count), height: caret.height)
        ghostView.isHidden = false
        currentSuffix = suffix
    }

    private func hideGhost() {
        currentSuffix = nil
        if !ghostView.isHidden { ghostView.isHidden = true }
    }

    /// Intercept Tab to accept a visible suggestion. `keyDown`/`doCommand` are
    /// sealed in SwiftTerm, so — like the Option-drag selection monitor — we watch
    /// key events with a local monitor. Tab is consumed *only* when this view is
    /// focused, the shell is idle, and a ghost is shown; otherwise it passes through
    /// so the shell's native completion is never lost.
    func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window != nil, self.window === event.window,
                  self.window?.firstResponder === self else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 48, mods.isEmpty {   // 48 = Tab
                if let suffix = self.currentSuffix, !suffix.isEmpty, (self.isIdleAtPrompt?() ?? true) {
                    self.send(txt: suffix)
                    self.hideGhost()
                    return nil   // consume — don't also forward Tab to the shell
                }
                return event     // no ghost → shell's own completion
            }
            // Cursor-navigation keys move the caret without a content change, so the
            // ghost would be stale/mispositioned — hide it; it returns on next edit.
            let navKeys: Set<UInt16> = [123, 124, 125, 126, 115, 116, 119, 121]
            if navKeys.contains(event.keyCode) { self.hideGhost() }
            return event
        }
    }

    // Reposition/recompute the ghost as terminal content changes. These SwiftTerm
    // delegate methods are `open`; the low-level display hooks are not.
    override func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        super.rangeChanged(source: source, startY: startY, endY: endY)
        scheduleGhostRefresh()
        onBufferChanged?()
    }

    override func scrolled(source: TerminalView, position: Double) {
        super.scrolled(source: source, position: position)
        scheduleGhostRefresh()
        onScroll?()
    }

    override func bufferActivated(source: Terminal) {
        super.bufferActivated(source: source)
        scheduleGhostRefresh()
        onBufferChanged?()
    }

    deinit {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: Drag & drop (Finder files/folders -> shell-escaped paths)

    func registerDrag() {
        registerForDraggedTypes([.fileURL, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let cmdHeld = NSEvent.modifierFlags.contains(.command)
            let folders = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            let markdown = urls.filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
            if cmdHeld, !folders.isEmpty {
                // Cmd+drop a folder -> open a new tab there.
                onOpenFolders?(folders)
            } else if !cmdHeld, markdown.count == urls.count, let open = onOpenMarkdown {
                // Markdown files -> preview. Cmd+drop keeps the shell-path
                // insert below for building command lines.
                open(markdown)
            } else {
                // Default: insert shell-escaped path(s) at the cursor, using
                // Terminal.app's backslash style (NOT single quotes) — TUI apps
                // like Claude Code recognize dropped image/file paths in that
                // form and turn them into attachments; a quoted path reads as
                // plain text to them.
                let joined = urls.map { ZTerminalView.shellEscape($0.path) }.joined(separator: " ")
                send(txt: joined + " ")
            }
            return true
        }
        if let s = pb.string(forType: .string) {
            send(txt: s)
            return true
        }
        return false
    }

    /// Single-quote a path for safe shell insertion (handles spaces, unicode,
    /// and embedded single quotes).
    static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Backslash-escape a path the way Terminal.app / iTerm2 do on file drop:
    /// letters, digits, and safe punctuation pass through; everything else
    /// (spaces, quotes, shell metacharacters) is escaped individually. This
    /// form is both valid shell input and recognizable to TUI apps that detect
    /// dropped file paths (e.g. Claude Code's image attachments).
    static func shellEscape(_ path: String) -> String {
        var out = ""
        out.reserveCapacity(path.count)
        for ch in path {
            if ch.isLetter || ch.isNumber || "_-./+".contains(ch) {
                out.append(ch)
            } else {
                out.append("\\")
                out.append(ch)
            }
        }
        return out
    }

    // MARK: Copy-on-select
    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)
        if let text = getSelection(), !text.isEmpty {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
    }

    // MARK: Quick Look (preview the selected file path)

    /// Resolve the current selection to an existing file URL (strips shell quoting,
    /// expands `~`, resolves relative paths against the CWD).
    func selectedFileURL() -> URL? {
        guard var s = getSelection()?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if (s.hasPrefix("'") && s.hasSuffix("'")) || (s.hasPrefix("\"") && s.hasSuffix("\"")), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }
        s = s.replacingOccurrences(of: "'\\''", with: "'")   // undo our shell escaping
        let expanded = (s as NSString).expandingTildeInPath
        let path = expanded.hasPrefix("/")
            ? expanded
            : ((currentDirectory?() ?? NSHomeDirectory()) as NSString).appendingPathComponent(expanded)
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func quickLookSelection() {
        guard let url = selectedFileURL() else { NSSound.beep(); return }
        quickLookURL = url
        if let panel = QLPreviewPanel.shared() {
            panel.makeKeyAndOrderFront(nil)
            panel.reloadData()
        }
    }

    // QLPreviewPanel control (NSResponder chain)
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self; panel.delegate = self
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}

    // MARK: Clear (Cmd+K)
    func clearWindow() {
        feed(text: "\u{1b}[3J")   // erase the scrollback buffer
        send(txt: "\u{0c}")        // Ctrl+L: shell clears the screen and redraws the prompt
    }

    // MARK: Right-click context menu
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let hasSelection = !(getSelection()?.isEmpty ?? true)
        let hasClipboard = NSPasteboard.general.string(forType: .string) != nil

        let copy = NSMenuItem(title: "Copy", action: #selector(zCopy), keyEquivalent: "c")
        copy.target = self; copy.isEnabled = hasSelection
        menu.addItem(copy)

        let paste = NSMenuItem(title: "Paste", action: #selector(zPaste), keyEquivalent: "v")
        paste.target = self; paste.isEnabled = hasClipboard
        menu.addItem(paste)

        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(zSelectAll), keyEquivalent: "a")
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        if selectedFileURL() != nil {
            let ql = NSMenuItem(title: "Quick Look", action: #selector(zQuickLook), keyEquivalent: "y")
            ql.target = self
            menu.addItem(ql)
        }

        menu.addItem(.separator())

        let clear = NSMenuItem(title: "Clear", action: #selector(zClear), keyEquivalent: "k")
        clear.target = self
        menu.addItem(clear)

        if onReveal != nil {
            let reveal = NSMenuItem(title: "Reveal in Finder", action: #selector(zReveal), keyEquivalent: "")
            reveal.target = self
            menu.addItem(reveal)
        }
        return menu
    }

    @objc private func zCopy() { copy(self) }
    @objc private func zPaste() {
        if let s = NSPasteboard.general.string(forType: .string) { send(txt: s) }
    }
    @objc private func zSelectAll() { selectAll(nil) }
    @objc private func zClear() { clearWindow() }
    @objc private func zReveal() { onReveal?() }
    @objc private func zQuickLook() { quickLookSelection() }
}

extension ZTerminalView: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { quickLookURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        quickLookURL as NSURL?
    }
}
