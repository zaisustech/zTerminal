import Foundation

/// A snapshot of a directory's git state. `nil` (not this type) means "not a repo".
struct GitStatus: Equatable {
    var label: String      // branch name, or short SHA when detached
    var detached: Bool
    var dirty: Bool
    var ahead: Int
    var behind: Int
}

/// Runs cheap git plumbing for a directory. Call `status(for:)` off the main
/// thread. The parsing helpers are pure and unit-tested.
enum Git {
    static let executable = "/usr/bin/git"

    /// Run `git -C <dir> <args>`; returns trimmed stdout on success, else nil.
    static func run(_ args: [String], in dir: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = ["-C", dir] + args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Full status for a directory, or nil when it isn't inside a work tree.
    static func status(for dir: String) -> GitStatus? {
        guard run(["rev-parse", "--is-inside-work-tree"], in: dir) == "true" else { return nil }

        var label = "HEAD"
        var detached = false
        if let b = run(["symbolic-ref", "--short", "HEAD"], in: dir), !b.isEmpty {
            label = b
        } else if let sha = run(["rev-parse", "--short", "HEAD"], in: dir), !sha.isEmpty {
            label = sha
            detached = true
        }

        let dirty = isDirty(porcelain: run(["status", "--porcelain"], in: dir))
        let (behind, ahead) = parseAheadBehind(
            run(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], in: dir)
        )
        return GitStatus(label: label, detached: detached, dirty: dirty, ahead: ahead, behind: behind)
    }

    /// Local branch names for a directory, current branch first, or [] on failure.
    /// Cheap plumbing (`for-each-ref`); safe to call off the main thread.
    static func branches(in dir: String) -> [String] {
        guard let out = run(["for-each-ref", "--format=%(refname:short)",
                             "--sort=-committerdate", "refs/heads/"], in: dir) else { return [] }
        return out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: Pure parsers (unit-tested)

    /// Any porcelain output means there are uncommitted changes.
    static func isDirty(porcelain: String?) -> Bool {
        !(porcelain ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `git rev-list --left-right --count @{upstream}...HEAD` prints "<behind>\t<ahead>".
    /// Returns (0,0) when there's no upstream (nil input) or on a parse miss.
    static func parseAheadBehind(_ s: String?) -> (behind: Int, ahead: Int) {
        guard let s else { return (0, 0) }
        let parts = s.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).compactMap { Int($0) }
        guard parts.count == 2 else { return (0, 0) }
        return (parts[0], parts[1])
    }
}
