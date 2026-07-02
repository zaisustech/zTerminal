import Foundation

/// Persisted, de-duplicated, capped list of recently visited directories, most
/// recent first. Independent of the shell's own history; updated as the working
/// directory changes and surfaced in the command palette.
final class RecentDirectories {
    static let shared = RecentDirectories(defaults: .standard)

    private let defaults: UserDefaults
    private let key = "commandPalette.recentDirectories"
    private let cap: Int

    private(set) var paths: [String]

    init(defaults: UserDefaults, cap: Int = 20) {
        self.defaults = defaults
        self.cap = cap
        self.paths = defaults.stringArray(forKey: key) ?? []
    }

    /// Record a visited directory: move it to the front, drop duplicates, trim to
    /// the cap. Ignores empty paths and root (`/`).
    func record(_ path: String) {
        let p = path.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty, p != "/" else { return }
        guard paths.first != p else { return }          // already most-recent
        paths.removeAll { $0 == p }
        paths.insert(p, at: 0)
        if paths.count > cap { paths.removeLast(paths.count - cap) }
        defaults.set(paths, forKey: key)
    }

    func clear() {
        paths = []
        defaults.removeObject(forKey: key)
    }
}
