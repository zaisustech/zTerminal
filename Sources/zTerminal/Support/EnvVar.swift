import Foundation

/// A user-defined environment variable injected into every new zTerminal shell:
/// `KEY=value`. Exported into the spawned shell *after* the user's rc is sourced,
/// so the user's value overrides both the inherited/parent environment and any
/// same-named export in `~/.zshrc`. Disabled entries are kept but not injected.
public struct EnvVar: Codable, Identifiable, Equatable {
    /// Stable identity so editing the key doesn't disturb SwiftUI list rows.
    public var id: UUID
    public var key: String       // the variable name (POSIX: [A-Za-z_][A-Za-z0-9_]*)
    public var value: String     // its contents (embedded literally, safely quoted)
    public var enabled: Bool     // injected only when true

    public init(id: UUID = UUID(), key: String = "", value: String = "", enabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey { case id, key, value, enabled }

    /// Tolerant decode: a missing `id` (older configs) gets a fresh one; a missing
    /// `enabled` defaults to true so previously-saved variables stay active.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        key = try c.decode(String.self, forKey: .key)
        value = try c.decode(String.self, forKey: .value)
        enabled = (try c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? true
    }

    // MARK: - Validation

    /// A key is valid when it matches `^[A-Za-z_][A-Za-z0-9_]*$` — the POSIX rule
    /// for environment variable names (letters, digits, underscore; no leading
    /// digit; no hyphens, unlike script-shortcut names).
    public static func isValidKey(_ raw: String) -> Bool {
        let k = raw.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return false }
        return k.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
    }

    /// Keys that appear more than once in the list (trimmed, case-sensitive).
    public static func duplicateKeys(in list: [EnvVar]) -> Set<String> {
        var seen = Set<String>(), dupes = Set<String>()
        for v in list {
            let key = v.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            if !seen.insert(key).inserted { dupes.insert(key) }
        }
        return dupes
    }

    // MARK: - Shadowing detection (UI warning)

    /// True when `key` already exists in the inherited environment — injecting the
    /// variable will override that value. Warned about in the UI, never blocked.
    public static func shadowsInheritedEnv(
        _ raw: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        let k = raw.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return false }
        return environment[k] != nil
    }

    // MARK: - Shell injection

    /// One `export KEY='value'` line, or nil when the entry is disabled or the key
    /// is invalid. The value is single-quoted (reusing `ScriptShortcut.shellQuote`)
    /// so quotes, `$`, backticks, and newlines are literal and cannot break the
    /// export or inject commands.
    public func exportLine() -> String? {
        let k = key.trimmingCharacters(in: .whitespaces)
        guard enabled, EnvVar.isValidKey(k) else { return nil }
        return "export \(k)=\(ScriptShortcut.shellQuote(value))"
    }

    /// A sourced shell block exporting every enabled, valid variable. Invalid,
    /// disabled, or duplicate entries (first key wins) are skipped, so one bad row
    /// can never break shell startup. Empty when there is nothing to inject.
    public static func shellBlock(for vars: [EnvVar]) -> String {
        var seen = Set<String>()
        var lines: [String] = []
        for v in vars {
            let k = v.key.trimmingCharacters(in: .whitespaces)
            guard let line = v.exportLine(), seen.insert(k).inserted else { continue }
            lines.append(line)
        }
        guard !lines.isEmpty else { return "" }
        return "\n# zTerminal environment variables\n" + lines.joined(separator: "\n") + "\n"
    }

    /// The same enabled/valid/deduped variables as a `[key: value]` map, for
    /// seeding the pre-spawn child environment (belt-and-suspenders; the shell
    /// export above is authoritative for override precedence).
    public static func exportDictionary(for vars: [EnvVar]) -> [String: String] {
        var seen = Set<String>()
        var out: [String: String] = [:]
        for v in vars {
            let k = v.key.trimmingCharacters(in: .whitespaces)
            guard v.enabled, isValidKey(k), seen.insert(k).inserted else { continue }
            out[k] = v.value
        }
        return out
    }
}
