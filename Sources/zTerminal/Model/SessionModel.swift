import Foundation
import SwiftUI
import AppKit
import SwiftTerm
import Darwin

/// The exit code and wall-clock duration of the most recently finished command,
/// derived from OSC 133 `C`/`D` markers emitted by the shell integration.
struct CommandResult: Equatable {
    var exitCode: Int
    var duration: TimeInterval
    var succeeded: Bool { exitCode == 0 }
}

/// An OSC 133 semantic-prompt marker we act on.
enum CommandMarker: Equatable {
    case start                    // 133;C — command began running
    case end(exitCode: Int)       // 133;D[;<exit>] — command finished

    /// Parse an OSC 133 payload (the bytes after "133;"): "C", "D", "D;0".
    /// Returns nil for the prompt markers (A/B) we ignore.
    static func parse(osc133 payload: String) -> CommandMarker? {
        switch payload.first {
        case "C": return .start
        case "D":
            let parts = payload.split(separator: ";")
            return .end(exitCode: parts.count > 1 ? (Int(parts[1]) ?? 0) : 0)
        default: return nil
        }
    }
}

/// One terminal session: a PTY-backed SwiftTerm view, its live CWD, a start
/// time and duration timer, and shell-exit state. Each tab owns one of these.
final class SessionModel: ObservableObject, Identifiable {
    let id = UUID()

    /// Directory the shell is spawned in (from `$HOME`, an inheriting new tab,
    /// or Finder / script-runner integration).
    let initialDirectory: String

    /// An optional command to run once the shell is ready (script runner).
    let initialCommand: String?

    @Published var autoTitle: String      // derived from program / directory
    @Published var customTitle: String?   // user-set (double-click to rename); overrides auto
    @Published var cwd: String            // raw filesystem path
    @Published var cwdHost: String = ""   // OSC 7 host ("" = local)
    @Published var startedAt: Date
    @Published var elapsed: TimeInterval = 0
    @Published var isRunning: Bool = true // false once the shell exits
    @Published var gitStatus: GitStatus?  // nil = not a git repo (segment hidden)
    @Published var foreground: String?    // running program name (nil = at prompt)
    @Published var lastCommand: CommandResult?  // exit + duration of last command
    @Published var envBadges: [EnvBadge] = []   // active runtime(s) for the cwd
    private var wasIdle = true            // for busy → idle refresh detection
    private var sawOSC7 = false           // once true, OSC 7 is authoritative
    private var commandStartedAt: Date?   // set on OSC 133;C, cleared on 133;D

    /// The SwiftTerm view backing this session (created lazily by the host view).
    weak var terminalView: ZTerminalView?

    private var fallbackTimer: Timer?

    /// Reveal this session's CWD in Finder (local dirs only).
    func revealInFinder() {
        guard isRevealable else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: cwd)])
    }

    /// Clear the terminal window (Cmd+K / context menu).
    func clear() { terminalView?.clearWindow() }

    /// True when the shell (not a foreground program) owns the tty — i.e. we can
    /// safely inject a command. Defaults to true if it can't be determined.
    var isIdleAtPrompt: Bool {
        guard let tv = terminalView, let p = tv.process, p.shellPid > 0 else { return true }
        if let pg = ForegroundCwd.foregroundPGID(fd: p.childfd) { return pg == p.shellPid }
        return true
    }

    /// Run a command in this session by sending it to the shell.
    func run(command: String) { terminalView?.send(txt: command + "\n") }

    /// Terminate the shell process (tab close / app quit) so no orphan remains.
    func terminate() {
        stopTimer()
        fallbackTimer?.invalidate()
        if let pid = terminalView?.process?.shellPid, pid > 0 {
            kill(pid, SIGHUP)
        }
    }


    private var timer: Timer?

    init(initialDirectory: String, initialCommand: String? = nil, title: String? = nil) {
        self.initialDirectory = initialDirectory
        self.initialCommand = initialCommand
        self.cwd = initialDirectory
        self.startedAt = Date()
        self.autoTitle = title ?? SessionModel.deriveTitle(from: initialDirectory)
        startTimer()
        startFallbackPolling()
        refreshGit()
    }

    // MARK: - Display helpers

    /// The name shown on the tab: a user-set title if present, else the auto title.
    var displayTitle: String {
        if let c = customTitle, !c.isEmpty { return c }
        return autoTitle
    }

    /// Rename the tab. An empty name clears the custom title (reverts to auto).
    func rename(_ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        customTitle = t.isEmpty ? nil : t
    }

    var displayCWD: String {
        CwdLogic.abbreviatingHome(cwd, home: NSHomeDirectory())
    }

    /// Whether the folder icon should reveal the CWD (local, existing dir).
    var isRevealable: Bool {
        guard isLocalCWD else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: cwd, isDirectory: &isDir) && isDir.boolValue
    }

    var isLocalCWD: Bool {
        CwdLogic.isLocalHost(cwdHost, localNames: SessionModel.localHostNames)
    }

    static func deriveTitle(from path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? "zsh" : name
    }

    static let localHostNames: Set<String> = {
        var names: Set<String> = ["localhost", "127.0.0.1"]
        names.insert(ProcessInfo.processInfo.hostName)
        if let h = Host.current().localizedName { names.insert(h) }
        names.formUnion(Host.current().names)
        return names
    }()

    // MARK: - CWD updates

    /// Apply an OSC 7 directory reported by SwiftTerm.
    func applyHostDirectory(_ raw: String) {
        guard let parsed = CwdLogic.parseOSC7(raw) else { return }
        DispatchQueue.main.async {
            self.sawOSC7 = true            // OSC 7 wins; stop the fallback poll
            self.cwdHost = parsed.host
            let changed = self.cwd != parsed.path
            self.cwd = parsed.path
            self.autoTitle = SessionModel.deriveTitle(from: parsed.path)
            if changed { self.refreshGit() }
        }
    }

    /// Recompute git state + env badges off-main and publish them.
    func refreshGit() {
        let dir = cwd
        guard isLocalCWD else {
            DispatchQueue.main.async { self.gitStatus = nil; self.envBadges = [] }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let status = Git.status(for: dir)
            let badges = EnvInfo.badges(for: dir)
            DispatchQueue.main.async {
                guard self.cwd == dir else { return }
                if self.gitStatus != status { self.gitStatus = status }
                if self.envBadges != badges { self.envBadges = badges }
            }
        }
    }

    /// Local branch names for the current repo (current-first), computed off-main.
    func fetchBranches(_ completion: @escaping ([String]) -> Void) {
        let dir = cwd
        DispatchQueue.global(qos: .userInitiated).async {
            let names = Git.branches(in: dir)
            DispatchQueue.main.async { completion(names) }
        }
    }

    // MARK: - Command markers (OSC 133)

    /// OSC 133;C — a command started running. Begin timing; hide the last result.
    func noteCommandStart() {
        DispatchQueue.main.async {
            self.commandStartedAt = Date()
            self.lastCommand = nil
        }
    }

    /// OSC 133;D;<exit> — the running command finished. Publish exit + duration.
    /// Ignored when no command was started (e.g. the prompt's initial marker or
    /// pressing return on an empty line).
    func noteCommandEnd(exitCode: Int) {
        DispatchQueue.main.async {
            guard let started = self.commandStartedAt else { return }
            self.commandStartedAt = nil
            self.lastCommand = CommandResult(exitCode: exitCode,
                                             duration: Date().timeIntervalSince(started))
        }
    }

    // MARK: - Lifecycle

    func markExited() {
        DispatchQueue.main.async {
            self.isRunning = false
            self.stopTimer()             // duration timer stops when the shell exits
            self.fallbackTimer?.invalidate()   // no need to keep polling a dead shell
        }
    }

    private func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.elapsed = Date().timeIntervalSince(self.startedAt)
            // Refresh git when the shell returns to a prompt (command finished).
            let idle = self.isIdleAtPrompt
            if idle && !self.wasIdle { self.refreshGit() }
            self.wasIdle = idle
            self.updateForeground(idle: idle)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Publish the name of the foreground program (nil when the shell owns the
    /// tty, i.e. we're at a prompt). Uses the tty's foreground process group.
    private func updateForeground(idle: Bool) {
        var name: String?
        if !idle, let tv = terminalView, let p = tv.process, p.shellPid > 0,
           let pg = ForegroundCwd.foregroundPGID(fd: p.childfd), pg != p.shellPid {
            name = ForegroundCwd.processName(pid: pg)
        }
        if foreground != name { foreground = name }
    }

    /// While OSC 7 has not been seen, resolve the CWD from the tty's foreground
    /// process group. Keeps the last-known value if the query is denied.
    private func startFallbackPolling() {
        let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self, self.isRunning, !self.sawOSC7,
                  let tv = self.terminalView, let proc = tv.process, proc.shellPid > 0
            else { return }
            if let dir = ForegroundCwd.resolve(ttyFD: proc.childfd, shellPID: proc.shellPid),
               dir != self.cwd, dir != "/" {
                self.cwd = dir
                self.autoTitle = SessionModel.deriveTitle(from: dir)
                self.refreshGit()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        fallbackTimer = t
    }

    deinit { stopTimer(); fallbackTimer?.invalidate() }
}
