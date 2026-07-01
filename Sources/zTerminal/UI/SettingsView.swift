import SwiftUI

/// The Settings window (⌘,) — tabbed Liquid Glass customizer.
struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            TerminalSettings()
                .tabItem { Label("Terminal", systemImage: "terminal") }
            ScriptsSettings()
                .tabItem { Label("Scripts", systemImage: "command") }
            EnvironmentSettings()
                .tabItem { Label("Environment", systemImage: "list.bullet.rectangle") }
        }
        .frame(minWidth: 560, idealWidth: 620, maxWidth: .infinity,
               minHeight: 460, idealHeight: 620, maxHeight: .infinity)
        .background(SettingsWindowAccessor())   // make the preferences window user-resizable
    }
}

/// The SwiftUI `Settings` scene creates a fixed preferences panel that re-locks
/// its window (dropping `.resizable`) whenever it becomes key/main. Inserting the
/// style mask once isn't enough — this coordinator finds the window, then keeps
/// re-applying resizability on the notifications where AppKit would reset it, so
/// the user can always drag to resize.
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
            w.minSize = NSSize(width: 560, height: 460)
            w.maxSize = NSSize(width: 5000, height: 5000)
            w.contentMinSize = NSSize(width: 560, height: 460)
            w.contentMaxSize = NSSize(width: 5000, height: 5000)
            w.isRestorable = true
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if theme.projectTheme != nil {
                    Label {
                        Text("A project theme from the current folder's **.zTerminal.json** is overriding these settings. Your choices here apply when no project theme is active.")
                            .font(.callout)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                sectionTitle("Theme")
                HStack(spacing: 12) {
                    ThemeCard(mode: .system, icon: "circle.lefthalf.filled")
                    ThemeCard(mode: .light, icon: "sun.max")
                    ThemeCard(mode: .dark, icon: "moon.stars")
                    ThemeCard(mode: .glass, icon: "cube.transparent")
                }

                sectionTitle("Gradient Presets")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                    ForEach(GradientPreset.all) { preset in
                        GradientSwatch(preset: preset,
                                       selected: theme.tokens.gradientHexes == preset.hexes) {
                            theme.tokens.gradientHexes = preset.hexes
                        }
                    }
                }

                sectionTitle("Custom Gradient")
                CustomGradientEditor()

                sectionTitle("Colors")
                HStack {
                    Text("Accent").font(.body)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { theme.accent },
                        set: { theme.tokens.accentHex = NSColor($0).hexString }
                    ), supportsOpacity: false).labelsHidden()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Terminal color scheme").font(.body)
                        Text("Color adds a vibrant palette + colorful prompt & ls/git colors. System uses your plain shell.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $theme.tokens.terminalScheme) {
                        ForEach(TerminalScheme.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }

                sectionTitle("Glass & Window")
                VStack(spacing: 16) {
                    Toggle("Hide title bar (frameless)", isOn: $theme.tokens.hideTitleBar)
                    LabeledSlider("Glass Opacity", $theme.tokens.glassOpacity, 0.04...0.22, fmt: pct)
                    LabeledSlider("Blur Intensity", $theme.tokens.blur, 6...44, fmt: { pct01(($0 - 6) / 38) })
                    LabeledSlider("Corner Radius", $theme.tokens.cornerRadius, 8...28, fmt: { "\(Int($0.rounded()))pt" })
                    LabeledSlider("Window Transparency", $theme.tokens.windowTransparency, 0.35...1.0, fmt: pct)
                }

                HStack { Spacer(); Button("Reset to defaults") { theme.reset() } }
            }
            .padding(24)
        }
        .tint(theme.accent)
    }

    private func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
    private func pct01(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased()).font(.caption.weight(.semibold))
            .foregroundStyle(.secondary).kerning(0.6)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                colorInput("Start", $start)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                colorInput("End", $end)
                Spacer()
                Button("Apply") { theme.tokens.gradientHexes = previewHexes }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .help("Use this custom gradient")
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: previewHexes.map(Color.init(hex:)),
                                     startPoint: .leading, endPoint: .trailing))
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
        }
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
}

// MARK: - Terminal

private struct TerminalSettings: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        Form {
            Section("Shell") {
                Picker("Shell", selection: $theme.tokens.shellPath) {
                    Text("zsh").tag("/bin/zsh")
                    Text("bash").tag("/bin/bash")
                }
                Text("Applies to new tabs. Sources your ~/.zshrc first, then enables ls/git colors.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Power") {
                Picker("Keep awake", selection: $theme.tokens.keepAwake) {
                    ForEach(KeepAwakeMode.allCases) { Text($0.label).tag($0) }
                }
                Text("Prevents idle system sleep during long runs (e.g. Claude Code).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Text") {
                Picker("Font", selection: $theme.tokens.terminalFontName) {
                    ForEach(ThemeManager.monospacedFamilies, id: \.self) { name in
                        Text(name).font(.custom(name, size: 12)).tag(name)
                    }
                }
                LabeledSlider("Font size", $theme.tokens.terminalFontSize, 8...32, fmt: { "\(Int($0.rounded()))pt" })
            }
        }
        .formStyle(.grouped)
        .tint(theme.accent)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("SHORTCUTS").font(.caption.weight(.semibold))
                .foregroundStyle(.secondary).kerning(0.6)

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
                .frame(minHeight: 180)
            }

            HStack {
                Button {
                    theme.tokens.scriptShortcuts.append(ScriptShortcut())
                } label: { Label("Add Shortcut", systemImage: "plus") }
                Spacer()
            }

            Text("Type a shortcut's name at the prompt to run its command; extra arguments "
                 + "are forwarded (e.g. `zaisus --watch`). Shortcuts are global, apply to "
                 + "**new** tabs, and override a same-named alias in your ~/.zshrc.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .tint(theme.accent)
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
        .padding(.vertical, 24)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("VARIABLES").font(.caption.weight(.semibold))
                .foregroundStyle(.secondary).kerning(0.6)

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
                .frame(minHeight: 180)
            }

            HStack {
                Button {
                    theme.tokens.envVars.append(EnvVar())
                } label: { Label("Add Variable", systemImage: "plus") }
                Spacer()
            }

            Text("Variables are exported into **new** tabs after your ~/.zshrc is sourced, so a "
                 + "variable here overrides an inherited or ~/.zshrc value of the same name. "
                 + "Toggle a row off to keep it without injecting it.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .tint(theme.accent)
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
        .padding(.vertical, 24)
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

private struct LabeledSlider: View {
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
    }
}
