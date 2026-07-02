import Foundation

/// Recent search terms, most-recent-first, de-duplicated and capped. Persisted so
/// the find bar can offer prior queries across launches. App-wide (not per-tab):
/// history is a convenience, and developers expect the same recents everywhere.
final class SearchHistory {
    static let shared = SearchHistory(defaults: .standard)

    private let defaults: UserDefaults
    private let key = "terminalSearch.history"
    private let cap: Int

    private(set) var terms: [String]

    init(defaults: UserDefaults, cap: Int = 20) {
        self.defaults = defaults
        self.cap = cap
        self.terms = defaults.stringArray(forKey: key) ?? []
    }

    /// Record a committed query: move it to the front, drop duplicates (case- and
    /// whitespace-insensitively), and trim to the cap. Blank queries are ignored.
    func record(_ raw: String) {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        terms.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        terms.insert(term, at: 0)
        if terms.count > cap { terms.removeLast(terms.count - cap) }
        defaults.set(terms, forKey: key)
    }

    func clear() {
        terms = []
        defaults.removeObject(forKey: key)
    }
}
