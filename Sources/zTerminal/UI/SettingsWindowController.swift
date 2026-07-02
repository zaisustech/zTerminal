import AppKit
import SwiftUI

/// Hosts the Settings UI in our own resizable AppKit window. SwiftUI's `Settings`
/// scene creates a fixed panel that can't be resized, so we manage the window.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    var theme: ThemeManager?
    private var window: NSWindow?

    func show() {
        guard let theme else { return }
        if window == nil {
            let root = SettingsView().environmentObject(theme)
            let hosting = NSHostingController(rootView: root)
            let w = NSWindow(contentViewController: hosting)
            w.title = "zTerminal Settings"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 680, height: 660))
            w.minSize = NSSize(width: 620, height: 500)
            // Translucent chrome so the Liquid Glass background (a real desktop
            // blur) shows through and the window matches the app's frosted look.
            w.isOpaque = false
            w.backgroundColor = .clear
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.center()
            w.delegate = self
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
