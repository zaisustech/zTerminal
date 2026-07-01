import SwiftUI
import AppKit

/// The bottom toolbar: folder path + Reveal-in-Finder, session start time, and
/// a live duration timer. Reveal is enabled only for local, existing dirs.
struct BottomToolbar: View {
    @ObservedObject var session: SessionModel
    @State private var branches: [String] = []

    var body: some View {
        HStack(spacing: 12) {
            Button(action: reveal) {
                Label(session.displayCWD, systemImage: "folder")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, design: .monospaced))
            }
            .buttonStyle(.plain)
            .disabled(!session.isRevealable)
            .help(session.isRevealable ? "Reveal in Finder"
                                       : "Not a local directory")

            if let git = session.gitStatus {
                Divider().frame(height: 16)
                gitSegment(git)
            }

            if !session.envBadges.isEmpty {
                Divider().frame(height: 16)
                ForEach(session.envBadges) { badge in
                    Label(badge.text, systemImage: badge.symbol)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .help("Active runtime")
                }
            }

            // Running program while busy; otherwise the last command's result.
            if let fg = session.foreground {
                Divider().frame(height: 16)
                Label(fg, systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
                    .help("Running: \(fg)")
            } else if let result = session.lastCommand {
                Divider().frame(height: 16)
                commandResultSegment(result)
            }

            Divider().frame(height: 16)

            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            Text("Started \(startTimeString)")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            Text(durationString)
                .font(.system(size: 12).monospacedDigit())

            Spacer()

            Button(action: { session.clear() }) {
                Image(systemName: "trash").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear the terminal (⌘K)")
            .accessibilityLabel("Clear terminal")

            if !session.isRunning {
                Button("Restart") { WindowRouter.shared.model?.restart(session.id) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(session.isRunning ? "zsh · live" : "[process completed]")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(session.isRunning ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 34)
    }

    /// Git segment: branch/SHA, dirty dot, ahead/behind, with a quick-actions menu.
    @ViewBuilder private func gitSegment(_ git: GitStatus) -> some View {
        Menu {
            Button("Status") { runGit("status") }
            Button("Pull") { runGit("pull") }
            Button("Push") { runGit("push") }
            Button("Fetch") { runGit("fetch") }
            Button("Stash") { runGit("stash") }
            if !branches.isEmpty {
                Divider()
                Menu("Checkout") {
                    ForEach(branches, id: \.self) { b in
                        Button { runGit("checkout \(b)") } label: {
                            if b == git.label { Label(b, systemImage: "checkmark") }
                            else { Text(b) }
                        }
                    }
                }
            }
            Divider()
            Button("Reveal in Finder") { reveal() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: git.detached ? "arrow.triangle.branch" : "arrow.triangle.branch")
                    .font(.system(size: 11))
                Text(git.label).font(.system(size: 12, weight: .medium))
                if git.dirty {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                }
                if git.ahead > 0 { Text("↑\(git.ahead)").font(.system(size: 11)) }
                if git.behind > 0 { Text("↓\(git.behind)").font(.system(size: 11)) }
            }
            .foregroundStyle(git.dirty ? Color.orange : .secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Git: \(git.label)\(git.dirty ? " (changes)" : "")")
        .task(id: git.label) { session.fetchBranches { branches = $0 } }
    }

    /// Last-command result: green check + duration on success, red mark + exit
    /// code + duration on failure.
    @ViewBuilder private func commandResultSegment(_ r: CommandResult) -> some View {
        HStack(spacing: 4) {
            Image(systemName: r.succeeded ? "checkmark" : "xmark")
                .font(.system(size: 10, weight: .bold))
            if !r.succeeded { Text("exit \(r.exitCode)").font(.system(size: 11)) }
            Text(Self.durationString(r.duration)).font(.system(size: 11).monospacedDigit())
        }
        .foregroundStyle(r.succeeded ? Color.green : Color.red)
        .help(r.succeeded ? "Last command succeeded in \(Self.durationString(r.duration))"
                          : "Last command exited \(r.exitCode) after \(Self.durationString(r.duration))")
    }

    /// Compact command duration: "0.4s", "3.2s", "1m 05s".
    static func durationString(_ t: TimeInterval) -> String {
        if t < 60 { return String(format: "%.1fs", t) }
        let s = Int(t.rounded())
        return "\(s / 60)m \(String(format: "%02d", s % 60))s"
    }

    /// Run a git subcommand using the standard run semantics (current tab when
    /// idle, a new tab when busy).
    private func runGit(_ sub: String) {
        let cmd = "git \(sub)"
        if session.isIdleAtPrompt {
            session.run(command: cmd)
        } else {
            WindowRouter.shared.model?.open(directory: session.cwd, command: cmd)
        }
    }

    private func reveal() {
        guard session.isRevealable else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: session.cwd)])
    }

    private var startTimeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: session.startedAt)
    }

    private var durationString: String {
        let s = Int(session.elapsed)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
