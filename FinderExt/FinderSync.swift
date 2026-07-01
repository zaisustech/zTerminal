import Cocoa
import FinderSync

/// Finder Sync extension: contributes an "Open in zTerminal" item to the Finder
/// context menu — for a selected folder and for the current window's background —
/// and launches the app at that folder via the validated zterminal:// URL scheme.
class FinderSync: FIFinderSync {

    override init() {
        super.init()
        // Observe the whole filesystem so the menu is available everywhere.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override var toolbarItemName: String { "zTerminal" }
    override var toolbarItemToolTip: String { "Open in zTerminal" }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "Open in zTerminal",
                     action: #selector(openInZTerminal(_:)),
                     keyEquivalent: "")
        return menu
    }

    @objc func openInZTerminal(_ sender: AnyObject?) {
        let controller = FIFinderSyncController.default()
        // A selected folder wins; otherwise the folder the window is showing.
        let selected = (controller.selectedItemURLs() ?? []).first { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        guard let folder = selected ?? controller.targetedURL() else { return }

        var comps = URLComponents()
        comps.scheme = "zterminal"
        comps.host = "open"
        comps.queryItems = [URLQueryItem(name: "path", value: folder.path)]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }
}
