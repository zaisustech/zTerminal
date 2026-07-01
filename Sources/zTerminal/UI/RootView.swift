import SwiftUI

/// The window layout: animated Liquid Glass background behind a top tab bar, the
/// active terminal (inset + rounded so the gradient floats around it), and the
/// bottom toolbar. Inactive sessions stay mounted (hidden) so their shells run.
struct RootView: View {
    @ObservedObject var model: WindowModel
    @EnvironmentObject var theme: ThemeManager
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = false

    var body: some View {
        ZStack {
            WindowConfigurator(hideTitleBar: theme.tokens.hideTitleBar,
                               transparency: theme.effectiveTokens.windowTransparency)
                .frame(width: 0, height: 0)
            if let active = model.active {
                // Applies/clears this project's `.zTerminal.json` theme override,
                // re-evaluating when the active tab or its directory changes.
                ProjectThemeApplier(session: active).id(active.id)
            }
            VisualEffectBackground().ignoresSafeArea()
            LiquidBackground()

            // One floating glass panel — tab bar, terminal, toolbar — with the
            // animated gradient framing it (matches the Liquid Glass reference).
            VStack(spacing: 0) {
                TabBar(model: model)
                Divider().opacity(0.35)

                ZStack {
                    ForEach(model.sessions) { session in
                        TerminalHostView(session: session)
                            .opacity(session.id == model.activeID ? 1 : 0)
                            .allowsHitTesting(session.id == model.activeID)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let active = model.active {
                    Divider().opacity(0.35)
                    BottomToolbar(session: active)
                }
            }
            .background {
                // Frosted glass = blurred material + a white tint whose strength is
                // the Glass Opacity token (visible on the chrome + in Blur mode).
                ZStack {
                    Rectangle().fill(theme.glassMaterial)
                    Color.white.opacity(theme.effectiveTokens.glassOpacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(theme.effectiveTokens.cornerRadius), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(theme.effectiveTokens.cornerRadius), style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
            .padding(EdgeInsets(top: theme.tokens.hideTitleBar ? 12 : 8, leading: 12, bottom: 12, trailing: 12))
        }
        .frame(minWidth: 720, minHeight: 460)
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            if !hasSeenWelcome { showWelcome = true }
            KeepAwakeManager.shared.busyProvider = { [weak model] in
                model?.sessions.contains { !$0.isIdleAtPrompt } ?? false
            }
            KeepAwakeManager.shared.mode = theme.tokens.keepAwake
            KeepAwakeManager.shared.start()
        }
        .onChange(of: theme.tokens.keepAwake) { KeepAwakeManager.shared.mode = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .showWelcome)) { _ in showWelcome = true }
        .sheet(isPresented: $showWelcome) {
            WelcomeView { showWelcome = false; hasSeenWelcome = true }
                .environmentObject(theme)
        }
        // Smooth theme-switch + token transitions (~280ms).
        .animation(.easeInOut(duration: 0.28), value: theme.mode)
        .animation(.easeInOut(duration: 0.28), value: theme.tokens)
        .animation(.easeInOut(duration: 0.28), value: theme.projectTheme)
    }
}

/// Invisible view that keeps the active project's theme override in sync: it
/// observes the active session and re-applies `.zTerminal.json` on appear and
/// whenever the working directory changes.
private struct ProjectThemeApplier: View {
    @ObservedObject var session: SessionModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear { theme.applyProjectTheme(from: session.cwd) }
            .onChange(of: session.cwd) { theme.applyProjectTheme(from: $0) }
    }
}
