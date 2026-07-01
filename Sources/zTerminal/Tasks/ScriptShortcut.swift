import Foundation

/// A global, typed command shortcut: type `name` at the prompt and the mapped
/// `command` runs (e.g. `zaisus` → `bun run start`). Injected into each new shell
/// as a function so the shell itself expands it — no keystroke interception.
public struct ScriptShortcut: Codable, Identifiable, Equatable {
    /// Stable identity so editing the name doesn't disturb SwiftUI list rows.
    public var id: UUID
    public var name: String        // the word typed at the prompt
    public var command: String     // the shell command it runs (verbatim)

    public init(id: UUID = UUID(), name: String = "", command: String = "") {
        self.id = id
        self.name = name
        self.command = command
    }

    private enum CodingKeys: String, CodingKey { case id, name, command }

    /// Tolerant decode: a missing `id` (older configs) gets a fresh one.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        command = try c.decode(String.self, forKey: .command)
    }

    // MARK: - Validation

    /// Shell reserved words that cannot be used as a shortcut name.
    public static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "case", "esac", "for", "select",
        "while", "until", "do", "done", "function", "in", "time", "coproc",
    ]

    /// A name is valid when it matches `^[A-Za-z_][A-Za-z0-9_-]*$` and is not a
    /// shell keyword. This keeps it usable as a shell function name in zsh/bash.
    public static func isValidName(_ raw: String) -> Bool {
        let n = raw.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !shellKeywords.contains(n) else { return false }
        return n.range(of: "^[A-Za-z_][A-Za-z0-9_-]*$", options: .regularExpression) != nil
    }

    /// Names that appear more than once in the list (trimmed, case-sensitive).
    public static func duplicateNames(in list: [ScriptShortcut]) -> Set<String> {
        var seen = Set<String>(), dupes = Set<String>()
        for s in list {
            let key = s.name.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            if !seen.insert(key).inserted { dupes.insert(key) }
        }
        return dupes
    }

    // MARK: - Shell injection

    /// Wrap a string as a single-quoted shell literal, escaping embedded quotes
    /// (`'` → `'\''`). Nothing inside can break out of the quoting or inject
    /// additional commands, so any command text is safe to embed.
    public static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// The shell function that installs this shortcut, or nil when the entry is
    /// invalid (bad name or empty command) so a bad row is skipped, not emitted.
    /// Uses `eval` on the single-quoted command so it can never break the
    /// definition, and forwards extra arguments via `"$@"`.
    public func functionDefinition() -> String? {
        let n = name.trimmingCharacters(in: .whitespaces)
        let cmd = command.trimmingCharacters(in: .whitespaces)
        guard ScriptShortcut.isValidName(n), !cmd.isEmpty else { return nil }
        return "\(n)() { eval \(ScriptShortcut.shellQuote(cmd)) \"$@\"; }"
    }

    /// A sourced shell block defining every valid shortcut. Invalid or duplicate
    /// entries (first name wins) are skipped, so one bad row can never break shell
    /// startup. Returns an empty string when there is nothing to install.
    public static func shellBlock(for shortcuts: [ScriptShortcut]) -> String {
        var seen = Set<String>()
        var defs: [String] = []
        for s in shortcuts {
            let n = s.name.trimmingCharacters(in: .whitespaces)
            guard let def = s.functionDefinition(), seen.insert(n).inserted else { continue }
            defs.append(def)
        }
        guard !defs.isEmpty else { return "" }
        return "\n# zTerminal script shortcuts\n" + defs.joined(separator: "\n") + "\n"
    }

    // MARK: - Collision detection (UI warning)

    /// Common shell builtins a shortcut would shadow (warned about, not blocked).
    public static let commonBuiltins: Set<String> = [
        "cd", "echo", "pwd", "export", "alias", "unalias", "set", "unset",
        "source", "eval", "exec", "exit", "read", "test", "type", "command",
        "builtin", "let", "local", "return", "shift", "printf", "true", "false",
        "kill", "jobs", "fg", "bg", "wait", "trap", "history", "hash", "umask",
    ]

    /// True when `name` matches a shell builtin or an executable on `$PATH` —
    /// i.e. defining the shortcut would override an existing command.
    public static func shadowsExistingCommand(_ raw: String,
                                              fileManager fm: FileManager = .default) -> Bool {
        let n = raw.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return false }
        if commonBuiltins.contains(n) { return true }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        for dir in path.split(separator: ":") {
            let p = (String(dir) as NSString).appendingPathComponent(n)
            if fm.isExecutableFile(atPath: p) { return true }
        }
        return false
    }
}
