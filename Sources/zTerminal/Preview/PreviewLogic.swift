import Foundation

/// URL-scheme parsing for the Markdown preview, mirroring `CwdLogic`'s style
/// so it stays unit-testable: `zterminal://preview?path=/path/to/README.md`.
enum PreviewLogic {

    /// Extract a validated Markdown file path from a preview URL, or nil when
    /// the URL isn't a preview request / the file is missing / not Markdown.
    static func previewPath(fromURL url: URL,
                            fileManager: FileManager = .default) -> String? {
        guard url.scheme?.lowercased() == "zterminal",
              url.host?.lowercased() == "preview" else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let raw = comps?.queryItems?.first(where: { $0.name == "path" })?.value else {
            return nil
        }
        return validateMarkdownPath(raw, fileManager: fileManager)
    }

    /// Parse the shell-integration OSC 7773 payload emitted by the `markdown`
    /// (split) / `md` (tab) shell functions: `preview;<mode>;<absolute-path>`.
    /// The path is validated like every other preview entry point.
    static func previewRequest(fromOSC payload: String,
                               fileManager: FileManager = .default) -> (path: String, split: Bool)? {
        let parts = payload.split(separator: ";", maxSplits: 2, omittingEmptySubsequences: false)
            .map(String.init)
        guard parts.count == 3, parts[0] == "preview" else { return nil }
        guard let valid = validateMarkdownPath(parts[2], fileManager: fileManager) else { return nil }
        return (valid, parts[1] != "tab")
    }

    /// Expand, resolve, and verify a Markdown file path.
    static func validateMarkdownPath(_ path: String,
                                     fileManager: FileManager = .default) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).resolvingSymlinksInPath()
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return nil }
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return nil
        }
        return url.path
    }
}
