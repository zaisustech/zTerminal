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
        // Idempotent mount: if this session already has a live terminal (SwiftUI
        // recreated the representable, or the window tree mounted twice), REUSE
        // it — never spawn a second shell for the same session.
        if let existing = session.terminalView, existing.process?.shellPid ?? 0 > 0 {
            context.coordinator.term = existing
            return Self.wrapInContainer(existing, inset: inset, theme: theme)
        }
        let term = ZTerminalView(frame: .init(x: 0, y: 0, width: 800, height: 480))
        term.processDelegate = context.coordinator
        term.onReveal = { [weak session] in session?.revealInFinder() }
        term.currentDirectory = { [weak session] in session?.cwd ?? NSHomeDirectory() }
        term.onBell = { [weak session] in if let s = session { AttentionManager.shared.bell(for: s) } }
        term.onOpenFolders = { urls in
            if let dir = urls.first?.path { WindowRouter.shared.openInNewTab(dir) }
        }
        term.onOpenMarkdown = { urls in
            // One file follows the Settings open-mode; several files each get
            // their own preview tab (terminal-tab style).
            WindowRouter.shared.openMarkdownPreviews(urls)
        }
        term.registerDrag()
        term.installSelectionMonitor()
        session.terminalView = term
        context.coordinator.term = term
        session.search.attach(to: term)

        // ⌘-click a file path → open it in the configured editor at the parsed line.
        term.onCommandClickToken = { [weak theme] token, cwd in
            guard let theme,
                  let target = EditorLauncher.resolve(token: token, cwd: cwd) else { return }
            let editor = EditorLauncher.Editor(rawValue: theme.tokens.editor) ?? .system
            EditorLauncher.open(target, editor: editor, customTemplate: theme.tokens.editorCommand)
        }

        // Inline ghost autosuggestion: complete package.json scripts for the
        // project's detected package manager (npm/pnpm/yarn/bun), at an idle
        // prompt, accepted with Tab. Pluggable — more sources can be appended.
        // Ghost sources in priority order: project script completion first
        // (context-specific, fast-rejects unless the line starts with a package
        // manager), then global command history (fish-style prefix match).
        term.suggestionEngine = SuggestionEngine(sources: [ScriptCompletionSource(),
                                                           CommandHistorySource()])
        term.isIdleAtPrompt = { [weak session] in session?.isIdleAtPrompt ?? true }
        term.notifyUpdateChanges = true   // enable rangeChanged callbacks for reposition
        term.installKeyMonitor()

        // Command lifecycle markers (OSC 133) → last-command exit + duration, plus
        // the prompt-end (B) marker that anchors the autosuggestion input column.
        // Payload is everything after "133;": "C" (start), "D[;<exit>]" (end), "B".
        // Markdown preview requests from the `markdown`/`md` shell functions
        // (OSC 7773, defined in ShellColor.markdownPreviewBlock).
        term.getTerminal().registerOscHandler(code: 7773) { slice in
            let payload = String(decoding: slice, as: UTF8.self)
            guard let request = PreviewLogic.previewRequest(fromOSC: payload) else { return }
            WindowRouter.shared.openMarkdownPreview(URL(fileURLWithPath: request.path),
                                                    split: request.split)
        }

        term.getTerminal().registerOscHandler(code: 133) { [weak session, weak term] slice in
            switch CommandMarker.parse(osc133: String(decoding: slice, as: UTF8.self)) {
            case .start(let cmd):   session?.noteCommandStart(command: cmd)
            case .end(let code):    session?.noteCommandEnd(exitCode: code)
            case .promptEnd:
                term?.notePromptEnd()
                session?.flushInitialCommand()   // shell is at a real prompt now
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
        let container = Self.wrapInContainer(term, inset: inset, theme: theme)

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

        // Spawn directly in the tab's directory: the CHILD chdirs after fork
        // (SwiftTerm `currentDirectory`), so concurrent tab spawns can't race
        // on the app-global cwd and an unexpanded/missing path falls back to
        // the inherited cwd explicitly.
        let fm = FileManager.default
        let spawnDir = (session.initialDirectory as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        let validDir = fm.fileExists(atPath: spawnDir, isDirectory: &isDir) && isDir.boolValue
            ? spawnDir : nil
        term.startProcess(executable: shell, args: shellArgs, environment: envArray,
                          currentDirectory: validDir)

        // Script runner / bookmarks / Finder "open at path + run": the initial
        // command is deferred to the first shell prompt (OSC 133;B) instead of
        // being written into the PTY at spawn — early input can be silently
        // flushed by rc files (stty/instant-prompt) before the shell ever reads
        // it, which left bookmark `cd`s unexecuted. A timer covers shells
        // without our OSC integration.
        if session.initialCommand?.isEmpty == false {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak session] in
                session?.flushInitialCommand()
            }
        }

        // QA / demo hook: with `ZT_QA_SEARCH=<term>` set, seed deterministic sample
        // output straight into the emulator and open the find bar on that term. Lets
        // CLI screenshot tooling verify the search overlay without Accessibility
        // (keystroke injection) permission. No-op unless the env var is set.
        if let q = ProcessInfo.processInfo.environment["ZT_QA_SEARCH"], !q.isEmpty {
            term.feed(text: "\r\n\u{1b}[1mzTerminal search QA sample\u{1b}[0m\r\n")
            for i in 1...40 {
                term.feed(text: "line \(i): connecting to database — query executed, closing database\r\n")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                session.search.open()
                session.search.setQuery(q)
            }
            // Diagnosis line for CLI runs: state of the whole pipeline after the
            // debounce has fired (read from stderr by QA tooling).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak term] in
                guard let term else { return }
                let t = term.getTerminal()
                let firstNonEmpty = (0 ..< t.bufferLineCount)
                    .compactMap { t.bufferLine(atIndex: $0)?.translateToString(trimRight: true) }
                    .first { !$0.isEmpty } ?? "<all empty>"
                NSLog("ZT_QA_SEARCH diagnosis: active=%d total=%d bufferLines=%d alt=%d firstLine=%@",
                      session.search.isActive ? 1 : 0, session.search.total,
                      t.bufferLineCount, t.isCurrentBufferAlternate ? 1 : 0, firstNonEmpty)
            }
        }

        return container
    }

    /// Inset container around the terminal view. Also used by the idempotent
    /// remount path, so it detaches the terminal from any previous container.
    static func wrapInContainer(_ term: ZTerminalView, inset: CGFloat,
                                theme: ThemeManager) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = (theme.terminalBackgroundIsTranslucent ? NSColor.clear : theme.terminalBackground).cgColor
        term.removeFromSuperview()
        term.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(term)
        NSLayoutConstraint.activate([
            term.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            term.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            term.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            term.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])
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
