import Foundation

/// A source of inline ghost-text suggestions for the prompt. Given the current
/// input (prompt-end → cursor) and the session's working directory, it returns
/// the dim suffix to draw after the cursor, or nil when it has nothing to offer.
///
/// New sources (e.g. command history) conform to this and are appended to the
/// engine's list, reusing the same overlay + Tab-accept behavior.
public protocol GhostSuggesting: AnyObject {
    func ghostSuffix(forInput input: String, cwd: String) -> String?
}

/// Consults an ordered list of sources and returns the first non-empty suffix.
public final class SuggestionEngine {
    private let sources: [GhostSuggesting]

    public init(sources: [GhostSuggesting]) {
        self.sources = sources
    }

    /// The suffix to show after the cursor, or nil when no source matches.
    public func suffix(forInput input: String, cwd: String) -> String? {
        for source in sources {
            if let s = source.ghostSuffix(forInput: input, cwd: cwd), !s.isEmpty {
                return s
            }
        }
        return nil
    }
}

/// Fish-style history suggestion: the most recent executed command that begins
/// with the typed input, shown as its remaining suffix. Backed by the global
/// `CommandHistoryStore`; the shared engine's overlay + Tab-accept do the rest.
public final class CommandHistorySource: GhostSuggesting {
    private let store: CommandHistoryStore

    init(store: CommandHistoryStore = .shared) {
        self.store = store
    }

    public func ghostSuffix(forInput input: String, cwd: String) -> String? {
        guard let match = store.suggestion(forPrefix: input) else { return nil }
        return String(match.dropFirst(input.count))
    }
}

/// Suggests `package.json` script names for whichever package manager the current
/// project uses. Detects the manager(s) and scripts via `PackageRunner` — from the
/// lockfile (`bun.lockb`/`bun.lock`, `pnpm-lock.yaml`, `yarn.lock`,
/// `package-lock.json`) and the `packageManager` field — cached by directory so
/// typing doesn't re-read the file. Matching is delegated to `ScriptCompletion`,
/// which completes only for a detected manager (a `yarn.lock` project completes
/// `yarn …`, not `bun …`).
public final class ScriptCompletionSource: GhostSuggesting {
    /// Command words that can precede a package.json script — the fast-reject set.
    private static let commandWords: Set<String> = ["npm", "pnpm", "yarn", "bun"]

    private let fileManager: FileManager
    private var cachedDir: String?
    private var cachedManagers: [PackageManager] = []
    private var cachedScripts: [String] = []

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func ghostSuffix(forInput input: String, cwd: String) -> String? {
        // Fast reject before any file IO: the first word must be a package manager.
        let firstWord = input.drop(while: { $0 == " " }).prefix(while: { $0 != " " })
        guard Self.commandWords.contains(String(firstWord)) else { return nil }

        load(cwd)
        guard !cachedScripts.isEmpty, !cachedManagers.isEmpty else { return nil }
        return ScriptCompletion.ghostSuffix(forInput: input,
                                            managers: cachedManagers,
                                            scripts: cachedScripts)
    }

    /// Load and cache the detected managers + ranked scripts for `cwd`, until the
    /// directory changes.
    private func load(_ cwd: String) {
        if cachedDir == cwd { return }
        cachedDir = cwd
        if let scanned = PackageRunner.load(in: cwd, fileManager: fileManager) {
            cachedManagers = scanned.managers
            cachedScripts = ScriptCompletion.ranked(scanned.tasks.map(\.name))
        } else {
            cachedManagers = []
            cachedScripts = []
        }
    }
}
