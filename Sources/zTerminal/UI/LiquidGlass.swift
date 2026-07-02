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
    /// Every mutation is change-guarded: this runs on each SwiftUI render, and
    /// unconditional window mutations dirty AppKit's persistent UI state,
    /// making NSPersistentUIManager rewrite window plists continuously (a
    /// measurable idle-CPU cost found while profiling).
    private func apply(_ window: NSWindow?) {
        guard let w = window else { return }
        if w.titlebarAppearsTransparent != hideTitleBar { w.titlebarAppearsTransparent = hideTitleBar }
        let visibility: NSWindow.TitleVisibility = hideTitleBar ? .hidden : .visible
        if w.titleVisibility != visibility { w.titleVisibility = visibility }
        if hideTitleBar != w.styleMask.contains(.fullSizeContentView) {
            if hideTitleBar { w.styleMask.insert(.fullSizeContentView) }
            else { w.styleMask.remove(.fullSizeContentView) }
        }
        // Draggable by the native title-bar strip only — NOT the whole background.
        // Background dragging hijacked drags on interactive content (file-tree rows,
        // tab reordering), moving the window instead of starting the item drag.
        if w.isMovableByWindowBackground { w.isMovableByWindowBackground = false }
        // Background-only transparency: keep the window fully opaque (text stays
        // crisp) but let its *background* be translucent so the desktop shows
        // through. Actual translucency comes from the background layers below.
        if w.alphaValue != 1.0 { w.alphaValue = 1.0 }
        let translucent = transparency < 1.0
        if w.isOpaque != translucent { w.isOpaque = translucent }
        let bg: NSColor? = translucent ? .clear : nil
        if w.backgroundColor != bg { w.backgroundColor = bg }
        // Terminal sessions can't be restored across launches, so window-state
        // restoration only costs plist writes — turn it off.
        if w.isRestorable { w.isRestorable = false }
    }
}

/// A transparent layer that drags the window on mouse-down. Placed BEHIND chrome
/// (e.g. the tab bar) so empty areas move the window, while interactive controls on
/// top (tabs, buttons) keep their own gestures — restoring window dragging after
/// `isMovableByWindowBackground` was turned off to let content drags work.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
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

/// The window background: either the animated blobs or a linear gradient honoring
/// the user's direction points, per the `backgroundStyle` token.
struct BackgroundLayer: View {
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        switch theme.effectiveTokens.backgroundStyle {
        case .linear:
            LinearGradient(colors: theme.gradientColors,
                           startPoint: theme.gradientStartPoint,
                           endPoint: theme.gradientEndPoint)
                .opacity(theme.effectiveTokens.windowTransparency)
                .ignoresSafeArea()
        case .blobs:
            LiquidBackground()
        }
    }
}

/// Animated mesh-style gradient background: drifting, blurred colored blobs over
/// a dark ground. Honors Reduced Motion (freezes) and the animation-speed token.
///
/// Perf-conscious by construction (this layer used to dominate idle CPU):
/// - Driven by a pausable 30 fps `TimelineView`, not a `repeatForever`
///   animation — it fully stops when the window is occluded, the app is in
///   the background, or Reduce Motion is on.
/// - The blob stack is rasterized with `drawingGroup()` so the 55 pt blur
///   composites ONE Metal texture instead of five live blended layers.
struct LiquidBackground: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var paused = false

    var body: some View {
        GeometryReader { geo in
            // Rendered at QUARTER resolution and upscaled: the output is a heavy
            // blur, so the upscale is invisible while pixel work drops ~16×.
            // 10 fps is indistinguishable for a 14-second drift cycle.
            let scale: CGFloat = 4
            let w = max(geo.size.width / scale, 1)
            let h = max(geo.size.height / scale, 1)
            let s = min(w, h)
            TimelineView(.animation(minimumInterval: 1.0 / 10.0,
                                    paused: paused || reduceMotion)) { context in
                let phase = Self.phase(at: context.date,
                                       speed: theme.effectiveTokens.animationSpeed,
                                       frozen: reduceMotion)
                ZStack {
                    Color.black.opacity(0.92 * theme.effectiveTokens.windowTransparency)
                    blob(c(0), baseX: 0.20, baseY: 0.18, s: s, k: 1.0, phase: phase)
                    blob(c(1), baseX: 0.82, baseY: 0.26, s: s, k: 0.8, phase: phase)
                    blob(c(2), baseX: 0.30, baseY: 0.86, s: s, k: 1.1, phase: phase)
                    blob(c(3), baseX: 0.78, baseY: 0.82, s: s, k: 0.9, phase: phase)
                    blob(c(4), baseX: 0.55, baseY: 0.50, s: s, k: 0.7, phase: phase)
                }
                .frame(width: w, height: h)
                .blur(radius: 55 / scale)
                .drawingGroup()
                .scaleEffect(scale, anchor: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { _ in
            syncPaused()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            paused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            syncPaused()
        }
    }

    /// Animate only while some app window is actually visible on screen and the
    /// app is frontmost — a background decoration must never burn frames the
    /// user cannot see.
    private func syncPaused() {
        let visible = NSApp.windows.contains {
            $0.isVisible && $0.occlusionState.contains(.visible)
        }
        paused = !(visible && NSApp.isActive)
    }

    /// Smooth 0…1 drift phase from wall time — same 14 s cadence the old
    /// autoreversing animation had, scaled by the animation-speed token.
    static func phase(at date: Date, speed: Double, frozen: Bool) -> CGFloat {
        guard !frozen else { return 0.5 }
        let period = 28.0 / max(0.2, speed)   // 14 s each way
        let t = date.timeIntervalSinceReferenceDate
        return CGFloat(0.5 + 0.5 * sin(t * 2 * .pi / period))
    }

    /// Safe indexed gradient color (presets may define fewer than 5).
    private func c(_ i: Int) -> Color {
        let a = theme.gradientColors
        return a.isEmpty ? .blue : a[i % a.count]
    }

    private func blob(_ color: Color, baseX: CGFloat, baseY: CGFloat, s: CGFloat,
                      k: CGFloat, phase: CGFloat) -> some View {
        let drift = (phase - 0.5) * 0.14 * k
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
