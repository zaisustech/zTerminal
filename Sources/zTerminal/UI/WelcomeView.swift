import SwiftUI

extension Notification.Name {
    static let showWelcome = Notification.Name("zterminal.showWelcome")
}

/// First-run welcome: highlights the signature features + key shortcuts.
struct WelcomeView: View {
    @EnvironmentObject var theme: ThemeManager
    let onDismiss: () -> Void

    private let features: [(String, String, String)] = [
        ("rectangle.stack", "Same-folder tabs", "⌘T opens a new tab in the current directory. Double-click to rename, drag to reorder."),
        ("play.circle.fill", "Run project tasks", "In a Node/Rust/Go/Java/Python/… project, click ▶ to run scripts. ⌘-click runs in a new tab."),
        ("folder", "Finder integration", "Click the folder path to reveal in Finder, or right-click a folder in Finder → “Open in zTerminal.”"),
        ("bell.badge", "Attention alerts", "When a background tab needs you (e.g. Claude Code asks to confirm), you get a notification + Dock badge."),
        ("paintbrush", "Liquid Glass themes", "⌘, opens Settings — theme, accent, gradient presets, font, terminal background, and shell."),
        ("sparkles", "Built for AI CLIs", "Truecolor + full TUI support runs claude, codex, opencode, aider cleanly."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 34)).foregroundStyle(theme.accent)
                Text("Welcome to zTerminal").font(.title.bold())
                Text("A native macOS terminal, built for developers.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28).padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(features, id: \.1) { icon, title, desc in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 17)).foregroundStyle(theme.accent)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.headline)
                                Text(desc).font(.subheadline).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 28)
            }

            Divider()
            HStack {
                Text("Shortcuts: ⌘T new tab · ⌘W close · ⌘K clear · ⌘+/− zoom · ⌘, settings")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Get Started", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 540, height: 520)
        .background(.ultraThinMaterial)
        .tint(theme.accent)
    }
}
