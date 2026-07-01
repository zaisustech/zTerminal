import Foundation

/// A group of runnable tasks contributed by one ecosystem (Node, Cargo, …).
public struct RunGroup: Identifiable, Equatable {
    public var id: String { title }
    public let title: String
    public let tasks: [RunTask]
    public var managers: [PackageManager] = []   // non-empty only for Node
    public var installCommand: String? = nil     // shown when tasks is empty
    public var error: String? = nil
    public var bookmarks: Bool = false           // the .zTerminal.json "Bookmarks" group
}

/// One ecosystem's detector. `matches` is a cheap file-existence check for
/// toolbar visibility; `detect` does the full parse for the popover.
public protocol TaskSource {
    func matches(in dir: String, fileManager fm: FileManager) -> Bool
    func detect(in dir: String, fileManager fm: FileManager) -> RunGroup?
}

public extension TaskSource {
    func exists(_ file: String, in dir: String, _ fm: FileManager) -> Bool {
        fm.fileExists(atPath: (dir as NSString).appendingPathComponent(file))
    }
}

/// Runs every task source against a directory.
public enum TaskRunner {
    public static let sources: [TaskSource] = [
        ZTerminalTaskSource(),   // project bookmarks — listed first
        NodeTaskSource(), CargoTaskSource(), MavenTaskSource(), GradleTaskSource(),
        PythonTaskSource(), GoTaskSource(), DotNetTaskSource(), DenoTaskSource(),
        RubyTaskSource(), MakeTaskSource(),
    ]

    /// Cheap: is this directory recognized by any source? (toolbar visibility)
    public static func isRecognized(_ dir: String, fileManager fm: FileManager = .default) -> Bool {
        sources.contains { $0.matches(in: dir, fileManager: fm) }
    }

    /// True when the directory has `.zTerminal.json` bookmarks (bookmark button).
    public static func hasBookmarks(_ dir: String, fileManager fm: FileManager = .default) -> Bool {
        ZTerminalTaskSource().matches(in: dir, fileManager: fm)
    }

    /// True when a manifest-based ecosystem is present (the play/script-shortcut
    /// button), independent of `.zTerminal.json` bookmarks.
    public static func hasScriptTasks(_ dir: String, fileManager fm: FileManager = .default) -> Bool {
        sources.contains { !($0 is ZTerminalTaskSource) && $0.matches(in: dir, fileManager: fm) }
    }

    /// Full detection — one group per matching ecosystem.
    public static func detect(in dir: String, fileManager fm: FileManager = .default) -> [RunGroup] {
        sources.compactMap { $0.detect(in: dir, fileManager: fm) }
    }
}

private func task(_ name: String, _ command: String) -> RunTask {
    RunTask(name: name, rawCommand: command, runCommand: command)
}

// MARK: - Node

public struct NodeTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        PackageRunner.hasPackageJSON(in: dir, fileManager: fm)
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard let s = PackageRunner.load(in: dir, fileManager: fm) else { return nil }
        let title = "Node · \(s.manager.rawValue)"
        return RunGroup(title: title, tasks: s.tasks, managers: s.managers,
                         installCommand: s.tasks.isEmpty ? s.manager.installCommand : nil,
                         error: s.error)
    }
}

// MARK: - Rust

public struct CargoTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool { exists("Cargo.toml", in: dir, fm) }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        return RunGroup(title: "Cargo", tasks: [
            task("run", "cargo run"), task("build", "cargo build"),
            task("test", "cargo test"), task("check", "cargo check"),
            task("clippy", "cargo clippy"), task("fmt", "cargo fmt"),
        ])
    }
}

// MARK: - Java / Spring Boot (Maven + Gradle)

public struct MavenTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool { exists("pom.xml", in: dir, fm) }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        let mvn = exists("mvnw", in: dir, fm) ? "./mvnw" : "mvn"
        return RunGroup(title: "Maven", tasks: [
            task("spring-boot:run", "\(mvn) spring-boot:run"),
            task("test", "\(mvn) test"),
            task("package", "\(mvn) package"),
            task("clean install", "\(mvn) clean install"),
        ])
    }
}

public struct GradleTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        exists("build.gradle", in: dir, fm) || exists("build.gradle.kts", in: dir, fm) || exists("gradlew", in: dir, fm)
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        let g = exists("gradlew", in: dir, fm) ? "./gradlew" : "gradle"
        return RunGroup(title: "Gradle", tasks: [
            task("bootRun", "\(g) bootRun"),
            task("build", "\(g) build"),
            task("test", "\(g) test"),
        ])
    }
}

// MARK: - Python

public struct PythonTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        exists("manage.py", in: dir, fm) || exists("pyproject.toml", in: dir, fm) || exists("requirements.txt", in: dir, fm)
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        if exists("manage.py", in: dir, fm) {   // Django
            return RunGroup(title: "Django", tasks: [
                task("runserver", "python manage.py runserver"),
                task("migrate", "python manage.py migrate"),
                task("makemigrations", "python manage.py makemigrations"),
                task("test", "python manage.py test"),
            ])
        }
        var tasks = [task("pytest", "pytest")]
        if exists("requirements.txt", in: dir, fm) {
            tasks.append(task("install", "pip install -r requirements.txt"))
        }
        if exists("pyproject.toml", in: dir, fm) {
            tasks.append(task("build", "python -m build"))
        }
        return RunGroup(title: "Python", tasks: tasks)
    }
}

// MARK: - Go

public struct GoTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool { exists("go.mod", in: dir, fm) }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        return RunGroup(title: "Go", tasks: [
            task("run", "go run ./..."), task("build", "go build ./..."),
            task("test", "go test ./..."), task("vet", "go vet ./..."),
        ])
    }
}

// MARK: - Make

public struct MakeTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        exists("Makefile", in: dir, fm) || exists("makefile", in: dir, fm)
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        let path = exists("Makefile", in: dir, fm)
            ? (dir as NSString).appendingPathComponent("Makefile")
            : (dir as NSString).appendingPathComponent("makefile")
        guard let data = fm.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let targets = MakeTaskSource.parseTargets(text)
        guard !targets.isEmpty else { return nil }
        return RunGroup(title: "Make", tasks: targets.map { task($0, "make \($0)") })
    }

    /// Parse target names from a Makefile: lines like `name:` (not `:=`), skipping
    /// special/pattern targets. Pure + testable.
    public static func parseTargets(_ text: String) -> [String] {
        var out: [String] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
            // Skip variable assignments, recipes (tab-indented), pattern/special targets.
            if line.hasPrefix("\t") || line.hasPrefix(" ") { continue }
            if name.isEmpty || name.hasPrefix(".") || name.contains("%") || name.contains("=") || name.contains("$") { continue }
            if name.contains(" ") { continue }
            let after = line.index(after: colon)
            if after < line.endIndex, line[after] == "=" { continue }  // ":=" assignment
            if !out.contains(name) { out.append(name) }
            if out.count >= 40 { break }
        }
        return out
    }
}

// MARK: - .NET

public struct DotNetTaskSource: TaskSource {
    public init() {}
    private func projectFiles(in dir: String, _ fm: FileManager) -> [String] {
        (try? fm.contentsOfDirectory(atPath: dir))?.filter {
            $0.hasSuffix(".sln") || $0.hasSuffix(".csproj") || $0.hasSuffix(".fsproj") || $0.hasSuffix(".vbproj")
        } ?? []
    }
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        !projectFiles(in: dir, fm).isEmpty
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        return RunGroup(title: ".NET", tasks: [
            task("run", "dotnet run"), task("build", "dotnet build"),
            task("test", "dotnet test"), task("restore", "dotnet restore"),
        ])
    }
}

// MARK: - Deno

public struct DenoTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        exists("deno.json", in: dir, fm) || exists("deno.jsonc", in: dir, fm)
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        var tasks: [RunTask] = []
        let path = exists("deno.json", in: dir, fm)
            ? (dir as NSString).appendingPathComponent("deno.json")
            : (dir as NSString).appendingPathComponent("deno.jsonc")
        if let data = fm.contents(atPath: path),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let defs = obj["tasks"] as? [String: Any] {
            tasks = defs.keys.sorted().map { task($0, "deno task \($0)") }
        }
        tasks.append(task("test", "deno test"))
        return RunGroup(title: "Deno", tasks: tasks)
    }
}

// MARK: - Ruby

public struct RubyTaskSource: TaskSource {
    public init() {}
    public func matches(in dir: String, fileManager fm: FileManager) -> Bool {
        exists("Rakefile", in: dir, fm) || exists("Gemfile", in: dir, fm)
    }
    public func detect(in dir: String, fileManager fm: FileManager) -> RunGroup? {
        guard matches(in: dir, fileManager: fm) else { return nil }
        let hasBundler = exists("Gemfile", in: dir, fm)
        let rake = hasBundler ? "bundle exec rake" : "rake"
        var tasks: [RunTask] = []
        if hasBundler { tasks.append(task("install", "bundle install")) }
        let rakefile = (dir as NSString).appendingPathComponent("Rakefile")
        if let data = fm.contents(atPath: rakefile),
           let text = String(data: data, encoding: .utf8) {
            for name in RubyTaskSource.parseRakeTasks(text) {
                tasks.append(task(name, "\(rake) \(name)"))
            }
        }
        return tasks.isEmpty ? nil : RunGroup(title: "Ruby", tasks: tasks)
    }

    /// Parse `task :name` / `task "name"` declarations from a Rakefile. Pure + testable.
    public static func parseRakeTasks(_ text: String) -> [String] {
        var out: [String] = []
        let pattern = #"(?m)^\s*task\s+[:"']([A-Za-z0-9_:-]+)"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = text as NSString
        re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            if let m, m.numberOfRanges > 1 {
                let name = ns.substring(with: m.range(at: 1))
                if !out.contains(name) { out.append(name) }
            }
        }
        return Array(out.prefix(30))
    }
}
