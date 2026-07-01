import SwiftUI
import AppKit
import SwiftTerm

/// Bridges SwiftTerm's AppKit `LocalProcessTerminalView` into SwiftUI and wires
/// it to a `SessionModel` (shell spawn, truecolor env, OSC 7 CWD, exit state).
struct TerminalHostView: NSViewRepresentable {
    @ObservedObject var session: SessionModel
    @EnvironmentObject var theme: ThemeManager

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    /// Inner margin so glyphs never touch the (rounded) window edges.
    private let inset: CGFloat = 8

    func makeNSView(context: Context) -> NSView {
        let term = ZTerminalView(frame: .init(x: 0, y: 0, width: 800, height: 480))
        term.processDelegate = context.coordinator
        term.onReveal = { [weak session] in session?.revealInFinder() }
        term.currentDirectory = { [weak session] in session?.cwd ?? NSHomeDirectory() }
        term.onBell = { [weak session] in if let s = session { AttentionManager.shared.bell(for: s) } }
        term.onOpenFolders = { urls in
            if let dir = urls.first?.path { WindowRouter.shared.openInNewTab(dir) }
        }
        term.registerDrag()
        term.installSelectionMonitor()
        session.terminalView = term
        context.coordinator.term = term

        // Command lifecycle markers (OSC 133) → last-command exit + duration.
        // Payload is everything after "133;": "C" (command start) or "D[;<exit>]".
        term.getTerminal().registerOscHandler(code: 133) { [weak session] slice in
            guard let session else { return }
            switch CommandMarker.parse(osc133: String(decoding: slice, as: UTF8.self)) {
            case .start:            session.noteCommandStart()
            case .end(let code):    session.noteCommandEnd(exitCode: code)
            case nil:               break
            }
        }

        // Appearance from the theme; Option behaves as Meta for readline/agents.
        term.nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
        term.font = theme.terminalFont
        term.optionAsMetaKey = true
        applyScheme(theme.effectiveTokens.terminalScheme, to: term)
        applyBackground(to: term)
        context.coordinator.scheme = theme.effectiveTokens.terminalScheme
        context.coordinator.glass = theme.terminalBackgroundIsTranslucent

        // Container gives the terminal an inner margin. In Blur mode it's clear so
        // the gradient shows through; otherwise it's the opaque terminal color.
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = (theme.terminalBackgroundIsTranslucent ? NSColor.clear : theme.terminalBackground).cgColor
        term.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(term)
        NSLayoutConstraint.activate([
            term.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            term.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            term.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            term.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])

        // Spawn the login shell chosen in Settings (default zsh), in the session's dir.
        var shell = theme.tokens.shellPath
        if !FileManager.default.isExecutableFile(atPath: shell) {
            shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        }

        // Guard against an unusable shell so we show an error, not a blank pane.
        guard FileManager.default.isExecutableFile(atPath: shell) else {
            term.feed(text: "\r\n\u{1b}[31mzTerminal: cannot start shell '\(shell)' — not found or not executable.\u{1b}[0m\r\n")
            session.markExited()
            return container
        }

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"     // advertise 24-bit color to programs
        env["TERM_PROGRAM"] = "zTerminal"  // avoid Apple_Terminal's "Restored session" banner
        // "Color" scheme → vibrant prompt + ls/grep/git colorize; "System" → plain.
        if theme.effectiveTokens.terminalScheme == .liquidGlass {
            env.merge(ShellColor.colorEnv) { _, new in new }
            env["ZT_COLORFUL"] = "1"
        }
        // Shell integration: zsh via ZDOTDIR, bash via --rcfile — both source the
        // user's real config first (leaving their own prompt intact), emit OSC 7
        // for reliable CWD tracking, and define the user's script shortcuts.
        // User environment variables: seed the pre-spawn env so lookups before rc
        // sourcing see them. The rc `export` (emitted below, after sourcing the
        // user's rc) is authoritative for override precedence; for unsupported
        // shells that skip the generated rc, this dictionary seed is the fallback.
        let envVars = theme.tokens.envVars
        env.merge(EnvVar.exportDictionary(for: envVars)) { _, new in new }
        var shellArgs = ["-l"]
        let shortcuts = theme.tokens.scriptShortcuts
        if shell.hasSuffix("zsh"), let zdot = ShellColor.makeZDotDir(shortcuts: shortcuts, envVars: envVars) {
            env["ZDOTDIR"] = zdot
        } else if shell.hasSuffix("bash"), let rc = ShellColor.makeBashRC(shortcuts: shortcuts, envVars: envVars) {
            shellArgs = ["--rcfile", rc, "-i"]
        }
        let envArray = env.map { "\($0.key)=\($0.value)" }

        // LocalProcessTerminalView has no cwd parameter; the fork inherits our
        // process cwd, so set it just around startProcess.
        let fm = FileManager.default
        let saved = fm.currentDirectoryPath
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: session.initialDirectory, isDirectory: &isDir), isDir.boolValue {
            fm.changeCurrentDirectoryPath(session.initialDirectory)
        }
        term.startProcess(executable: shell, args: shellArgs, environment: envArray)
        fm.changeCurrentDirectoryPath(saved)

        // Script runner / Finder "open at path + run": inject an initial command.
        // The PTY buffers input until the shell reads it, so sending now is safe.
        if let cmd = session.initialCommand, !cmd.isEmpty {
            term.send(txt: cmd + "\n")
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let term = context.coordinator.term else { return }
        // Live-apply font + background when the theme changes.
        if term.font != theme.terminalFont { term.font = theme.terminalFont }
        if term.nativeBackgroundColor != theme.effectiveTerminalBackground || context.coordinator.glass != theme.terminalBackgroundIsTranslucent {
            applyBackground(to: term)
            nsView.layer?.backgroundColor = (theme.terminalBackgroundIsTranslucent ? NSColor.clear : theme.terminalBackground).cgColor
            context.coordinator.glass = theme.terminalBackgroundIsTranslucent
            term.needsDisplay = true
        }
        if context.coordinator.scheme != theme.effectiveTokens.terminalScheme {
            applyScheme(theme.effectiveTokens.terminalScheme, to: term)
            context.coordinator.scheme = theme.effectiveTokens.terminalScheme
        }
    }

    /// Apply the (possibly translucent) terminal background for the current mode.
    private func applyBackground(to term: ZTerminalView) {
        term.nativeBackgroundColor = theme.effectiveTerminalBackground
        term.wantsLayer = true
        term.layer?.isOpaque = !theme.terminalBackgroundIsTranslucent
        if theme.terminalBackgroundIsTranslucent { term.layer?.backgroundColor = NSColor.clear.cgColor }
    }

    /// Install a vibrant ANSI palette + accent cursor for the Liquid Glass scheme.
    private func applyScheme(_ scheme: TerminalScheme, to term: ZTerminalView) {
        term.caretColor = NSColor(theme.accent)
        guard let hexes = scheme.ansiHexes, hexes.count == 16 else { return }
        term.installColors(hexes.map { hex in
            let v = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
            func c8(_ shift: UInt32) -> UInt16 { UInt16((v >> shift) & 0xFF) * 257 }  // 8-bit → 16-bit
            return SwiftTerm.Color(red: c8(16), green: c8(8), blue: c8(0))
        })
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let session: SessionModel
        weak var term: ZTerminalView?
        var scheme: TerminalScheme?
        var glass: Bool?
        init(session: SessionModel) { self.session = session }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            guard !title.isEmpty else { return }
            DispatchQueue.main.async { self.session.autoTitle = title }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard let directory else { return }
            session.applyHostDirectory(directory)
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            session.markExited()
        }
    }
}
