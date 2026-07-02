import Foundation
import SwiftUI

/// The window's tab set: an ordered list of sessions plus the active one.
/// New tabs inherit the active tab's current directory (Terminal.app-style).
final class WindowModel: ObservableObject {
    @Published var sessions: [SessionModel] = []
    @Published var activeID: UUID? {
        didSet {
            AttentionManager.shared.markActive(active)
            // Only the selected tab runs per-second bookkeeping (perf).
            sessions.forEach { $0.isActiveTab = ($0.id == activeID) }
        }
    }

    init() {
        addTab()   // open one session on launch, in $HOME
        WindowRouter.shared.model = self
    }

    var active: SessionModel? {
        sessions.first { $0.id == activeID }
    }

    /// Directory a brand-new "+" tab should start in: the active tab's live CWD,
    /// falling back to its initial directory, then $HOME.
    private var inheritedDirectory: String {
        if let a = active {
            let dir = a.cwd
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
                return dir
            }
            return a.initialDirectory
        }
        return NSHomeDirectory()
    }

    /// Cmd+T — new tab inheriting the current directory.
    @discardableResult
    func addTab() -> SessionModel {
        let dir = sessions.isEmpty ? NSHomeDirectory() : inheritedDirectory
        return open(directory: dir)
    }

    /// Open a tab in an explicit directory (Finder / script runner).
    @discardableResult
    func open(directory: String, command: String? = nil) -> SessionModel {
        let s = SessionModel(initialDirectory: directory, initialCommand: command)
        sessions.append(s)
        activeID = s.id
        return s
    }

    /// Open a Markdown file in a preview. `split: nil` follows the Settings →
    /// Markdown "Open Markdown files in" choice.
    ///
    /// Single-split policy: the window has at most ONE split preview panel.
    /// Every split-opened document becomes a tab INSIDE that panel
    /// (terminal | preview | doc-tab1 | doc-tab2 …) instead of sprouting a
    /// preview on every terminal tab. Falls back to a dedicated window tab
    /// when there is no terminal to split beside.
    func openPreview(url: URL, split: Bool? = nil) {
        let wantSplit = split
            ?? (UserDefaults.standard.string(forKey: "previewOpenMode") != "tab")
        if wantSplit {
            if let host = sessions.first(where: { $0.kind == .terminal && $0.preview != nil }),
               let panel = host.preview {
                panel.open(url: url)
                host.code = nil        // a code split would occlude the preview
                activeID = host.id
                return
            }
            if let active, active.kind == .terminal {
                let panel = PreviewPanelModel()
                panel.open(url: url)
                active.preview = panel
                active.code = nil      // a code split would occlude the preview
                return
            }
        }
        let panel = PreviewPanelModel()
        panel.open(url: url)
        openPreviewTab(panel)
    }

    /// Open a code file in a read-only viewer. Single-split policy (like preview):
    /// the window keeps at most ONE split code panel, and every opened file becomes
    /// a tab INSIDE it (terminal | code | tab1 | tab2 …); re-opening a file focuses
    /// its tab. Falls back to a dedicated `.code` tab when there is no terminal.
    @MainActor
    func openCode(url: URL, split: Bool = true) {
        if split {
            if let host = sessions.first(where: { $0.kind == .terminal && $0.code != nil }),
               let panel = host.code {
                panel.open(url: url)
                activeID = host.id
                return
            }
            if let active, active.kind == .terminal {
                let panel = CodePanelModel()
                panel.open(url: url)
                active.code = panel
                return
            }
        }
        // No terminal to split beside: dedicated code tab (reuse an existing one).
        if let host = sessions.first(where: { $0.kind == .code }), let panel = host.code {
            panel.open(url: url)
            activeID = host.id
            return
        }
        let panel = CodePanelModel()
        panel.open(url: url)
        let s = SessionModel.codeTab(panel)
        sessions.append(s)
        activeID = s.id
    }

    /// Open several Markdown files at once (multi-file drag & drop): all land
    /// in the single split panel as document tabs (or as window tabs when the
    /// user's open-mode is "tab").
    func openPreviews(urls: [URL]) {
        urls.forEach { openPreview(url: $0) }
    }

    /// Open a preview panel as its own window tab (document name as the title).
    @discardableResult
    func openPreviewTab(_ panel: PreviewPanelModel) -> SessionModel {
        let s = SessionModel.previewTab(panel)
        sessions.append(s)
        activeID = s.id
        return s
    }

    /// Restart a completed session in place: spawn a fresh shell in its last-known
    /// directory, keeping the tab's position and (if active) selection.
    func restart(_ id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        let old = sessions[idx]
        var dir = old.cwd
        var isDir: ObjCBool = false
        if !(FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) && isDir.boolValue) {
            dir = old.initialDirectory
        }
        let fresh = SessionModel(initialDirectory: dir)
        fresh.customTitle = old.customTitle   // keep the user's tab name
        sessions[idx] = fresh
        if activeID == old.id { activeID = fresh.id }
    }

    func select(_ id: UUID) { activeID = id }

    func selectIndex(_ index: Int) {
        guard sessions.indices.contains(index) else { return }
        activeID = sessions[index].id
    }

    func close(_ id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = sessions[idx].id == activeID
        sessions[idx].terminate()          // tear down the shell/PTY
        sessions.remove(at: idx)
        if sessions.isEmpty {
            NSApp.keyWindow?.close()
            return
        }
        if wasActive {
            activeID = sessions[min(idx, sessions.count - 1)].id
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        sessions.move(fromOffsets: source, toOffset: destination)
    }

    /// Reorder: drop the dragged tab (by id string) in front of `targetID`.
    func moveTab(_ draggedIDString: String, before targetID: UUID) {
        guard let dragged = UUID(uuidString: draggedIDString), dragged != targetID,
              let from = sessions.firstIndex(where: { $0.id == dragged }) else { return }
        let item = sessions.remove(at: from)
        let target = sessions.firstIndex(where: { $0.id == targetID }) ?? sessions.count
        sessions.insert(item, at: target)
    }

    /// Terminate every session's shell (called on app quit).
    func terminateAll() { sessions.forEach { $0.terminate() } }
}

/// Lightweight bridge so AppKit views (drag & drop, URL open) can reach the
/// active window model. Single-window app for now.
final class WindowRouter {
    static let shared = WindowRouter()
    weak var model: WindowModel?
    func openInNewTab(_ directory: String) {
        DispatchQueue.main.async { self.model?.open(directory: directory) }
    }
    func openMarkdownPreview(_ url: URL, split: Bool? = nil) {
        DispatchQueue.main.async { self.model?.openPreview(url: url, split: split) }
    }
    func openMarkdownPreviews(_ urls: [URL]) {
        DispatchQueue.main.async { self.model?.openPreviews(urls: urls) }
    }
    func openCode(_ url: URL, split: Bool = true) {
        DispatchQueue.main.async { self.model?.openCode(url: url, split: split) }
    }
}
