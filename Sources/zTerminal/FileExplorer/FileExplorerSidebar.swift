import SwiftUI
import AppKit

/// VS Code-style file tree sidebar: a header (root name + Refresh + hidden-files
/// toggle) over a lazily-loaded, recursive tree of the active tab's directory.
struct FileExplorerSidebar: View {
    @ObservedObject var tree: FileTreeModel
    /// Open a file (phase 1: caller reveals / opens externally; phase 2 intercepts code files).
    var onOpenFile: (URL) -> Void
    /// Open a folder in a new terminal tab.
    var onOpenFolderInTab: (URL) -> Void

    @State private var selection: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            if !tree.pinnedPaths.isEmpty {
                pinnedSection
                Divider().opacity(0.3)
            }
            if let root = tree.root {
                // `SidebarTree` observes the root node, so it re-renders as soon as
                // the root's children load (fixes the endless spinner that only
                // cleared on a sidebar toggle).
                SidebarTree(root: root, tree: tree, selection: $selection,
                            onOpenFile: onOpenFile, onOpenFolderInTab: onOpenFolderInTab)
            } else {
                Spacer()
                Text("No folder").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .clipped()
    }

    /// Favorites pinned via the row "Pin to Top" action. Each is its own expandable
    /// tree — browse the files in place WITHOUT changing the workspace root. Unpin
    /// via the row's context menu ("Remove from Pinned").
    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("PINNED").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 2)
            ForEach(tree.pinnedNodes) { node in
                FileRow(node: node, tree: tree, depth: 0,
                        selection: $selection,
                        onOpenFile: onOpenFile,
                        onOpenFolderInTab: onOpenFolderInTab)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { tree.toggleRootPin() } label: {
                Image(systemName: tree.rootPinned ? "lock.fill" : "lock.open").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(tree.rootPinned ? Color.accentColor : .secondary)
            .help(tree.rootPinned ? "Unlock — follow the terminal's folder" : "Lock this folder as the root")
            Text(tree.root?.name ?? "Explorer")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button { tree.goToWorkspace() } label: {
                Image(systemName: "house").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Back to the current terminal folder")
            Button { tree.showHidden.toggle() } label: {
                Image(systemName: tree.showHidden ? "eye" : "eye.slash").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(tree.showHidden ? Color.accentColor : .secondary)
            .help("Show hidden files")
            Button { tree.collapseAll() } label: {
                Image(systemName: "rectangle.compress.vertical").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Collapse all folders")
            Button { tree.refresh() } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Refresh")
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }
}

/// One tree row, plus (when a folder is expanded) its children recursively. Each
/// row observes only its own node, so expanding one folder doesn't rebuild the tree.
/// The scrollable tree body, observing the root node so it re-renders the moment
/// the root's children finish loading.
private struct SidebarTree: View {
    @ObservedObject var root: FileNode
    let tree: FileTreeModel
    @Binding var selection: URL?
    var onOpenFile: (URL) -> Void
    var onOpenFolderInTab: (URL) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let children = root.children {
                    if children.isEmpty {
                        Text("Empty folder").font(.caption).foregroundStyle(.secondary).padding(8)
                    } else {
                        ForEach(children) { child in
                            FileRow(node: child, tree: tree, depth: 0,
                                    selection: $selection,
                                    onOpenFile: onOpenFile,
                                    onOpenFolderInTab: onOpenFolderInTab)
                        }
                    }
                } else {
                    ProgressView().controlSize(.small).padding(.top, 8)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FileRow: View {
    @ObservedObject var node: FileNode
    let tree: FileTreeModel
    let depth: Int
    @Binding var selection: URL?
    var onOpenFile: (URL) -> Void
    var onOpenFolderInTab: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            rowContent
            if node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileRow(node: child, tree: tree, depth: depth + 1,
                            selection: $selection,
                            onOpenFile: onOpenFile,
                            onOpenFolderInTab: onOpenFolderInTab)
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 4) {
            // Indent + disclosure triangle (folders only).
            if node.isDirectory {
                Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            } else {
                Spacer().frame(width: 12)
            }
            Image(systemName: node.iconName)
                .font(.system(size: 12))
                .foregroundStyle(node.isDirectory ? Color.accentColor : .secondary)
                .frame(width: 16)
            Text(node.name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(depth) * 12 + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selection == node.url ? Color.accentColor.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { open() }
        .onTapGesture(count: 1) {
            selection = node.url
            if node.isDirectory { tree.toggle(node) }
        }
        // Drag a row onto the terminal to insert its (shell-escaped) path — the
        // terminal already accepts file-URL drops, same as dragging from Finder.
        .onDrag { NSItemProvider(object: node.url as NSURL) }
        .contextMenu { menu }
    }

    private func open() {
        if node.isDirectory { tree.toggle(node) } else { onOpenFile(node.url) }
    }

    @ViewBuilder private var menu: some View {
        if node.isDirectory {
            Button("Open in New Tab") { onOpenFolderInTab(node.url) }
            Button(tree.isPinned(node.url.path) ? "Remove from Pinned" : "Pin to Top") {
                tree.togglePin(path: node.url.path)
            }
            Divider()
        } else {
            Button("Open") { onOpenFile(node.url) }
            Divider()
        }
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.url.path, forType: .string)
        }
    }
}
