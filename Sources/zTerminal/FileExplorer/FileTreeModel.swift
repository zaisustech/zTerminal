import Foundation
import SwiftUI

/// Backing store for the file-explorer sidebar: holds the current root node,
/// reads directory contents off the main thread, caches children per node, and
/// re-roots when the active tab's working directory changes. One model per window
/// (the sidebar shows one tree at a time).
@MainActor
final class FileTreeModel: ObservableObject {
    @Published private(set) var root: FileNode?
    @Published var showHidden = false {
        didSet { if oldValue != showHidden { refresh() } }
    }
    /// When the root is locked, the tree stays on its current root and ignores CWD
    /// changes (header pin button — distinct from pinned-favorite folders below).
    @Published private(set) var rootPinned = false

    /// Pinned favorite folders, shown as their own expandable trees in a section at
    /// the top of the sidebar. Persisted; ordered most-recently-pinned last.
    @Published private(set) var pinnedPaths: [String] = UserDefaults.standard.stringArray(forKey: "fileExplorer.pinned") ?? []
    /// A `FileNode` per pinned path so each can be browsed in place (expanded) WITHOUT
    /// changing the workspace root.
    @Published private(set) var pinnedNodes: [FileNode] = []

    private var rootPath: String?
    /// The active tab's directory (recorded on every CWD-driven `setRoot`) so the
    /// Home button can always return to the original workspace tree.
    private(set) var workspacePath: String?

    /// Unlock and re-root to the active tab's working directory (the "Home" action).
    func goToWorkspace() {
        rootPinned = false
        if let w = workspacePath { setRoot(path: w, force: true) }
    }

    init() {
        pinnedNodes = pinnedPaths.map { FileNode(url: URL(fileURLWithPath: $0), isDirectory: true) }
    }

    /// Lock/unlock the current root against CWD changes.
    func toggleRootPin() { rootPinned.toggle() }

    // MARK: Pinned favorites

    func isPinned(_ path: String) -> Bool {
        pinnedPaths.contains((path as NSString).standardizingPath)
    }

    /// Pin or unpin a folder to the top favorites section.
    func togglePin(path: String) {
        let p = (path as NSString).standardizingPath
        if let i = pinnedPaths.firstIndex(of: p) {
            pinnedPaths.remove(at: i)
            pinnedNodes.remove(at: i)
        } else {
            pinnedPaths.append(p)
            pinnedNodes.append(FileNode(url: URL(fileURLWithPath: p), isDirectory: true))
        }
        UserDefaults.standard.set(pinnedPaths, forKey: "fileExplorer.pinned")
    }

    /// Point the tree at `path` if it is an existing directory and differs from the
    /// current root. Non-directories and unchanged paths are ignored (so noisy CWD
    /// updates don't thrash the tree). CWD-driven calls respect the root lock;
    /// `force` (e.g. clicking a pinned favorite) navigates regardless.
    func setRoot(path: String, force: Bool = false) {
        // Remember the workspace (CWD) target even when locked, so "Home" can return.
        if !force { workspacePath = (path as NSString).standardizingPath }
        guard force || !rootPinned else { return }   // locked → ignore CWD changes
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue
        else { return }
        let standardized = (path as NSString).standardizingPath
        guard standardized != rootPath else { return }
        rootPath = standardized
        let node = FileNode(url: URL(fileURLWithPath: standardized), isDirectory: true)
        node.isExpanded = true
        root = node
        load(node)
    }

    /// Collapse every expanded folder back to the top level (VS Code "Collapse
    /// Folders"). The root stays visible; pinned folders collapse too.
    func collapseAll() {
        if let root { Self.collapseDescendants(of: root) }
        for node in pinnedNodes { node.isExpanded = false; Self.collapseDescendants(of: node) }
    }

    private static func collapseDescendants(of node: FileNode) {
        for child in node.children ?? [] where child.isDirectory {
            child.isExpanded = false
            collapseDescendants(of: child)
        }
    }

    /// Toggle a folder open/closed, loading its children on first expand.
    func toggle(_ node: FileNode) {
        guard node.isDirectory else { return }
        node.isExpanded.toggle()
        if node.isExpanded && !node.isLoaded { load(node) }
    }

    /// Re-read the whole tree from disk, preserving which folders are expanded
    /// where they still exist.
    func refresh() {
        guard let root else { return }
        let expanded = expandedPaths(of: root)
        root.children = nil
        load(root) { [weak self] in self?.restoreExpansion(root, expanded: expanded) }
    }

    // MARK: Loading

    /// Read a folder's children off-main, arrange them, and publish on main.
    private func load(_ node: FileNode, completion: (() -> Void)? = nil) {
        let dir = node.url
        let showHidden = self.showHidden
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let urls = (try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [])) ?? []
            let entries = urls.map { url -> (URL, DirEntry) in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return (url, DirEntry(name: url.lastPathComponent, isDirectory: isDir))
            }
            let arranged = FileTree.arrange(entries.map { $0.1 }, showHidden: showHidden)
            // Rebuild nodes in arranged order.
            let byName = Dictionary(entries.map { ($0.1.name, $0.0) }, uniquingKeysWith: { a, _ in a })
            let nodes = arranged.compactMap { entry -> FileNode? in
                guard let url = byName[entry.name] else { return nil }
                return FileNode(url: url, isDirectory: entry.isDirectory)
            }
            DispatchQueue.main.async {
                node.children = nodes
                completion?()
            }
        }
    }

    // MARK: Expansion preservation across refresh

    private func expandedPaths(of node: FileNode, into set: inout Set<String>) {
        if node.isExpanded { set.insert(node.url.path) }
        node.children?.forEach { expandedPaths(of: $0, into: &set) }
    }

    private func expandedPaths(of node: FileNode) -> Set<String> {
        var set = Set<String>()
        expandedPaths(of: node, into: &set)
        return set
    }

    /// After a refresh reload, re-expand (and re-load) folders that were open.
    private func restoreExpansion(_ node: FileNode, expanded: Set<String>) {
        guard let children = node.children else { return }
        for child in children where child.isDirectory && expanded.contains(child.url.path) {
            child.isExpanded = true
            load(child) { [weak self] in self?.restoreExpansion(child, expanded: expanded) }
        }
    }
}
