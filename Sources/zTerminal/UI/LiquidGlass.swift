import SwiftUI
import AppKit

/// Window-level vibrancy: a real `NSVisualEffectView` behind the SwiftUI content
/// so the desktop blurs through the app, reinforcing the glass look.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Frosted input field with an accent focus ring (theme spec §5.4).
struct FrostedField: ViewModifier {
    var focused: Bool
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(focused ? Color.accentColor : .white.opacity(0.12),
                                  lineWidth: focused ? 2 : 1)
            )
            .animation(.easeOut(duration: 0.16), value: focused)
    }
}

extension View {
    func frostedField(focused: Bool) -> some View { modifier(FrostedField(focused: focused)) }
}

/// Applies title-bar visibility to the hosting window at runtime, so it can be
/// toggled from Settings (hidden = frameless, content to the top edge).
struct WindowConfigurator: NSViewRepresentable {
    var hideTitleBar: Bool
    var transparency: Double = 1.0     // window opacity (1 = solid)
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { apply(v.window) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(nsView.window) }
    }
    private func apply(_ window: NSWindow?) {
        guard let w = window else { return }
        w.titlebarAppearsTransparent = hideTitleBar
        w.titleVisibility = hideTitleBar ? .hidden : .visible
        if hideTitleBar { w.styleMask.insert(.fullSizeContentView) }
        else { w.styleMask.remove(.fullSizeContentView) }
        w.isMovableByWindowBackground = true
        // Background-only transparency: keep the window fully opaque (text stays
        // crisp) but let its *background* be translucent so the desktop shows
        // through. Actual translucency comes from the background layers below.
        w.alphaValue = 1.0
        w.isOpaque = transparency < 1.0
        w.backgroundColor = transparency < 1.0 ? .clear : nil
    }
}

/// Glass button: translucent material, thin border, soft hover glow, press dip.
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(configuration.isPressed ? 0.28 : 0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.18),
                    radius: configuration.isPressed ? 2 : 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Animated mesh-style gradient background: drifting, blurred colored blobs over
/// a dark ground. Honors Reduced Motion (freezes) and the animation-speed token.
struct LiquidBackground: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Color.black.opacity(0.92 * theme.effectiveTokens.windowTransparency)
                blob(c(0), baseX: 0.20, baseY: 0.18, s: s, k: 1.0)
                blob(c(1), baseX: 0.82, baseY: 0.26, s: s, k: 0.8)
                blob(c(2), baseX: 0.30, baseY: 0.86, s: s, k: 1.1)
                blob(c(3), baseX: 0.78, baseY: 0.82, s: s, k: 0.9)
                blob(c(4), baseX: 0.55, baseY: 0.50, s: s, k: 0.7)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .blur(radius: 55)
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14 / max(0.2, theme.effectiveTokens.animationSpeed))
                .repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    /// Safe indexed gradient color (presets may define fewer than 5).
    private func c(_ i: Int) -> Color {
        let a = theme.gradientColors
        return a.isEmpty ? .blue : a[i % a.count]
    }

    private func blob(_ color: Color, baseX: CGFloat, baseY: CGFloat, s: CGFloat, k: CGFloat) -> some View {
        let drift = reduceMotion ? 0 : (phase - 0.5) * 0.14 * k
        return Circle()
            .fill(RadialGradient(colors: [color.opacity(0.85), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: s * 0.42))
            .frame(width: s * 0.9, height: s * 0.9)
            .offset(x: (baseX - 0.5) * s + drift * s,
                    y: (baseY - 0.5) * s - drift * s)
            .blendMode(.screen)
    }
}

extension View {
    /// Liquid Glass surface: translucent material, thin white border, inner
    /// highlight, rounded corners driven by the theme's corner-radius token.
    func glassSurface(_ theme: ThemeManager, radius: CGFloat? = nil) -> some View {
        let r = radius ?? CGFloat(theme.effectiveTokens.cornerRadius)
        return self
            .background(theme.glassMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(.white.opacity(0.13), lineWidth: 1)
                    .allowsHitTesting(false)   // decorative — must not swallow clicks
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(.white.opacity(theme.effectiveTokens.glassOpacity * 0.5))
                    .blendMode(.overlay)
                    .allowsHitTesting(false)   // decorative — must not swallow clicks
            )
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }
}
