import SwiftUI

/// The Settings window (⌘,) — a tabbed Liquid Glass customizer. Content sits on a
/// frosted, gradient-tinted glass background and is laid out as a single centered,
/// width-constrained column (System-Settings style) so controls never drift to
/// opposite edges on a wide window.
struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ZStack {
            SettingsBackground()
            TabView {
                AppearanceSettings()
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                TerminalSettings()
                    .tabItem { Label("Terminal", systemImage: "terminal") }
                MarkdownSettings()
                    .tabItem { Label("Markdown", systemImage: "doc.richtext") }
                ScriptsSettings()
                    .tabItem { Label("Scripts", systemImage: "command") }
                EnvironmentSettings()
                    .tabItem { Label("Environment", systemImage: "list.bullet.rectangle") }
            }
            .padding(.top, 2)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 620, idealWidth: 680, maxWidth: .infinity,
               minHeight: 500, idealHeight: 660, maxHeight: .infinity)
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .background(SettingsWindowAccessor())   // keep the preferences window user-resizable
    }
}

/// Frosted glass behind the whole Settings window: a real desktop blur
/// (`VisualEffectBackground`), a soft wash of the current theme gradient, and a
/// dark scrim so every label stays crisp over the color.
private struct SettingsBackground: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ZStack {
            VisualEffectBackground()
            LinearGradient(colors: theme.gradientColors.map { $0.opacity(0.18) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(theme.glassMaterial).opacity(0.55)
            Color.black.opacity(0.10)
        }
        .ignoresSafeArea()
    }
}

/// The `Settings`/preferences window re-locks itself (dropping `.resizable`)
/// whenever it becomes key/main. This coordinator finds the window, then keeps
/// re-applying resizability on the notifications where AppKit would reset it.
private struct SettingsWindowAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.locateWindow(from: v, attempt: 0)
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.configure(nsView.window)
    }

    final class Coordinator {
        private weak var boundWindow: NSWindow?
        private var observers: [NSObjectProtocol] = []

        /// `view.window` is nil right after creation — retry until it attaches.
        func locateWindow(from view: NSView, attempt: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak view] in
                guard let self, let view else { return }
                if let w = view.window { self.bind(w) }
                else if attempt < 60 { self.locateWindow(from: view, attempt: attempt + 1) }
            }
        }

        /// Configure once, then re-apply on the events that re-lock the window.
        private func bind(_ w: NSWindow) {
            guard boundWindow !== w else { return }
            boundWindow = w
            configure(w)
            let nc = NotificationCenter.default
            for name in [NSWindow.didBecomeKeyNotification,
                         NSWindow.didBecomeMainNotification,
                         NSWindow.didResizeNotification] {
                observers.append(nc.addObserver(forName: name, object: w, queue: .main) { [weak self, weak w] _ in
                    self?.configure(w)
                })
            }
        }

        func configure(_ window: NSWindow?) {
            guard let w = window else { return }
            if !w.styleMask.contains(.resizable) { w.styleMask.insert(.resizable) }
            w.minSize = NSSize(width: 620, height: 500)
            w.maxSize = NSSize(width: 5000, height: 5000)
            w.contentMinSize = NSSize(width: 620, height: 500)
            w.contentMaxSize = NSSize(width: 5000, height: 5000)
            w.isRestorable = true
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}

// MARK: - Layout primitives

/// A centered, width-constrained scroll column shared by every tab. Keeping the
/// content column narrow (and centered in a wide window) is what fixes the
/// "label on the far left, control on the far right" spread.
private struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)          // center the column
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
        }
        .scrollContentBackground(.hidden)
    }
}

/// A titled frosted-glass card grouping related controls, matching the app's
/// Liquid Glass chrome (translucent material, hairline border, inner highlight).
private struct SettingsCard<Content: View>: View {
    var title: String? = nil
    var footnote: LocalizedStringKey? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary).kerning(0.7)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.03)).blendMode(.overlay)
                        .allowsHitTesting(false)
                )
            if let footnote {
                Text(footnote)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
            }
        }
    }
}

/// A crisper hairline than `Divider()`, which nearly vanishes on the frosted
/// glass cards. Adapts to light/dark and separates every card row.
private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.14))
            .frame(height: 1)
    }
}

/// One row inside a card: an optional icon + title + detail on the leading edge,
/// and a trailing control. Fixed vertical rhythm keeps every card aligned.
private struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String? = nil
    var icon: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 11)
    }
}

/// A titled section that is NOT boxed — for content that carries its own surface
/// (theme cards, gradient swatches, gradient preview).
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary).kerning(0.7)
                .padding(.leading, 4)
            content
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        SettingsPage {
            if theme.projectTheme != nil {
                Label {
                    Text("A project theme from the current folder's **.zTerminal.json** is overriding these settings. Your choices here apply when no project theme is active.")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                )
            }

            SettingsSection(title: "Theme") {
                HStack(spacing: 12) {
                    ThemeCard(mode: .system, icon: "circle.lefthalf.filled")
                    ThemeCard(mode: .light, icon: "sun.max")
                    ThemeCard(mode: .dark, icon: "moon.stars")
                    ThemeCard(mode: .glass, icon: "cube.transparent")
                }
            }

            SettingsSection(title: "Gradient Presets") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                    ForEach(GradientPreset.all) { preset in
                        GradientSwatch(preset: preset,
                                       selected: theme.tokens.gradientHexes == preset.hexes) {
                            theme.tokens.gradientHexes = preset.hexes
                        }
                    }
                }
            }

            SettingsSection(title: "Custom Gradient") {
                CustomGradientEditor()
            }

            SettingsCard(title: "Colors") {
                SettingsRow(title: "Accent") {
                    ColorPicker("", selection: Binding(
                        get: { theme.accent },
                        set: { theme.tokens.accentHex = NSColor($0).hexString }
                    ), supportsOpacity: false).labelsHidden()
                }
                RowDivider()
                SettingsRow(title: "Terminal color scheme",
                            detail: "Color adds a vibrant palette + colorful prompt & ls/git colors. System uses your plain shell.") {
                    Picker("", selection: $theme.tokens.terminalScheme) {
                        ForEach(TerminalScheme.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }

            SettingsCard(title: "Glass & Window") {
                SettingsRow(title: "Hide title bar", detail: "Frameless — content runs to the top edge.") {
                    Toggle("", isOn: $theme.tokens.hideTitleBar).labelsHidden().toggleStyle(.switch)
                }
                RowDivider()
                SliderRow("Glass Opacity", $theme.tokens.glassOpacity, 0.04...0.22, fmt: pct)
                RowDivider()
                SliderRow("Blur Intensity", $theme.tokens.blur, 6...44, fmt: { pct01(($0 - 6) / 38) })
                RowDivider()
                SliderRow("Corner Radius", $theme.tokens.cornerRadius, 8...28, fmt: { "\(Int($0.rounded()))pt" })
                RowDivider()
                SliderRow("Window Transparency", $theme.tokens.windowTransparency, 0.35...1.0, fmt: pct)
            }

            SettingsCard(title: "Bottom Toolbar", footnote: theme.tokens.showBottomToolbar
                         ? "Hide any item you don't need. The same toggles are on the toolbar's right-click menu."
                         : "Turn the toolbar on to choose which items appear.") {
                SettingsRow(title: "Show bottom toolbar",
                            detail: "The strip along the window's bottom edge.") {
                    Toggle("", isOn: $theme.tokens.showBottomToolbar).labelsHidden().toggleStyle(.switch)
                }
                RowDivider()
                ToolbarItemsEditor()
            }

            HStack {
                Spacer()
                Button("Reset to defaults") { theme.reset() }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
    }

    private func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
    private func pct01(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}

/// Settings → Markdown: reader customization for the preview. Every change is
/// pushed live to open previews via .previewSettingsChanged.
private struct MarkdownSettings: View {
    @AppStorage("previewFontSize") private var fontSize = 17.0
    @AppStorage("previewWidth") private var readingWidth = 740.0
    @AppStorage("previewShowTOC") private var showTOC = true
    @AppStorage("previewAnimations") private var animations = true
    @AppStorage("previewLineNumbers") private var lineNumbers = true
    @AppStorage("previewWrapCode") private var wrapCode = false
    @AppStorage("previewOpenMode") private var openMode = "split"
    @AppStorage("previewAllowHTML") private var allowHTML = false

    var body: some View {
        SettingsPage {
            SettingsCard(title: "Reading",
                         footnote: "Changes apply live to every open preview.") {
                SliderRow("Font Size", $fontSize, 14...22, fmt: { "\(Int($0.rounded()))px" })
                RowDivider()
                SliderRow("Reading Width", $readingWidth, 600...1000, fmt: { "\(Int($0.rounded()))pt" })
                RowDivider()
                SettingsRow(title: "Table of contents",
                            detail: "Sidebar outline with scroll tracking.") {
                    Toggle("", isOn: $showTOC).labelsHidden().toggleStyle(.switch)
                }
                RowDivider()
                SettingsRow(title: "Animations",
                            detail: "Fade-in for new content and smooth scrolling.") {
                    Toggle("", isOn: $animations).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Code Blocks") {
                SettingsRow(title: "Line numbers",
                            detail: "Show numbers in the code gutter.") {
                    Toggle("", isOn: $lineNumbers).labelsHidden().toggleStyle(.switch)
                }
                RowDivider()
                SettingsRow(title: "Wrap long lines",
                            detail: "Wrap by default instead of scrolling sideways.") {
                    Toggle("", isOn: $wrapCode).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Behavior",
                         footnote: "HTML is sanitized before rendering — scripts never run. In the shell, `markdown <file>` always splits and `md <file>` always opens a tab.") {
                SettingsRow(title: "Open Markdown files in",
                            detail: "Menu, drag & drop, and Finder Open With.") {
                    Picker("", selection: $openMode) {
                        Text("Split Pane").tag("split")
                        Text("New Tab").tag("tab")
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 180)
                }
                RowDivider()
                SettingsRow(title: "Render raw HTML",
                            detail: "Show HTML blocks inside Markdown documents.") {
                    Toggle("", isOn: $allowHTML).labelsHidden().toggleStyle(.switch)
                }
            }
        }
        .onChange(of: fontSize) { _ in notifyPreviews() }
        .onChange(of: readingWidth) { _ in notifyPreviews() }
        .onChange(of: showTOC) { _ in notifyPreviews() }
        .onChange(of: animations) { _ in notifyPreviews() }
        .onChange(of: lineNumbers) { _ in notifyPreviews() }
        .onChange(of: wrapCode) { _ in notifyPreviews() }
        .onChange(of: allowHTML) { _ in notifyPreviews() }
    }

    private func notifyPreviews() {
        NotificationCenter.default.post(name: .previewSettingsChanged, object: nil)
    }
}

/// Per-item visibility for the bottom toolbar: one toggle per segment, dimmed
/// while the whole toolbar is hidden. Rendered inside a `SettingsCard`.
private struct ToolbarItemsEditor: View {
    @EnvironmentObject var theme: ThemeManager

    private var toolbarOn: Bool { theme.tokens.showBottomToolbar }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(ToolbarItemKind.allCases.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 { RowDivider() }
                SettingsRow(title: item.label, detail: item.detail, icon: item.symbol) {
                    Toggle("", isOn: Binding(
                        get: { theme.tokens.showsToolbarItem(item) },
                        set: { theme.tokens.setToolbarItem(item, visible: $0) }
                    ))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
        }
        .disabled(!toolbarOn)
        .opacity(toolbarOn ? 1 : 0.5)
    }
}

private struct ThemeCard: View {
    @EnvironmentObject var theme: ThemeManager
    let mode: AppearanceMode
    let icon: String
    private var selected: Bool { theme.mode == mode }

    var body: some View {
        Button { theme.mode = mode } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .regular))
                Text(mode.label).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .white.opacity(0.10),
                                  lineWidth: selected ? 2 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : .clear)
            )
            .foregroundStyle(selected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.label) theme")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct GradientSwatch: View {
    let preset: GradientPreset
    let selected: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: preset.hexes.map(Color.init(hex:)),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : .white.opacity(0.15),
                                      lineWidth: selected ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                            .padding(4).shadow(radius: 2)
                    }
                }
                .scaleEffect(hovering ? 1.03 : 1)
                .shadow(color: .black.opacity(hovering ? 0.25 : 0), radius: 6, y: 3)
            Text(preset.name).font(.caption)
                .foregroundStyle(selected ? Color.accentColor : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityLabel("\(preset.name) gradient")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Build a gradient from two hand-picked colors (start → end). Shows a live
/// preview and applies an evenly-interpolated 5-stop gradient on demand.
private struct CustomGradientEditor: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var start = Color(hex: "#4F8CFF")
    @State private var end = Color(hex: "#10B981")
    @State private var seeded = false

    private var previewHexes: [String] {
        GradientPreset.interpolatedHexes(from: NSColor(start), to: NSColor(end))
    }
    /// The custom gradient is "in use" when the current gradient matches no preset.
    private var isActive: Bool {
        !GradientPreset.all.contains { $0.hexes == theme.tokens.gradientHexes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                colorInput("Start", $start)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                colorInput("End", $end)
                Spacer()
                Button("Apply") { theme.tokens.gradientHexes = previewHexes }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .help("Use this custom gradient")
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: previewHexes.map(Color.init(hex:)),
                                     startPoint: theme.gradientStartPoint,
                                     endPoint: theme.gradientEndPoint))
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isActive ? Color.accentColor : .white.opacity(0.15),
                                      lineWidth: isActive ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white).padding(6).shadow(radius: 2)
                    }
                }

            directionControls
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .onAppear {
            // Seed the pickers from the current gradient's endpoints, once.
            guard !seeded else { return }
            seeded = true
            if let first = theme.tokens.gradientHexes.first { start = Color(hex: first) }
            if let last = theme.tokens.gradientHexes.last { end = Color(hex: last) }
        }
    }

    private func colorInput(_ label: String, _ binding: Binding<Color>) -> some View {
        VStack(spacing: 4) {
            ColorPicker("", selection: binding, supportsOpacity: false)
                .labelsHidden()
                .accessibilityLabel("\(label) color")
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Direction + background style

    /// Live direction controls: quick presets, four x/y sliders for the start and
    /// end points, and the window background style. These apply immediately (unlike
    /// colors, which wait for Apply).
    private var directionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().opacity(0.3)

            HStack {
                Text("Direction").font(.caption).foregroundStyle(.secondary)
                Spacer()
                directionPreset("Horizontal", "arrow.left.and.right", 0, 0.5, 1, 0.5)
                directionPreset("Vertical", "arrow.up.and.down", 0.5, 0, 0.5, 1)
                directionPreset("Diagonal ↘", "arrow.down.right", 0, 0, 1, 1)
                directionPreset("Diagonal ↗", "arrow.up.right", 0, 1, 1, 0)
            }

            HStack(spacing: 16) {
                axisSlider("Start X", tokenX(\.gradientStartX))
                axisSlider("Start Y", tokenX(\.gradientStartY))
            }
            HStack(spacing: 16) {
                axisSlider("End X", tokenX(\.gradientEndX))
                axisSlider("End Y", tokenX(\.gradientEndY))
            }

            HStack {
                Text("Background").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { theme.tokens.backgroundStyle },
                    set: { theme.tokens.backgroundStyle = $0 })) {
                    ForEach(BackgroundStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
                Spacer()
            }

            // The gradient only shows through the terminal when the background is
            // translucent (Blur). Without this, the opaque terminal hides it.
            Toggle(isOn: Binding(
                get: { theme.mode == .glass },
                set: { theme.mode = $0 ? .glass : .dark })) {
                Text("Show gradient through terminal (Blur)")
                    .font(.caption)
            }
            .toggleStyle(.switch)

            // How strongly the selected gradient colors tint the glass/terminal.
            // Raise this if the terminal looks gray instead of your chosen colors.
            HStack(spacing: 8) {
                Text("Gradient tint").font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                Slider(value: tokenX(\.gradientTint), in: 0...1)
                Text(String(format: "%.0f%%", theme.tokens.gradientTint * 100))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }

            Text(gradientVisibilityHint)
                .font(.caption2)
                .foregroundStyle(showsGradient ? Color.secondary : Color.orange)
        }
    }

    /// Whether the gradient is actually visible behind the terminal right now.
    private var showsGradient: Bool {
        theme.mode == .glass || theme.tokens.windowTransparency < 1.0
    }

    private var gradientVisibilityHint: String {
        if !showsGradient {
            return "The terminal is opaque, so the gradient is hidden. Turn on Blur above to reveal it."
        }
        return theme.tokens.backgroundStyle == .linear
            ? "Linear background follows the direction above."
            : "Animated background (blobs); switch to Linear to see the direction."
    }

    /// A binding into a `Double` token field, applied live.
    private func tokenX(_ keyPath: WritableKeyPath<DesignTokens, Double>) -> Binding<Double> {
        Binding(get: { theme.tokens[keyPath: keyPath] },
                set: { theme.tokens[keyPath: keyPath] = $0 })
    }

    private func axisSlider(_ label: String, _ binding: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Slider(value: binding, in: 0...1)
            Text(String(format: "%.2f", binding.wrappedValue))
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func directionPreset(_ help: String, _ symbol: String,
                                 _ sx: Double, _ sy: Double, _ ex: Double, _ ey: Double) -> some View {
        Button {
            theme.tokens.gradientStartX = sx; theme.tokens.gradientStartY = sy
            theme.tokens.gradientEndX = ex;   theme.tokens.gradientEndY = ey
        } label: {
            Image(systemName: symbol).font(.system(size: 11))
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

// MARK: - Terminal

private struct TerminalSettings: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        SettingsPage {
            SettingsCard(title: "Shell",
                         footnote: "Applies to new tabs. Sources your ~/.zshrc first, then enables ls/git colors.") {
                SettingsRow(title: "Shell") {
                    Picker("", selection: $theme.tokens.shellPath) {
                        Text("zsh").tag("/bin/zsh")
                        Text("bash").tag("/bin/bash")
                    }
                    .labelsHidden().fixedSize()
                }
            }

            SettingsCard(title: "Power",
                         footnote: "Prevents idle system sleep during long runs (e.g. Claude Code).") {
                SettingsRow(title: "Keep awake") {
                    Picker("", selection: $theme.tokens.keepAwake) {
                        ForEach(KeepAwakeMode.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }

            SettingsCard(title: "Notifications",
                         footnote: "Notifies you when a command finishes in a background tab and ran at least this long.") {
                SettingsRow(title: "Notify on command finish") {
                    Toggle("", isOn: $theme.tokens.notifyOnCommandFinish).labelsHidden().toggleStyle(.switch)
                }
                if theme.tokens.notifyOnCommandFinish {
                    RowDivider()
                    SliderRow("Only if longer than", $theme.tokens.commandNotifyThreshold, 5...300,
                              fmt: { "\(Int($0.rounded()))s" })
                }
            }

            SettingsCard(title: "Text") {
                SettingsRow(title: "Font") {
                    Picker("", selection: $theme.tokens.terminalFontName) {
                        ForEach(ThemeManager.monospacedFamilies, id: \.self) { name in
                            Text(name).font(.custom(name, size: 12)).tag(name)
                        }
                    }
                    .labelsHidden().fixedSize()
                }
                RowDivider()
                SliderRow("Font size", $theme.tokens.terminalFontSize, 8...32, fmt: { "\(Int($0.rounded()))pt" })
            }

            SettingsCard(title: "Editor",
                         footnote: "⌘-click a file path in the terminal (or the toolbar button) to open it here. Falls back to the system default when the CLI isn't installed.") {
                SettingsRow(title: "Open files in") {
                    Picker("", selection: $theme.tokens.editor) {
                        ForEach(EditorLauncher.Editor.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .labelsHidden().fixedSize()
                }
                if theme.tokens.editor == EditorLauncher.Editor.custom.rawValue {
                    RowDivider()
                    SettingsRow(title: "Command",
                                detail: "Use {file}, {line}, {col} placeholders.") {
                        TextField("e.g. myeditor +{line} {file}", text: $theme.tokens.editorCommand)
                            .textFieldStyle(.roundedBorder).frame(width: 220)
                    }
                }
            }
        }
    }
}

// MARK: - Scripts

/// Global typed command shortcuts: `name` → `command`. Typing the name at the
/// prompt runs the command (arguments forwarded). Applies to new tabs.
private struct ScriptsSettings: View {
    @EnvironmentObject var theme: ThemeManager

    private var shortcuts: [ScriptShortcut] { theme.tokens.scriptShortcuts }
    private var duplicates: Set<String> { ScriptShortcut.duplicateNames(in: shortcuts) }

    var body: some View {
        SettingsPage {
            SettingsSection(title: "Shortcuts") {
                VStack(alignment: .leading, spacing: 12) {
                    if shortcuts.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach($theme.tokens.scriptShortcuts) { $s in
                                ScriptRow(shortcut: $s,
                                          isDuplicate: duplicates.contains(s.name.trimmingCharacters(in: .whitespaces))) {
                                    theme.tokens.scriptShortcuts.removeAll { $0.id == s.id }
                                }
                            }
                            .onMove { theme.tokens.scriptShortcuts.move(fromOffsets: $0, toOffset: $1) }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        )
                    }

                    Button {
                        theme.tokens.scriptShortcuts.append(ScriptShortcut())
                    } label: { Label("Add Shortcut", systemImage: "plus") }
                        .buttonStyle(.bordered)
                }
            }

            Text("Type a shortcut's name at the prompt to run its command; extra arguments "
                 + "are forwarded (e.g. `zaisus --watch`). Shortcuts are global, apply to "
                 + "**new** tabs, and override a same-named alias in your ~/.zshrc.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No shortcuts yet.").font(.body)
            Text("Example: name `zaisus` → command `bun run start`. Then type `zaisus` "
                 + "in a new tab to run it.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

/// One editable shortcut row: name + command, with inline validation and a
/// non-blocking warning when the name shadows an existing command.
private struct ScriptRow: View {
    @Binding var shortcut: ScriptShortcut
    let isDuplicate: Bool
    let onDelete: () -> Void

    private var name: String { shortcut.name.trimmingCharacters(in: .whitespaces) }
    private var command: String { shortcut.command.trimmingCharacters(in: .whitespaces) }
    private var nameInvalid: Bool { !name.isEmpty && !ScriptShortcut.isValidName(name) }
    private var shadows: Bool {
        ScriptShortcut.isValidName(name) && ScriptShortcut.shadowsExistingCommand(name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                TextField("name", text: $shortcut.name)
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    .frame(width: 140)
                    .accessibilityLabel("Shortcut name")
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                TextField("command to run, e.g. bun run start", text: $shortcut.command)
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    .accessibilityLabel("Command")
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete shortcut")
            }
            if let msg = message {
                Text(msg.text).font(.caption).foregroundStyle(msg.color)
            }
        }
        .padding(.vertical, 2)
    }

    private var message: (text: String, color: Color)? {
        if isDuplicate {
            return ("Duplicate name — each shortcut needs a unique name.", .red)
        }
        if nameInvalid {
            return ("Invalid name — use letters, digits, _ or -, not starting with a digit, "
                    + "and not a shell keyword.", .red)
        }
        if name.isEmpty {
            return command.isEmpty ? nil : ("Enter a name to enable this shortcut.", .secondary)
        }
        if shadows {
            return ("Overrides an existing command named “\(name)”.", .orange)
        }
        return nil
    }
}

// MARK: - Environment

/// Global environment variables: `KEY` → `value`. Each enabled, valid variable is
/// exported into every new tab's shell after the user's rc is sourced, so it
/// overrides an inherited/parent value of the same name. Applies to new tabs.
private struct EnvironmentSettings: View {
    @EnvironmentObject var theme: ThemeManager

    private var vars: [EnvVar] { theme.tokens.envVars }
    private var duplicates: Set<String> { EnvVar.duplicateKeys(in: vars) }

    var body: some View {
        SettingsPage {
            SettingsSection(title: "Variables") {
                VStack(alignment: .leading, spacing: 12) {
                    if vars.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach($theme.tokens.envVars) { $v in
                                EnvVarRow(envVar: $v,
                                          isDuplicate: duplicates.contains(v.key.trimmingCharacters(in: .whitespaces))) {
                                    theme.tokens.envVars.removeAll { $0.id == v.id }
                                }
                            }
                            .onMove { theme.tokens.envVars.move(fromOffsets: $0, toOffset: $1) }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        )
                    }

                    Button {
                        theme.tokens.envVars.append(EnvVar())
                    } label: { Label("Add Variable", systemImage: "plus") }
                        .buttonStyle(.bordered)
                }
            }

            Text("Variables are exported into **new** tabs after your ~/.zshrc is sourced, so a "
                 + "variable here overrides an inherited or ~/.zshrc value of the same name. "
                 + "Toggle a row off to keep it without injecting it.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No variables yet.").font(.body)
            Text("Example: key `NODE_ENV` → value `development`. Open a new tab and "
                 + "`echo $NODE_ENV` prints `development`.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

/// One editable variable row: enabled toggle + key + value, with inline validation
/// and a non-blocking warning when the key overrides an inherited env var.
private struct EnvVarRow: View {
    @Binding var envVar: EnvVar
    let isDuplicate: Bool
    let onDelete: () -> Void

    private var key: String { envVar.key.trimmingCharacters(in: .whitespaces) }
    private var keyInvalid: Bool { !key.isEmpty && !EnvVar.isValidKey(key) }
    private var shadows: Bool {
        EnvVar.isValidKey(key) && EnvVar.shadowsInheritedEnv(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Toggle("", isOn: $envVar.enabled)
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    .help("Inject this variable into new tabs")
                    .accessibilityLabel("Enabled")
                TextField("KEY", text: $envVar.key)
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    .frame(width: 160)
                    .accessibilityLabel("Variable name")
                Text("=").foregroundStyle(.secondary)
                TextField("value", text: $envVar.value)
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    .accessibilityLabel("Value")
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete variable")
            }
            if let msg = message {
                Text(msg.text).font(.caption).foregroundStyle(msg.color)
            }
        }
        .padding(.vertical, 2)
        .opacity(envVar.enabled ? 1 : 0.5)
    }

    private var message: (text: String, color: Color)? {
        if isDuplicate {
            return ("Duplicate key — each variable needs a unique key.", .red)
        }
        if keyInvalid {
            return ("Invalid key — use letters, digits, or _, not starting with a digit.", .red)
        }
        if key.isEmpty {
            return envVar.value.isEmpty ? nil : ("Enter a key to enable this variable.", .secondary)
        }
        if shadows {
            return ("Overrides an inherited environment variable named “\(key)”.", .orange)
        }
        return nil
    }
}

// MARK: - Shared

/// A labeled slider laid out as a card row: title + live value on one line, the
/// full-width slider below.
private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let fmt: (Double) -> String

    init(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
         fmt: @escaping (Double) -> String) {
        self.title = title; self._value = value; self.range = range; self.fmt = fmt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(fmt(value)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $value, in: range)
        }
        .padding(.vertical, 9)
    }
}
