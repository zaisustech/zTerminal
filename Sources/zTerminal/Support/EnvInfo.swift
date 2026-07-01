import Foundation

/// A small runtime/environment badge for the status bar (e.g. "node 20", ".venv").
struct EnvBadge: Equatable, Identifiable {
    var symbol: String   // SF Symbol name
    var text: String
    var id: String { symbol + text }
}

/// Cheap, filesystem-first detection of the active runtime for a directory.
/// Spawns a subprocess only when a manifest is present and no pinned version
/// file answers the question. Call `badges(for:)` off the main thread.
enum EnvInfo {

    static func badges(for dir: String) -> [EnvBadge] {
        var out: [EnvBadge] = []
        if let node = node(in: dir) { out.append(node) }
        if let py = python(in: dir) { out.append(py) }
        return out
    }

    // MARK: Node

    /// `.nvmrc`/`.node-version` (no spawn) wins; otherwise, if a package.json is
    /// present, report the resolved `node --version`.
    private static func node(in dir: String) -> EnvBadge? {
        let fm = FileManager.default
        for pin in [".nvmrc", ".node-version"] {
            let p = (dir as NSString).appendingPathComponent(pin)
            if let raw = try? String(contentsOfFile: p, encoding: .utf8) {
                let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !v.isEmpty { return EnvBadge(symbol: "hexagon", text: "node \(clean(v))") }
            }
        }
        guard fm.fileExists(atPath: (dir as NSString).appendingPathComponent("package.json")) else { return nil }
        if let v = run("/usr/bin/env", ["node", "--version"], in: dir) {
            return EnvBadge(symbol: "hexagon", text: "node \(clean(v))")
        }
        return EnvBadge(symbol: "hexagon", text: "node")
    }

    // MARK: Python

    /// A project virtualenv (`.venv`/`venv` with a python binary) — labeled by the
    /// version from `pyvenv.cfg` when available, so we never spawn a process.
    private static func python(in dir: String) -> EnvBadge? {
        let fm = FileManager.default
        for name in [".venv", "venv"] {
            let venv = (dir as NSString).appendingPathComponent(name)
            let py = (venv as NSString).appendingPathComponent("bin/python")
            guard fm.fileExists(atPath: py) else { continue }
            var label = name
            let cfg = (venv as NSString).appendingPathComponent("pyvenv.cfg")
            if let text = try? String(contentsOfFile: cfg, encoding: .utf8),
               let line = text.split(separator: "\n").first(where: { $0.contains("version") }),
               let ver = line.split(separator: "=").last {
                label = "py \(ver.trimmingCharacters(in: .whitespaces))"
            }
            return EnvBadge(symbol: "chevron.left.forwardslash.chevron.right", text: label)
        }
        return nil
    }

    // MARK: Helpers

    private static func clean(_ v: String) -> String {
        v.hasPrefix("v") ? String(v.dropFirst()) : v
    }

    private static func run(_ exe: String, _ args: [String], in dir: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        p.currentDirectoryURL = URL(fileURLWithPath: dir)
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty ?? true) ? nil : s
    }
}
