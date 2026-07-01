import AppKit
import SwiftTerm
import Quartz

/// `LocalProcessTerminalView` plus: copy-on-select, a right-click context menu,
/// a Clear (Cmd+K) action, and Quick Look of the selected path.
final class ZTerminalView: LocalProcessTerminalView {

    /// Called when the folder should be revealed (wired by the host view).
    var onReveal: (() -> Void)?

    /// Provides the session's CWD so relative paths in the selection can resolve.
    var currentDirectory: (() -> String)?

    private var quickLookURL: URL?

    /// Called when folders are dropped while the Command key is held — the host
    /// opens a new tab at the (first) folder instead of inserting the path.
    var onOpenFolders: (([URL]) -> Void)?

    /// Called when the terminal bell rings (a program wants attention).
    var onBell: (() -> Void)?

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

    deinit {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
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
            if cmdHeld, !folders.isEmpty {
                // Cmd+drop a folder -> open a new tab there.
                onOpenFolders?(folders)
            } else {
                // Default: insert shell-escaped path(s) at the cursor.
                let joined = urls.map { ZTerminalView.shellQuote($0.path) }.joined(separator: " ")
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
