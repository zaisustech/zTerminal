import AppKit
import UserNotifications

/// Handles "a background tab needs you" signals (terminal bell). When a session
/// rings the bell while it is NOT the active, focused tab, posts a user
/// notification and increments the Dock icon badge; clears when the user returns.
final class AttentionManager {
    static let shared = AttentionManager()

    private var pending = Set<UUID>()        // sessions awaiting attention
    private var authorized = false

    /// Command-finish notification settings, driven from Settings (via RootView).
    var commandNotifyEnabled = true
    var commandNotifyThreshold: TimeInterval = 30   // seconds

    /// Pure decision: notify on a finished command only when enabled, the tab is
    /// unfocused, and it ran at least `threshold` seconds. Unit-tested.
    static func shouldNotifyOnFinish(enabled: Bool, focused: Bool,
                                     duration: TimeInterval, threshold: TimeInterval) -> Bool {
        enabled && !focused && duration >= threshold
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.authorized = granted
        }
    }

    /// Called when a session rings the bell.
    func bell(for session: SessionModel) {
        guard !isFocused(session) else { return }   // user is looking at it — no nag
        DispatchQueue.main.async {
            guard self.pending.insert(session.id).inserted else { return }
            self.updateBadge()
            self.notify(session)
        }
    }

    /// Called when a command finishes: notify (with ✓/✗ + duration) if the tab is
    /// unfocused and the command ran at least the threshold.
    func commandFinished(for session: SessionModel, result: CommandResult) {
        guard Self.shouldNotifyOnFinish(enabled: commandNotifyEnabled,
                                        focused: isFocused(session),
                                        duration: result.duration,
                                        threshold: commandNotifyThreshold) else { return }
        let mark = result.succeeded ? "✓" : "✗ (\(result.exitCode))"
        let cmd = result.command.map { "“\($0)” " } ?? ""
        let secs = String(format: "%.0fs", result.duration)
        notify(title: session.displayTitle,
               body: "\(cmd)\(mark) · \(secs)",
               id: "cmd-\(session.id.uuidString)")
    }

    /// Called when a session becomes the active/focused tab — clears its flag.
    func markActive(_ session: SessionModel?) {
        guard let session else { return }
        DispatchQueue.main.async {
            if self.pending.remove(session.id) != nil { self.updateBadge() }
        }
    }

    private func isFocused(_ session: SessionModel) -> Bool {
        NSApp.isActive && WindowRouter.shared.model?.activeID == session.id
    }

    private func updateBadge() {
        NSApp.dockTile.badgeLabel = pending.isEmpty ? nil : "\(pending.count)"
    }

    private func notify(_ session: SessionModel) {
        notify(title: "zTerminal", body: "\(session.displayTitle) needs your attention",
               id: session.id.uuidString)
    }

    private func notify(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
