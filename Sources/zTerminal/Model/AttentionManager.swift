import AppKit
import UserNotifications

/// Handles "a background tab needs you" signals (terminal bell). When a session
/// rings the bell while it is NOT the active, focused tab, posts a user
/// notification and increments the Dock icon badge; clears when the user returns.
final class AttentionManager {
    static let shared = AttentionManager()

    private var pending = Set<UUID>()        // sessions awaiting attention
    private var authorized = false

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
        let content = UNMutableNotificationContent()
        content.title = "zTerminal"
        content.body = "\(session.displayTitle) needs your attention"
        content.sound = .default
        let req = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
