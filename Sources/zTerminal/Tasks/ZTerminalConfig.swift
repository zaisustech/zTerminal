import Foundation

/// One project bookmark: a named shell command with an SF Symbol icon. Runs
/// verbatim (shell semantics — `&&`, pipes, redirects all allowed).
public struct Bookmark: Codable, Equatable, Identifiable {
    public var id: String { name + "\u{1}" + command }
    public var name: String
    public var command: String
    public var icon: String        // SF Symbol name; defaults to a star when absent.
    public var color: String?      // hex tint for the icon; nil = use the app accent.

    public init(name: String, command: String, icon: String = Bookmark.defaultIcon, color: String? = nil) {
        self.name = name
        self.command = command
        self.icon = icon
        self.color = color
    }

    public static let defaultIcon = "star.fill"

    private enum CodingKeys: String, CodingKey { case name, command, icon, color }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        command = try c.decode(String.self, forKey: .command)
        let raw = (try c.decodeIfPresent(String.self, forKey: .icon))?
            .trimmingCharacters(in: .whitespaces)
        icon = (raw?.isEmpty == false) ? raw! : Bookmark.defaultIcon
        let rawColor = (try c.decodeIfPresent(String.self, forKey: .color))?
            .trimmingCharacters(in: .whitespaces)
        color = (rawColor?.isEmpty == false) ? rawColor : nil
    }
}

/// An optional per-project theme override. Every field is optional and merged over
/// the user's base theme; nothing here is persisted to the user's Settings.
public struct ProjectTheme: Codable, Equatable {
    public var mode: String?                 // "system" | "light" | "dark" | "glass"
    public var accentHex: String?
    public var gradientHexes: [String]?
    public var terminalScheme: String?       // "liquidGlass" | "system"
    public var terminalBackgroundHex: String?
    public var terminalFontName: String?
    public var terminalFontSize: Double?
    public var glassOpacity: Double?
    public var blur: Double?
    public var cornerRadius: Double?
    public var animationSpeed: Double?

    /// True when nothing was specified (treated as "no override").
    public var isEmpty: Bool {
        mode == nil && accentHex == nil && gradientHexes == nil && terminalScheme == nil
            && terminalBackgroundHex == nil && terminalFontName == nil && terminalFontSize == nil
            && glassOpacity == nil && blur == nil && cornerRadius == nil && animationSpeed == nil
    }

    /// Layer `top` over `base` — each field in `top` wins when present, otherwise
    /// the `base` value shows through. Returns nil only when both are absent.
    /// Used to cascade the project theme over the global (`~/.zTerminal.json`) theme.
    public static func combine(_ top: ProjectTheme?, over base: ProjectTheme?) -> ProjectTheme? {
        guard top != nil || base != nil else { return nil }
        var r = base ?? ProjectTheme()
        guard let t = top else { return r }
        if let v = t.mode { r.mode = v }
        if let v = t.accentHex { r.accentHex = v }
        if let v = t.gradientHexes { r.gradientHexes = v }
        if let v = t.terminalScheme { r.terminalScheme = v }
        if let v = t.terminalBackgroundHex { r.terminalBackgroundHex = v }
        if let v = t.terminalFontName { r.terminalFontName = v }
        if let v = t.terminalFontSize { r.terminalFontSize = v }
        if let v = t.glassOpacity { r.glassOpacity = v }
        if let v = t.blur { r.blur = v }
        if let v = t.cornerRadius { r.cornerRadius = v }
        if let v = t.animationSpeed { r.animationSpeed = v }
        return r
    }
}

/// The `.zTerminal.json` project config: bookmarked commands + an optional theme.
public struct ZTerminalConfig: Codable, Equatable {
    public var bookmarks: [Bookmark]
    public var theme: ProjectTheme?

    public init(bookmarks: [Bookmark] = [], theme: ProjectTheme? = nil) {
        self.bookmarks = bookmarks
        self.theme = theme
    }

    private enum CodingKeys: String, CodingKey { case bookmarks, theme }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookmarks = (try c.decodeIfPresent([Bookmark].self, forKey: .bookmarks)) ?? []
        theme = try c.decodeIfPresent(ProjectTheme.self, forKey: .theme)
    }

    // MARK: - Location

    public static let filename = ".zTerminal.json"

    public static func path(in dir: String) -> String {
        (dir as NSString).appendingPathComponent(filename)
    }

    public static func exists(in dir: String, fileManager fm: FileManager = .default) -> Bool {
        fm.fileExists(atPath: path(in: dir))
    }

    // MARK: - Load / save

    /// Load the config, or nil when the file is missing or cannot be parsed. A
    /// malformed file returns nil rather than throwing so callers never crash.
    public static func load(in dir: String, fileManager fm: FileManager = .default) -> ZTerminalConfig? {
        let p = path(in: dir)
        guard fm.fileExists(atPath: p), let data = fm.contents(atPath: p) else { return nil }
        return try? JSONDecoder().decode(ZTerminalConfig.self, from: data)
    }

    /// Write the config to `dir/.zTerminal.json` as pretty, stable JSON.
    public func save(in dir: String) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(self)
        try data.write(to: URL(fileURLWithPath: ZTerminalConfig.path(in: dir)), options: .atomic)
    }

    /// Append a bookmark to the project's config, creating the file if needed.
    public static func addBookmark(_ bookmark: Bookmark, in dir: String,
                                   fileManager fm: FileManager = .default) throws {
        var config = load(in: dir, fileManager: fm) ?? ZTerminalConfig()
        config.bookmarks.append(bookmark)
        try config.save(in: dir)
    }

    /// Replace the bookmark at `index` with `bookmark`. No-op if out of range.
    public static func updateBookmark(at index: Int, to bookmark: Bookmark, in dir: String,
                                      fileManager fm: FileManager = .default) throws {
        guard var config = load(in: dir, fileManager: fm), config.bookmarks.indices.contains(index) else { return }
        config.bookmarks[index] = bookmark
        try config.save(in: dir)
    }

    /// Remove the bookmark at `index`. No-op if out of range.
    public static func removeBookmark(at index: Int, in dir: String,
                                      fileManager fm: FileManager = .default) throws {
        guard var config = load(in: dir, fileManager: fm), config.bookmarks.indices.contains(index) else { return }
        config.bookmarks.remove(at: index)
        try config.save(in: dir)
    }
}

/// Run-time argument placeholders in a command, written `<label>`. A bookmark like
/// `expo prebuild --platform <platform>` prompts for `platform` before running.
public enum CommandTemplate {
    /// Ordered, de-duplicated placeholder labels found in a command.
    public static func placeholders(in command: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: "<([^<>]+)>") else { return [] }
        let ns = command as NSString
        var out: [String] = []
        re.enumerateMatches(in: command, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m, m.numberOfRanges > 1 else { return }
            let label = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if !label.isEmpty, !out.contains(label) { out.append(label) }
        }
        return out
    }

    /// Substitute `<label>` occurrences with the supplied values (verbatim).
    /// Placeholders without a value are left untouched.
    public static func substitute(_ command: String, values: [String: String]) -> String {
        var out = command
        for (label, value) in values {
            out = out.replacingOccurrences(of: "<\(label)>", with: value)
        }
        return out
    }
}

/// A `TaskSource` that contributes a project's `.zTerminal.json` bookmarks as a
/// "Bookmarks" group. Registered first so it renders at the top of the popover.
public struct ZTerminalTaskSource: TaskSource {
    public init() {}

    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        ZTerminalConfig.exists(in: dir, fileManager: fm)
    }

    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard ZTerminalConfig.exists(in: dir, fileManager: fm) else { return nil }
        // Present the group even when empty so the "Add bookmark" affordance shows.
        let config = ZTerminalConfig.load(in: dir, fileManager: fm) ?? ZTerminalConfig()
        let tasks = config.bookmarks.map {
            RunTask(name: $0.name, rawCommand: $0.command, runCommand: $0.command,
                    icon: $0.icon, iconColorHex: $0.color)
        }
        return RunGroup(title: "Bookmarks", tasks: tasks, bookmarks: true)
    }
}
