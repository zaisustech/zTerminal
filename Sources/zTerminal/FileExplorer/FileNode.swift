import Foundation
import SwiftUI

/// One node in the file tree. A reference type so SwiftUI rows can observe a
/// single node's expansion/children changing without rebuilding the whole tree,
/// and so children can be loaded lazily in place.
final class FileNode: Identifiable, ObservableObject {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool

    /// Whether this folder is expanded in the UI.
    @Published var isExpanded = false
    /// Children, or nil until this folder is first loaded (nil = not yet read).
    @Published var children: [FileNode]?

    var isLoaded: Bool { children != nil }

    init(url: URL, isDirectory: Bool) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
    }

    /// SF Symbol for this node, by kind then extension.
    var iconName: String {
        if isDirectory { return isExpanded ? "folder.fill" : "folder" }
        return FileNode.icon(forExtension: url.pathExtension.lowercased())
    }

    static func icon(forExtension ext: String) -> String {
        switch ext {
        case "swift":                          return "swift"
        case "js", "jsx", "ts", "tsx", "mjs":  return "curlybraces"
        case "json", "yml", "yaml", "toml":    return "list.bullet.indent"
        case "md", "markdown", "txt", "rtf":   return "doc.text"
        case "py", "rb", "go", "rs", "java",
             "c", "h", "cpp", "cc", "sh",
             "zsh", "bash":                    return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif",
             "svg", "webp", "icns", "heic":    return "photo"
        case "pdf":                            return "doc.richtext"
        case "zip", "gz", "tar", "dmg":        return "archivebox"
        case "lock":                           return "lock"
        default:                               return "doc"
        }
    }
}

/// A lightweight directory entry (name + kind) — the unit the pure sort/filter
/// operates on, so it is testable without touching disk.
struct DirEntry: Equatable {
    let name: String
    let isDirectory: Bool
}

enum FileTree {
    /// Names always hidden unless "show hidden" is on (dotfiles are handled by the
    /// leading-dot check; these are common noise dirs worth hiding too).
    static let noiseNames: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", ".build", ".next", "dist",
        ".DS_Store", ".idea", ".vscode", "__pycache__", ".pytest_cache",
    ]

    /// Filter (hidden files / noise) then sort folders-first, case-insensitive by
    /// name. Pure — the sidebar's ordering contract, unit-tested against fixtures.
    static func arrange(_ entries: [DirEntry], showHidden: Bool) -> [DirEntry] {
        entries
            .filter { e in
                if showHidden { return true }
                if e.name.hasPrefix(".") { return false }
                if noiseNames.contains(e.name) { return false }
                return true
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }
}
