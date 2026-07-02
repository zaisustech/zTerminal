import Foundation
import AppKit

/// Opens files/directories in an external editor. The parsing + resolution +
/// argument-building are pure and unit-tested; only the final process spawn
/// touches the system.
enum EditorLauncher {

    /// A resolved click target: an existing file plus an optional line/column.
    struct FileTarget: Equatable {
        let path: String
        let line: Int?
        let col: Int?
    }

    /// Split a trailing `:line` or `:line:col` suffix off a token. Only trailing
    /// all-digit components are treated as line/col; everything else is the path.
    /// Pure.
    static func parseSuffix(_ token: String) -> (path: String, line: Int?, col: Int?) {
        var parts = token.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return (token, nil, nil) }
        var col: Int?
        var line: Int?
        // Peel an all-digit tail (col first, then line).
        if parts.count >= 3, let c = Int(parts[parts.count - 1]), let _ = Int(parts[parts.count - 2]) {
            col = c
            parts.removeLast()
        }
        if parts.count >= 2, let l = Int(parts[parts.count - 1]) {
            line = l
            parts.removeLast()
        }
        let path = parts.joined(separator: ":")
        return (path.isEmpty ? token : path, line, col)
    }

    /// Resolve a clicked token to an existing file: parse the suffix, take the path
    /// as absolute or relative to `cwd`, and return it only if the file exists.
    static func resolve(token: String, cwd: String, fileManager fm: FileManager = .default) -> FileTarget? {
        let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'()[]<>,"))
        let (rawPath, line, col) = parseSuffix(trimmed)
        var path = (rawPath as NSString).expandingTildeInPath
        if !(path as NSString).isAbsolutePath {
            path = (cwd as NSString).appendingPathComponent(path)
        }
        path = (path as NSString).standardizingPath
        guard fm.fileExists(atPath: path) else { return nil }
        return FileTarget(path: path, line: line, col: col)
    }

    /// Known editors plus a custom-template option.
    enum Editor: String, Codable, CaseIterable, Identifiable {
        case vscode, cursor, xcode, system, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .vscode: return "VS Code"
            case .cursor: return "Cursor"
            case .xcode:  return "Xcode"
            case .system: return "System default"
            case .custom: return "Custom command"
            }
        }
        /// The CLI tool name to look for on PATH (nil = no line-aware CLI).
        var cliTool: String? {
            switch self {
            case .vscode: return "code"
            case .cursor: return "cursor"
            case .xcode:  return "xed"
            default:      return nil
            }
        }
    }

    /// Build the `(tool, args)` to launch for a line-aware editor, or nil when the
    /// editor has no such CLI (→ caller uses the system-open fallback). Pure.
    static func cliInvocation(editor: Editor, target: FileTarget) -> (tool: String, args: [String])? {
        switch editor {
        case .vscode, .cursor:
            let tool = editor.cliTool!
            if let line = target.line {
                return (tool, ["-g", "\(target.path):\(line)\(target.col.map { ":\($0)" } ?? "")"])
            }
            return (tool, [target.path])
        case .xcode:
            if let line = target.line { return ("xed", ["--line", "\(line)", target.path]) }
            return ("xed", [target.path])
        case .system, .custom:
            return nil
        }
    }

    /// Substitute `{file}`/`{line}`/`{col}` in a custom template. Pure.
    static func substitute(template: String, target: FileTarget) -> String {
        template
            .replacingOccurrences(of: "{file}", with: shellQuote(target.path))
            .replacingOccurrences(of: "{line}", with: target.line.map(String.init) ?? "")
            .replacingOccurrences(of: "{col}", with: target.col.map(String.init) ?? "")
    }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: Launch (side-effecting)

    /// Open a resolved target in the chosen editor, falling back to the system
    /// default when the editor's CLI isn't available.
    static func open(_ target: FileTarget, editor: Editor, customTemplate: String) {
        if editor == .custom, !customTemplate.isEmpty {
            runShell(substitute(template: customTemplate, target: target))
            return
        }
        if let inv = cliInvocation(editor: editor, target: target), let toolPath = toolPath(inv.tool) {
            run(toolPath, inv.args)
            return
        }
        // Fallback: open the file with its default app (no line jump).
        NSWorkspace.shared.open(URL(fileURLWithPath: target.path))
    }

    /// Open a directory as a project/folder in the chosen editor.
    static func openDirectory(_ path: String, editor: Editor, customTemplate: String) {
        let target = FileTarget(path: path, line: nil, col: nil)
        if editor == .custom, !customTemplate.isEmpty {
            runShell(substitute(template: customTemplate, target: target)); return
        }
        if let tool = editor.cliTool, let toolPath = toolPath(tool) {
            run(toolPath, [path]); return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: Process helpers

    private static func toolPath(_ name: String) -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        for dir in path.split(separator: ":") {
            let candidate = (String(dir) as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    private static func run(_ tool: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try? p.run()
    }

    private static func runShell(_ command: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", command]
        try? p.run()
    }
}
