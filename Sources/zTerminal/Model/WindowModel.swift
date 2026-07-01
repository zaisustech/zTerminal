import Foundation
import SwiftUI

/// The window's tab set: an ordered list of sessions plus the active one.
/// New tabs inherit the active tab's current directory (Terminal.app-style).
final class WindowModel: ObservableObject {
    @Published var sessions: [SessionModel] = []
    @Published var activeID: UUID? { didSet { AttentionManager.shared.markActive(active) } }

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
}
