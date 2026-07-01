import SwiftUI
import AppKit
import CoreText

@main
struct zTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = WindowModel()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .environmentObject(theme)
                .onAppear { appDelegate.attach(model) }
                .onOpenURL { url in
                    // zterminal://open?path=... — validated before use.
                    if let dir = CwdLogic.openPath(fromURL: url) {
                        model.open(directory: dir)
                    }
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") { model.addTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") { if let id = model.activeID { model.close(id) } }
                    .keyboardShortcut("w", modifiers: .command)
                Button("Clear") { model.active?.clear() }
                    .keyboardShortcut("k", modifiers: .command)
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
                // Cmd+1..9 switch tabs.
                ForEach(1...9, id: \.self) { n in
                    Button("Select Tab \(n)") { model.selectIndex(n - 1) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                }
            }
            CommandGroup(replacing: .help) {
                Button("Welcome to zTerminal") {
                    NotificationCenter.default.post(name: .showWelcome, object: nil)
                }
            }
        }

        // ⌘, Settings — the full Liquid Glass theme customizer.
        Settings {
            SettingsView().environmentObject(theme)
        }
        .windowResizability(.contentMinSize)   // user-resizable down to the content's min
        .defaultSize(width: 620, height: 620)
    }
}

/// Ensures the app activates as a regular GUI app (relevant when launched as a
/// bare SPM binary rather than from a bundled .app) and holds the model for URL
/// handling / activation.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) weak var model: WindowModel?

    func attach(_ model: WindowModel) { self.model = model }

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
