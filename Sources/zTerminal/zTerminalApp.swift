import SwiftUI
import AppKit
import CoreText

@main
struct zTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = WindowModel()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        // A single `Window` scene, deliberately not `WindowGroup`: the app shares
        // one WindowModel, and WindowGroup mints an extra window per URL open
        // (zterminal:// / Finder), double-mounting every session — which spawned
        // duplicate shells and re-attached search to an invisible terminal.
        Window("zTerminal", id: "main") {
            RootView(model: model)
                .environmentObject(theme)
                .onAppear { appDelegate.attach(model) }
                .onOpenURL { url in
                    // zterminal://open?path=... — validated before use.
                    if let dir = CwdLogic.openPath(fromURL: url) {
                        model.open(directory: dir)
                    }
                    // zterminal://preview?path=... — Markdown preview tab.
                    if let file = PreviewLogic.previewPath(fromURL: url) {
                        model.openPreview(url: URL(fileURLWithPath: file), split: false)
                    }
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") { model.addTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") { if let id = model.activeID { model.close(id) } }
                    .keyboardShortcut("w", modifiers: .command)
                Button("Command Palette…") {
                    NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                // Clear moved to ⌘⌥K so the palette can own ⌘K (per the spec).
                Button("Clear") { model.active?.clear() }
                    .keyboardShortcut("k", modifiers: [.command, .option])
                Button("Toggle File Explorer") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
                Divider()
                Button("Open Markdown Preview…") { openMarkdownPreview() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Print…") {
                    guard let active = model.active else { return }
                    if let panel = active.preview, active.kind == .preview || panel.isFocused,
                       let doc = panel.activeDoc {
                        PreviewExport.printDocument(model: doc)
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
                Divider()
                Button("Zoom In") { theme.zoomFont(by: 1) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { theme.zoomFont(by: -1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { theme.resetFontSize() }
                    .keyboardShortcut("0", modifiers: .command)
                Button("Quick Look Selection") { model.active?.terminalView?.quickLookSelection() }
                    .keyboardShortcut("y", modifiers: .command)
                Button("Keep Awake: \(theme.tokens.keepAwake.label)") {
                    theme.tokens.keepAwake = theme.tokens.keepAwake.next
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                Divider()
                // ⌘1..9 and ⌃1..9 both switch to tab N.
                ForEach(1...9, id: \.self) { n in
                    Button("Select Tab \(n)") { model.selectIndex(n - 1) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                    Button("Select Tab \(n) (⌃)") { model.selectIndex(n - 1) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .control)
                }
            }
            // Edit ▸ Search (⌘F) — routes by focus: preview tabs and focused preview
            // panes get the in-page document search, the terminal gets the find bar.
            CommandGroup(after: .textEditing) {
                Button("Search") {
                    guard let active = model.active else { return }
                    if active.kind == .code || active.code != nil {
                        NotificationCenter.default.post(name: .codeFind, object: nil)
                    }
                    else if active.kind == .preview { active.preview?.find() }
                    else if let pane = active.preview, pane.isFocused { pane.find() }
                    else { active.search.open() }
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Welcome to zTerminal") {
                    NotificationCenter.default.post(name: .showWelcome, object: nil)
                }
                Button("Markdown Preview Streaming Demo") {
                    PreviewStreamDemo.run(in: model)
                }
            }
            // Replace the default (fixed) Settings scene with our resizable window.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowController.shared.theme = theme
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    /// File → Open Markdown Preview…: pick a .md file, open it split beside the
    /// active terminal (falls back to a dedicated tab when there is none).
    private func openMarkdownPreview() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText,
                                     .init(filenameExtension: "markdown") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Markdown file to preview"
        if panel.runModal() == .OK, let url = panel.url {
            model.openPreview(url: url)
        }
    }
}

/// Ensures the app activates as a regular GUI app (relevant when launched as a
/// bare SPM binary rather than from a bundled .app) and holds the model for URL
/// handling / activation.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) weak var model: WindowModel?

    /// Files opened before the SwiftUI window attached the model (app launched
    /// by double-clicking a document) — flushed in `attach`.
    private var pendingPreviewFiles: [URL] = []

    func attach(_ model: WindowModel) {
        self.model = model
        pendingPreviewFiles.forEach { model.openPreview(url: $0, split: false) }
        pendingPreviewFiles.removeAll()
    }

    /// Finder double-click / "Open With" on a Markdown document (declared in
    /// Info.plist CFBundleDocumentTypes) — open it in a preview tab.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL {
            guard PreviewLogic.validateMarkdownPath(url.path) != nil else { continue }
            if let model {
                model.openPreview(url: url, split: false)
            } else {
                pendingPreviewFiles.append(url)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.registerBundledFonts()            // make the bundled Nerd Font available
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.servicesProvider = self          // enables the "Open in zTerminal" Services entry
        AttentionManager.shared.requestAuthorization()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AttentionManager.shared.markActive(model?.active)   // returning clears the badge
    }

    /// Register any `.ttf` bundled under Resources (root or a Fonts/ subfolder)
    /// so `NSFont(name:)` can resolve the bundled Nerd Font.
    static func registerBundledFonts() {
        guard let res = Bundle.main.resourceURL else { return }
        let fm = FileManager.default
        var urls: [URL] = []
        for dir in [res.appendingPathComponent("Fonts"), res] {
            urls += (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        }
        for url in urls where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.terminateAll()                  // no orphan shells on quit
    }

    /// Services provider — right-click a selected folder → Services → "Open in zTerminal".
    /// Wired to NSServices `NSMessage = openFolderInZTerminal` in Info.plist.
    @objc func openFolderInZTerminal(_ pboard: NSPasteboard, userData: String?,
                                     error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self],
                                            options: [.urlReadingFileURLsOnly: true]) as? [URL]
        else { return }
        let folder = urls.first { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
                     ?? urls.first
        if let dir = folder?.path, let valid = CwdLogic.validateOpenPath(dir) {
            WindowRouter.shared.openInNewTab(valid)
        }
    }
}
