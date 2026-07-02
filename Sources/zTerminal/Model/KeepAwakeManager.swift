import Foundation

/// Keep-awake mode. Persisted as part of the theme settings bag.
enum KeepAwakeMode: String, Codable, CaseIterable, Identifiable {
    case off, whileBusy, always
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"
        case .whileBusy: return "While Busy"
        case .always: return "Always"
        }
    }
    /// Next mode, for a cycling menu command.
    var next: KeepAwakeMode {
        switch self { case .off: return .whileBusy; case .whileBusy: return .always; case .always: return .off }
    }
}

/// Holds a single idle-system-sleep power assertion while Keep Awake is active,
/// so a long Claude/agent run doesn't get interrupted by system sleep.
final class KeepAwakeManager {
    static let shared = KeepAwakeManager()

    var mode: KeepAwakeMode = .off { didSet { evaluate(); syncTimer() } }
    var busyProvider: () -> Bool = { false }

    private var token: NSObjectProtocol?
    private var timer: Timer?

    /// Pure decision — unit-tested.
    static func desiredActive(mode: KeepAwakeMode, busy: Bool) -> Bool {
        mode == .always || (mode == .whileBusy && busy)
    }

    /// Called once at launch. The 1 Hz re-evaluation ticker only runs in
    /// `.whileBusy` — the other modes need no polling (perf: this used to poll
    /// every tab's tty every second even when keep-awake was Off).
    func start() {
        evaluate()
        syncTimer()
    }

    private func syncTimer() {
        if mode == .whileBusy {
            guard timer == nil else { return }
            let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.evaluate() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func evaluate() {
        setActive(KeepAwakeManager.desiredActive(mode: mode, busy: busyProvider()))
    }

    private func setActive(_ on: Bool) {
        if on, token == nil {
            token = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled],
                                                          reason: "zTerminal Keep Awake")
        } else if !on, let t = token {
            ProcessInfo.processInfo.endActivity(t)
            token = nil
        }
    }
}
