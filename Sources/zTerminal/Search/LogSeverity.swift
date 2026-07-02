import SwiftUI

/// Best-effort log level detected from a line's text, for the DevTools-style
/// severity chips. Heuristic — terminal output isn't structured — so it scans for
/// common level tokens and falls back to `.none` (unclassified). Documented as
/// best-effort; text filtering is the precise fallback.
enum LogSeverity: String, CaseIterable, Identifiable {
    case error, warning, info, debug, trace, none

    var id: String { rawValue }

    /// The chips shown in the panel, in order (All is represented as `nil`).
    static let chipLevels: [LogSeverity] = [.error, .warning, .info, .debug, .trace]

    var label: String {
        switch self {
        case .error:   return "Error"
        case .warning: return "Warning"
        case .info:    return "Info"
        case .debug:   return "Debug"
        case .trace:   return "Trace"
        case .none:    return "Other"
        }
    }

    var color: Color {
        switch self {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        case .debug:   return .purple
        case .trace:   return .gray
        case .none:    return .secondary
        }
    }

    /// Classify a line by scanning for conservative level tokens, highest severity
    /// first. Case-insensitive. Returns `.none` when nothing recognizable is found.
    static func classify(_ line: String) -> LogSeverity {
        let l = line.lowercased()
        if contains(l, ["error", "fatal", "exception", "panic", "[e]", "level=error"]) { return .error }
        if contains(l, ["warning", "warn", "[w]", "level=warn"]) { return .warning }
        if contains(l, ["info", "notice", "[i]", "level=info"]) { return .info }
        if contains(l, ["debug", "[d]", "level=debug"]) { return .debug }
        if contains(l, ["trace", "verbose", "[t]", "level=trace"]) { return .trace }
        return .none
    }

    private static func contains(_ haystack: String, _ needles: [String]) -> Bool {
        for n in needles where haystack.contains(n) { return true }
        return false
    }
}
