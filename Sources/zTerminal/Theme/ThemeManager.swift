import SwiftUI
import AppKit

/// User-customizable design tokens for the Liquid Glass theme. Codable so the
/// whole set persists as one value in UserDefaults.
struct DesignTokens: Codable, Equatable {
    var accentHex: String = "#4F8CFF"
    var glassOpacity: Double = 0.10     // 0.04 ... 0.22
    var blur: Double = 26               // 6 ... 44 (px)
    var cornerRadius: Double = 16        // 8 ... 28
    var windowTransparency: Double = 1.0 // 0.35 ... 1.0 (1 = fully opaque)
    var animationSpeed: Double = 1.0     // 0.2 ... 2.0

    // Frameless look: hide the title bar so content runs edge-to-edge (default on).
    var hideTitleBar: Bool = true

    // Prevent idle system sleep (off / while a tab is busy / always).
    var keepAwake: KeepAwakeMode = .off

    // Terminal ANSI color scheme (vibrant Liquid Glass palette, or SwiftTerm default).
    var terminalScheme: TerminalScheme = .liquidGlass

    // Shell used for new sessions (existing tabs keep their shell). Default zsh.
    var shellPath: String = "/bin/zsh"

    // Terminal typography + background (separate from the glass chrome).
    var terminalFontName: String = "JetBrainsMono Nerd Font Mono"  // bundled; falls back to SF Mono
    var terminalFontSize: Double = 13    // 8 ... 32
    var terminalBackgroundHex: String = "#0A0D14"

    // Global typed command shortcuts (name → command), injected into new shells.
    var scriptShortcuts: [ScriptShortcut] = []

    // Global environment variables (key → value), exported into new shells.
    var envVars: [EnvVar] = []

    static let `default` = DesignTokens()

    /// The five gradient colors from the design brief.
    var gradientHexes: [String] = ["#4F8CFF", "#8B5CF6", "#38BDF8", "#EC4899", "#10B981"]
}

/// Tolerant decoding: any missing key falls back to its default, so adding a new
/// token (e.g. `scriptShortcuts`) never invalidates a user's saved settings.
/// Declared in an extension so the memberwise initializer is preserved.
extension DesignTokens {
    private enum CodingKeys: String, CodingKey {
        case accentHex, glassOpacity, blur, cornerRadius, windowTransparency,
             animationSpeed, hideTitleBar, keepAwake, terminalScheme, shellPath,
             terminalFontName, terminalFontSize, terminalBackgroundHex,
             scriptShortcuts, envVars, gradientHexes
    }

    init(from decoder: Decoder) throws {
        let d = DesignTokens.default
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex) ?? d.accentHex
        glassOpacity = try c.decodeIfPresent(Double.self, forKey: .glassOpacity) ?? d.glassOpacity
        blur = try c.decodeIfPresent(Double.self, forKey: .blur) ?? d.blur
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? d.cornerRadius
        windowTransparency = try c.decodeIfPresent(Double.self, forKey: .windowTransparency) ?? d.windowTransparency
        animationSpeed = try c.decodeIfPresent(Double.self, forKey: .animationSpeed) ?? d.animationSpeed
        hideTitleBar = try c.decodeIfPresent(Bool.self, forKey: .hideTitleBar) ?? d.hideTitleBar
        keepAwake = try c.decodeIfPresent(KeepAwakeMode.self, forKey: .keepAwake) ?? d.keepAwake
        terminalScheme = try c.decodeIfPresent(TerminalScheme.self, forKey: .terminalScheme) ?? d.terminalScheme
        shellPath = try c.decodeIfPresent(String.self, forKey: .shellPath) ?? d.shellPath
        terminalFontName = try c.decodeIfPresent(String.self, forKey: .terminalFontName) ?? d.terminalFontName
        terminalFontSize = try c.decodeIfPresent(Double.self, forKey: .terminalFontSize) ?? d.terminalFontSize
        terminalBackgroundHex = try c.decodeIfPresent(String.self, forKey: .terminalBackgroundHex) ?? d.terminalBackgroundHex
        scriptShortcuts = try c.decodeIfPresent([ScriptShortcut].self, forKey: .scriptShortcuts) ?? d.scriptShortcuts
        envVars = try c.decodeIfPresent([EnvVar].self, forKey: .envVars) ?? d.envVars
        gradientHexes = try c.decodeIfPresent([String].self, forKey: .gradientHexes) ?? d.gradientHexes
    }
}

/// Terminal ANSI color scheme.
enum TerminalScheme: String, Codable, CaseIterable, Identifiable {
    case liquidGlass, system
    var id: String { rawValue }
    var label: String { self == .liquidGlass ? "Color" : "System" }

    /// 16 ANSI colors (0-7 normal, 8-15 bright) as hex. "System" is a standard
    /// xterm palette so switching back from Liquid Glass actually reverts.
    var ansiHexes: [String]? {
        switch self {
        case .system:
            return [
                "#000000", "#C91B00", "#00C200", "#C7C400",   // black red green yellow
                "#2225C4", "#CA30C7", "#00C5C7", "#C7C7C7",   // blue magenta cyan white
                "#686868", "#FF6E67", "#5FFA68", "#FFFC67",   // bright black/red/green/yellow
                "#6871FF", "#FF77FF", "#60FDFF", "#FFFFFF",   // bright blue/magenta/cyan/white
            ]
        case .liquidGlass:
            return [
                "#1A1D2B", "#FB7185", "#10B981", "#F5C451",   // black red green yellow
                "#4F8CFF", "#8B5CF6", "#38BDF8", "#E5E9F0",   // blue magenta cyan white
                "#4B5163", "#FF8A8A", "#34D399", "#FBD671",   // bright black/red/green/yellow
                "#7AA7FF", "#A78BFA", "#67D0FB", "#FFFFFF",   // bright blue/magenta/cyan/white
            ]
        }
    }
}

/// A named gradient preset shown in Settings.
struct GradientPreset: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let hexes: [String]

    static let all: [GradientPreset] = [
        .init(name: "Aurora",   hexes: ["#8B5CF6", "#4F8CFF", "#38BDF8", "#22D3EE", "#818CF8"]),
        .init(name: "Sunset",   hexes: ["#F59E0B", "#FB7185", "#EF4444", "#F97316", "#FDA4AF"]),
        .init(name: "Ember",    hexes: ["#EF4444", "#F97316", "#DC2626", "#7F1D1D", "#FB923C"]),
        .init(name: "Grape",    hexes: ["#7C3AED", "#8B5CF6", "#6366F1", "#A78BFA", "#4F46E5"]),
        .init(name: "Rose",     hexes: ["#EC4899", "#F472B6", "#DB2777", "#FB7185", "#F9A8D4"]),
        .init(name: "Ocean",    hexes: ["#38BDF8", "#3B82F6", "#06B6D4", "#0EA5E9", "#22D3EE"]),
        .init(name: "Mint",     hexes: ["#10B981", "#34D399", "#5EEAD4", "#14B8A6", "#6EE7B7"]),
        .init(name: "Blossom",  hexes: ["#F9A8D4", "#C4B5FD", "#FBCFE8", "#DDD6FE", "#E9D5FF"]),
        .init(name: "Peach",    hexes: ["#FFB4A2", "#FFCDB2", "#FF8FA3", "#FFB3C1", "#FCA5A5"]),
        .init(name: "Forest",   hexes: ["#065F46", "#15803D", "#22C55E", "#4ADE80", "#166534"]),
        .init(name: "Midnight", hexes: ["#1E3A8A", "#312E81", "#1E40AF", "#4338CA", "#3730A3"]),
        .init(name: "Lavender", hexes: ["#A78BFA", "#C4B5FD", "#818CF8", "#DDD6FE", "#93C5FD"]),
        .init(name: "Citrus",   hexes: ["#FBBF24", "#F59E0B", "#FDE047", "#FACC15", "#EAB308"]),
        .init(name: "Volcano",  hexes: ["#DC2626", "#EA580C", "#F97316", "#B91C1C", "#FB923C"]),
        .init(name: "Arctic",   hexes: ["#67E8F9", "#A5F3FC", "#22D3EE", "#CFFAFE", "#7DD3FC"]),
        .init(name: "Slate",    hexes: ["#334155", "#475569", "#64748B", "#1E293B", "#94A3B8"]),
        .init(name: "Pink",     hexes: ["#FF2D95", "#EC4899", "#F472B6", "#FF6FB5", "#DB2777"]),
        .init(name: "Ruby",     hexes: ["#EF4444", "#DC2626", "#B91C1C", "#F87171", "#7F1D1D"]),
        .init(name: "India",    hexes: ["#FF9933", "#FFFFFF", "#138808", "#000080", "#FF9933"]),
        .init(name: "USA",      hexes: ["#B22234", "#FFFFFF", "#3C3B6E", "#B22234", "#3C3B6E"]),
    ]

    /// Build an evenly-interpolated N-stop gradient between two colors (sRGB).
    /// Used by the custom two-color gradient picker in Settings.
    static func interpolatedHexes(from start: NSColor, to end: NSColor, stops: Int = 5) -> [String] {
        guard stops > 1 else { return [start.hexString] }
        let a = start.usingColorSpace(.sRGB) ?? start
        let b = end.usingColorSpace(.sRGB) ?? end
        return (0..<stops).map { i in
            let t = CGFloat(i) / CGFloat(stops - 1)
            let r = a.redComponent   + (b.redComponent   - a.redComponent)   * t
            let g = a.greenComponent + (b.greenComponent - a.greenComponent) * t
            let bl = a.blueComponent + (b.blueComponent  - a.blueComponent)  * t
            return NSColor(srgbRed: r, green: g, blue: bl, alpha: 1).hexString
        }
    }
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark, glass
    var id: String { rawValue }
    var label: String { self == .glass ? "Blur" : rawValue.capitalized }
    /// A translucent terminal where the gradient shows through (its own mode,
    /// not light/dark).
    var isGlass: Bool { self == .glass }
}

/// Single source of truth for appearance + tokens; changes apply live and persist.
final class ThemeManager: ObservableObject {
    // Base (user) theme — persisted; Settings edits these directly.
    @Published var tokens: DesignTokens { didSet { save() } }
    @Published var mode: AppearanceMode { didSet { save() } }

    // Active per-project override from `.zTerminal.json`. Layered over the base
    // theme for rendering only — never persisted, so Settings are never clobbered.
    @Published private(set) var projectTheme: ProjectTheme?

    private let key = "theme.settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            tokens = saved.tokens
            mode = saved.mode
        } else {
            tokens = .default
            mode = .glass   // default theme: Blur (gradient shows through)
        }
        // The custom terminal-background control was removed (the Appearance
        // gradient/theme governs the background now), so clear any leftover value.
        tokens.terminalBackgroundHex = DesignTokens.default.terminalBackgroundHex
    }

    // MARK: Effective theme (base + project override)

    /// The user's tokens with each provided project-override field layered on top.
    var effectiveTokens: DesignTokens {
        guard let p = projectTheme else { return tokens }
        var t = tokens
        if let v = p.accentHex { t.accentHex = v }
        if let v = p.gradientHexes, !v.isEmpty { t.gradientHexes = v }
        if let v = p.terminalScheme, let s = TerminalScheme(rawValue: v) { t.terminalScheme = s }
        if let v = p.terminalBackgroundHex { t.terminalBackgroundHex = v }
        if let v = p.terminalFontName { t.terminalFontName = v }
        if let v = p.terminalFontSize { t.terminalFontSize = v }
        if let v = p.glassOpacity { t.glassOpacity = v }
        if let v = p.blur { t.blur = v }
        if let v = p.cornerRadius { t.cornerRadius = v }
        if let v = p.animationSpeed { t.animationSpeed = v }
        return t
    }

    /// The effective appearance mode (project override wins when valid).
    var effectiveMode: AppearanceMode {
        if let raw = projectTheme?.mode, let m = AppearanceMode(rawValue: raw) { return m }
        return mode
    }

    /// Resolve and apply the effective `.zTerminal.json` theme for a directory,
    /// cascading **project (cwd) over global (`~/.zTerminal.json`)**. When the
    /// directory has no project theme, the global one applies; when neither is
    /// present, the user's Settings show through. Nothing here is persisted.
    func applyProjectTheme(from cwd: String) {
        let home = NSHomeDirectory()
        let global = ZTerminalConfig.load(in: home)?.theme
        let project = (cwd == home) ? nil : ZTerminalConfig.load(in: cwd)?.theme
        let combined = ProjectTheme.combine(project, over: global)
        let next = (combined?.isEmpty == false) ? combined : nil
        guard next != projectTheme else { return }
        withAnimation(.easeInOut(duration: 0.28)) { projectTheme = next }
    }

    var accent: Color { Color(hex: effectiveTokens.accentHex) }
    var gradientColors: [Color] { effectiveTokens.gradientHexes.map(Color.init(hex:)) }

    /// SwiftUI materials can't take a blur radius, so map the Blur-Intensity token
    /// (6…44) to the five material tiers — the slider now visibly changes frost.
    var glassMaterial: Material {
        switch effectiveTokens.blur {
        case ..<13:  return .ultraThinMaterial
        case ..<22:  return .thinMaterial
        case ..<31:  return .regularMaterial
        case ..<39:  return .thickMaterial
        default:     return .ultraThickMaterial
        }
    }

    /// nil = follow the system (System mode).
    var colorScheme: ColorScheme? {
        switch effectiveMode {
        case .light: return .light
        case .dark, .glass: return .dark   // glass is a dark-based translucent look
        case .system: return nil
        }
    }

    /// Terminal background for the current mode. Blur is strongly translucent (the
    /// gradient shows through); otherwise the alpha follows Window Transparency —
    /// so lowering it makes the *background* see-through while text stays opaque.
    var effectiveTerminalBackground: NSColor {
        let alpha: CGFloat = effectiveMode.isGlass ? 0.18 : CGFloat(effectiveTokens.windowTransparency)
        return terminalBackground.withAlphaComponent(alpha)
    }

    /// True when the background is translucent (Blur, or Window Transparency < 1).
    var terminalBackgroundIsTranslucent: Bool {
        effectiveMode.isGlass || effectiveTokens.windowTransparency < 1.0
    }

    func reset() {
        tokens = .default
        mode = .glass   // default theme: Blur (gradient shows through)
    }

    // MARK: Terminal appearance

    var terminalFont: NSFont {
        NSFont(name: effectiveTokens.terminalFontName, size: effectiveTokens.terminalFontSize)
            ?? .monospacedSystemFont(ofSize: effectiveTokens.terminalFontSize, weight: .regular)
    }

    var terminalBackground: NSColor {
        NSColor(hex: effectiveTokens.terminalBackgroundHex) ?? NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1)
    }

    /// App-wide terminal font zoom (⌘= / ⌘- / ⌘0), clamped and persisted.
    func zoomFont(by delta: Double) {
        tokens.terminalFontSize = min(32, max(8, tokens.terminalFontSize + delta))
    }
    func resetFontSize() { tokens.terminalFontSize = DesignTokens.default.terminalFontSize }

    /// Monospaced font families installed on this system (for the picker).
    static let monospacedFamilies: [String] = {
        let families = NSFontManager.shared.availableFontFamilies.filter { fam in
            NSFont(name: fam, size: 12)?.isFixedPitch ?? false
        }
        return Array(Set(families + ["SF Mono", "Menlo", "Monaco"])).sorted()
    }()

    // MARK: Persistence
    private struct Saved: Codable { var tokens: DesignTokens; var mode: AppearanceMode }
    private func save() {
        if let data = try? JSONEncoder().encode(Saved(tokens: tokens, mode: mode)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v & 0xFF0000) >> 16) / 255,
                  green: CGFloat((v & 0x00FF00) >> 8) / 255,
                  blue: CGFloat(v & 0x0000FF) / 255, alpha: 1)
    }
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
        } else {
            r = 0.31; g = 0.55; b = 1.0 // fallback = #4F8CFF
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
