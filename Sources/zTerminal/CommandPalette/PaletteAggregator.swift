import Foundation
import AppKit

/// Builds the command palette's item list from everything the app already knows:
/// bookmarks (home + cwd), detected script tasks, script shortcuts, open tabs,
/// recent directories, and app commands. Built fresh each open, so it always
/// reflects the current CWD and tabs.
enum PaletteAggregator {

    static func items(model: WindowModel, theme: ThemeManager) -> [PaletteItem] {
        var out: [PaletteItem] = []
        let active = model.active
        let cwd = active?.cwd ?? NSHomeDirectory()
        let home = NSHomeDirectory()

        // Shared run semantics: idle → current tab, busy/⌘ → new tab (mirrors RunPopover).
        func run(_ command: String, newTab: Bool) {
            guard let active else { model.open(directory: cwd, command: command); return }
            if newTab || !active.isIdleAtPrompt {
                model.open(directory: active.cwd, command: command)
            } else {
                active.run(command: command)
            }
        }

        // Bookmarks — global (home) then current folder; de-duplicated by name+command.
        var seenBookmarks = Set<String>()
        for (scope, dir) in [("Global", home), ("Current folder", cwd)] where !(scope == "Current folder" && cwd == home) {
            for b in ZTerminalConfig.load(in: dir)?.bookmarks ?? [] {
                guard seenBookmarks.insert(b.id).inserted else { continue }
                out.append(PaletteItem(id: "bm:\(dir):\(b.id)", category: .bookmark,
                                       title: b.name, subtitle: "\(scope) · \(b.command)",
                                       icon: b.icon, iconColorHex: b.color,
                                       activate: { run(b.command, newTab: $0) }))
            }
        }

        // Detected script tasks in the CWD.
        for group in TaskRunner.detect(in: cwd) {
            for t in group.tasks {
                out.append(PaletteItem(id: "task:\(group.id):\(t.id)", category: .task,
                                       title: t.name, subtitle: t.runCommand,
                                       icon: t.icon ?? "play.fill", iconColorHex: t.iconColorHex,
                                       activate: { run(t.runCommand, newTab: $0) }))
            }
        }

        // Global script shortcuts.
        for s in theme.tokens.scriptShortcuts {
            out.append(PaletteItem(id: "sc:\(s.id)", category: .shortcut,
                                   title: s.name, subtitle: s.command, icon: "command",
                                   activate: { run(s.command, newTab: $0) }))
        }

        // Open tabs (activate switches; new-tab not meaningful).
        for tab in model.sessions {
            let id = tab.id
            out.append(PaletteItem(id: "tab:\(id)", category: .tab,
                                   title: tab.displayTitle, subtitle: tab.displayCWD,
                                   icon: "macwindow", supportsNewTab: false,
                                   activate: { _ in model.select(id) }))
        }

        // Recent directories — Return = cd in current tab, ⌘Return = new tab there.
        for dir in RecentDirectories.shared.paths where dir != cwd {
            out.append(PaletteItem(id: "dir:\(dir)", category: .directory,
                                   title: (dir as NSString).lastPathComponent,
                                   subtitle: CwdLogic.abbreviatingHome(dir, home: home),
                                   icon: "folder",
                                   activate: { newTab in
                                       if newTab { model.open(directory: dir) }
                                       else { active?.run(command: "cd \(ScriptShortcut.shellQuote(dir))") }
                                   }))
        }

        // App commands.
        func app(_ title: String, _ icon: String, _ action: @escaping () -> Void) {
            out.append(PaletteItem(id: "app:\(title)", category: .app, title: title,
                                   subtitle: "", icon: icon, supportsNewTab: false,
                                   activate: { _ in action() }))
        }
        app("New Tab", "plus.square") { model.addTab() }
        app("Reveal in Finder", "folder") { active?.revealInFinder() }
        app("Clear Terminal", "trash") { active?.clear() }
        app("Restart Tab", "arrow.clockwise") { if let id = active?.id { model.restart(id) } }
        app("Settings…", "gearshape") {
            DispatchQueue.main.async {
                SettingsWindowController.shared.theme = theme
                SettingsWindowController.shared.show()
            }
        }
        return out
    }
}
