import Foundation

/// The app-owned command history: one global, ordered (most recent first),
/// capped, de-duplicated list of executed commands, captured from the shell
/// integration's extended OSC 133;C marker and persisted so a fresh tab (or a
/// fresh launch) already has suggestions.
///
/// Recording and lookups happen on the main thread (both arrive from terminal
/// key/OSC handling); persistence is debounced and written in the background.
final class CommandHistoryStore {
    static let shared = CommandHistoryStore()

    /// Most recent first.
    private(set) var entries: [String] = []

    let cap: Int
    private let fileURL: URL
    private var persistPending = false

    /// Default persistence lives beside `~/.zTerminal.json`.
    static var defaultFileURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".zTerminal.history.json")
    }

    init(cap: Int = 2000, fileURL: URL = CommandHistoryStore.defaultFileURL) {
        self.cap = cap
        self.fileURL = fileURL
        load()
    }

    // MARK: Recording

    /// Record an executed command. Never records: empty/whitespace-only
    /// commands, the integration's own `_zt_*`/`__zt_*` helpers, or commands
    /// entered with a leading space (the shell-history opt-out convention).
    func record(_ raw: String) {
        guard !raw.isEmpty, raw.first != " " else { return }
        let command = raw.hasSuffix("\n") ? String(raw.dropLast()) : raw
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !Self.isInternalHelper(command) else { return }

        entries.removeAll { $0 == command }
        entries.insert(command, at: 0)
        if entries.count > cap { entries.removeLast(entries.count - cap) }
        persistSoon()
    }

    /// True for the shell integration's own helper invocations.
    static func isInternalHelper(_ command: String) -> Bool {
        command.hasPrefix("_zt_") || command.hasPrefix("__zt_")
    }

    // MARK: Suggestion

    /// The most recent entry that starts with `prefix` and is strictly longer
    /// (fish semantics). Empty input yields nothing; multiline entries are
    /// skipped because the single-line ghost overlay cannot render them.
    func suggestion(forPrefix prefix: String) -> String? {
        guard !prefix.isEmpty else { return nil }
        return entries.first {
            $0.count > prefix.count && $0.hasPrefix(prefix) && !$0.contains("\n")
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            entries = []   // missing or corrupt file → empty history
            return
        }
        entries = Array(list.prefix(cap))
    }

    /// Debounced write: coalesces bursts of commands into one save.
    private func persistSoon() {
        guard !persistPending else { return }
        persistPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.persistPending = false
            self?.persistNow()
        }
    }

    func persistNow() {
        let snapshot = entries
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
