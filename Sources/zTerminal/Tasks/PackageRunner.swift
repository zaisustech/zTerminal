import Foundation

/// A runnable project task (npm script) surfaced by a `TaskSource`.
public struct RunTask: Identifiable, Equatable {
    public var id: String { name }
    public let name: String          // script name, e.g. "dev"
    public let rawCommand: String    // the command it runs (for preview)
    public let runCommand: String    // what we execute, e.g. "pnpm run dev"
    public let icon: String?         // optional SF Symbol (project bookmarks)
    public let iconColorHex: String? // optional per-bookmark icon tint (nil = accent)

    public init(name: String, rawCommand: String, runCommand: String,
                icon: String? = nil, iconColorHex: String? = nil) {
        self.name = name
        self.rawCommand = rawCommand
        self.runCommand = runCommand
        self.icon = icon
        self.iconColorHex = iconColorHex
    }
}

/// Node package managers we can detect and run scripts with.
public enum PackageManager: String, Equatable {
    case npm, pnpm, yarn, bun

    /// Prefix used to run a named script.
    public func runCommand(for script: String) -> String {
        switch self {
        case .npm:  return "npm run \(script)"
        case .pnpm: return "pnpm run \(script)"
        case .yarn: return "yarn \(script)"   // yarn omits "run"
        case .bun:  return "bun run \(script)"
        }
    }

    public var installCommand: String {
        switch self {
        case .npm: return "npm install"
        case .pnpm: return "pnpm install"
        case .yarn: return "yarn"
        case .bun: return "bun install"
        }
    }

    /// Whether `<manager> <script>` runs a package.json script without an explicit
    /// `run` word. bun/pnpm/yarn do; npm requires `npm run <script>`. Used by
    /// inline script completion to know which positions are a script slot.
    public var runsScriptsBare: Bool {
        switch self {
        case .npm:               return false
        case .pnpm, .yarn, .bun: return true
        }
    }
}

/// Result of scanning a directory's `package.json`.
public struct PackageScripts: Equatable {
    public let manager: PackageManager        // the preferred/default manager
    public let managers: [PackageManager]     // every manager detected (≥1)
    public let tasks: [RunTask]
    public let error: String?                 // non-nil when package.json is malformed
}

/// Pure, testable logic for detecting the package manager and reading scripts.
public enum PackageRunner {

    public static func packageJSONPath(in dir: String) -> String {
        (dir as NSString).appendingPathComponent("package.json")
    }

    public static func hasPackageJSON(in dir: String, fileManager fm: FileManager = .default) -> Bool {
        fm.fileExists(atPath: packageJSONPath(in: dir))
    }

    /// Detect the preferred package manager: `packageManager` field first, then
    /// lockfiles, else npm.
    public static func detectManager(in dir: String,
                                     packageJSON: [String: Any]? = nil,
                                     fileManager fm: FileManager = .default) -> PackageManager {
        detectManagers(in: dir, packageJSON: packageJSON, fileManager: fm).first ?? .npm
    }

    /// Detect *all* package managers present (via the `packageManager` field and
    /// each lockfile), in preferred order. Always returns at least `[.npm]`.
    public static func detectManagers(in dir: String,
                                      packageJSON: [String: Any]? = nil,
                                      fileManager fm: FileManager = .default) -> [PackageManager] {
        var found: [PackageManager] = []
        func add(_ m: PackageManager) { if !found.contains(m) { found.append(m) } }

        if let pm = packageJSON?["packageManager"] as? String {
            let name = pm.split(separator: "@").first.map(String.init)?.lowercased() ?? ""
            if let m = PackageManager(rawValue: name) { add(m) }
        }
        func exists(_ f: String) -> Bool { fm.fileExists(atPath: (dir as NSString).appendingPathComponent(f)) }
        if exists("bun.lockb") || exists("bun.lock") { add(.bun) }
        if exists("pnpm-lock.yaml") { add(.pnpm) }
        if exists("yarn.lock") { add(.yarn) }
        if exists("package-lock.json") || exists("npm-shrinkwrap.json") { add(.npm) }

        return found.isEmpty ? [.npm] : found
    }

    /// Load scripts from the directory's `package.json`. Returns nil when there is
    /// no `package.json`; returns a result with `error` set when it is malformed.
    public static func load(in dir: String, fileManager fm: FileManager = .default) -> PackageScripts? {
        let path = packageJSONPath(in: dir)
        guard fm.fileExists(atPath: path) else { return nil }
        guard let data = fm.contents(atPath: path) else {
            return PackageScripts(manager: .npm, managers: [.npm], tasks: [], error: "Could not read package.json")
        }
        let json = try? JSONSerialization.jsonObject(with: data)
        guard let obj = json as? [String: Any] else {
            let mgrs = detectManagers(in: dir, fileManager: fm)
            return PackageScripts(manager: mgrs[0], managers: mgrs,
                                  tasks: [], error: "Could not parse package.json")
        }
        let managers = detectManagers(in: dir, packageJSON: obj, fileManager: fm)
        let manager = managers[0]
        let scripts = (obj["scripts"] as? [String: Any]) ?? [:]
        let tasks = scripts.compactMap { key, value -> RunTask? in
            guard let cmd = value as? String else { return nil }
            return RunTask(name: key, rawCommand: cmd, runCommand: manager.runCommand(for: key))
        }.sorted { $0.name < $1.name }
        return PackageScripts(manager: manager, managers: managers, tasks: tasks, error: nil)
    }
}
