import Foundation

/// Pure, testable logic for working-directory handling.
///
/// Kept free of SwiftTerm / AppKit so it can be exercised by unit tests
/// (tasks 7.1 / 7.2) and reused by the toolbar and Finder integration.
public enum CwdLogic {

    /// The result of resolving an OSC 7 `file://host/path` payload.
    public struct HostedPath: Equatable {
        public let host: String      // "" for local
        public let path: String      // decoded filesystem path
        public init(host: String, path: String) {
            self.host = host
            self.path = path
        }
    }

    /// Parse an OSC 7 directory payload of the form `file://HOST/PATH`.
    /// Also tolerates a bare path (no scheme) which some shells emit.
    /// Returns nil if the payload is empty or clearly malformed.
    public static func parseOSC7(_ raw: String) -> HostedPath? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if s.hasPrefix("file://") {
            let rest = String(s.dropFirst("file://".count))
            // rest = HOST/PATH ; the first "/" begins the path.
            guard let slash = rest.firstIndex(of: "/") else {
                // "file://host" with no path — not useful.
                return nil
            }
            let host = String(rest[rest.startIndex..<slash])
            let encodedPath = String(rest[slash...])
            let path = encodedPath.removingPercentEncoding ?? encodedPath
            return HostedPath(host: host, path: path)
        }

        // Bare absolute path fallback.
        if s.hasPrefix("/") {
            return HostedPath(host: "", path: s.removingPercentEncoding ?? s)
        }
        return nil
    }

    /// True when a host reported by OSC 7 refers to this machine.
    /// Local hosts: empty, "localhost", or the machine's own hostname(s).
    public static func isLocalHost(_ host: String, localNames: Set<String>) -> Bool {
        if host.isEmpty { return true }
        let h = host.lowercased()
        if h == "localhost" { return true }
        let names = Set(localNames.map { $0.lowercased() })
        if names.contains(h) { return true }
        // Trim a trailing ".local" / ".lan" for comparison.
        let base = h.split(separator: ".").first.map(String.init) ?? h
        return names.contains(base) || localNames.map { $0.lowercased().split(separator: ".").first.map(String.init) ?? "" }.contains(base)
    }

    /// Abbreviate a path under the user's home directory as `~`.
    public static func abbreviatingHome(_ path: String, home: String) -> String {
        guard !home.isEmpty else { return path }
        let normHome = home.hasSuffix("/") ? String(home.dropLast()) : home
        if path == normHome { return "~" }
        if path.hasPrefix(normHome + "/") {
            return "~" + path.dropFirst(normHome.count)
        }
        return path
    }

    /// Validate a path handed to the "open at path" entry point (URL scheme,
    /// Services, Finder Sync). Returns a canonical directory path or nil.
    ///
    /// Rejects: non-existent paths, files (non-directories). Resolves symlinks
    /// and `..`, and strips a trailing slash.
    public static func validateOpenPath(_ path: String,
                                        fileManager: FileManager = .default) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return url.path
    }

    /// Extract a validated directory path from a `zterminal://open?path=...` URL.
    public static func openPath(fromURL url: URL,
                                fileManager: FileManager = .default) -> String? {
        guard url.scheme?.lowercased() == "zterminal",
              url.host?.lowercased() == "open" || url.path.contains("open") || url.host == nil
        else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let raw = comps?.queryItems?.first(where: { $0.name == "path" })?.value else {
            return nil
        }
        return validateOpenPath(raw, fileManager: fileManager)
    }
}
