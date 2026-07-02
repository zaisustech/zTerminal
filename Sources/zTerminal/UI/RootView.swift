import SwiftUI

/// The window layout: animated Liquid Glass background behind a top tab bar, the
/// active terminal (inset + rounded so the gradient floats around it), and the
/// bottom toolbar. Inactive sessions stay mounted (hidden) so their shells run.
struct RootView: View {
    @ObservedObject var model: WindowModel
    @EnvironmentObject var theme: ThemeManager
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("sidebarVisible") private var sidebarVisible = false
    @AppStorage("sidebarWidth") private var sidebarWidth = 240.0
    @StateObject private var fileTree = FileTreeModel()
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
                // Keeps the file-explorer tree rooted at the active tab's CWD.
                SidebarRootUpdater(session: active, tree: fileTree).id(active.id)
            }
            VisualEffectBackground().ignoresSafeArea()
            BackgroundLayer()

            // One floating glass panel — optional file-explorer sidebar beside the
            // tab bar / terminal / toolbar stack, framed by the animated gradient.
            HStack(spacing: 0) {
                if sidebarVisible {
                    FileExplorerColumn(tree: fileTree, width: $sidebarWidth)
                }
            VStack(spacing: 0) {
                TabBar(model: model)
                Divider().opacity(0.35)

                ZStack {
                    ForEach(model.sessions) { session in
                        SessionContentView(session: session, model: model)
                            .opacity(session.id == model.activeID ? 1 : 0)
                            .allowsHitTesting(session.id == model.activeID)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Filter panel (log-inspector) covers the terminal while filter mode
                // is on — added before the find bar so the bar stays on top.
                .overlay {
                    if let active = model.active, active.kind == .terminal {
                        FilterPanelHost(controller: active.search)
                            .id(active.id)
                    }
                }
                // Sticky find bar for the active tab, pinned top-trailing over the
                // terminal (preview tabs have their own in-page search).
                .overlay(alignment: .topTrailing) {
                    if let active = model.active, active.kind == .terminal {
                        FindBarHost(controller: active.search)
                            .id(active.id)
                    }
                }

                if theme.tokens.showBottomToolbar, let active = model.active {
                    Divider().opacity(0.35)
                    BottomToolbar(session: active)
                }
            }
            }
            .background {
                // Frosted glass = blurred material + a white tint whose strength is
                // the Glass Opacity token (visible on the chrome + in Blur mode).
                ZStack {
                    Rectangle().fill(theme.glassMaterial)
                    // Tint the frost with the selected gradient so the terminal/chrome
                    // visibly take on the chosen colors (the dark material otherwise
                    // crushes light gradients to gray). Strength = Gradient tint token.
                    if theme.effectiveTokens.gradientTint > 0.001 {
                        LinearGradient(colors: theme.gradientColors,
                                       startPoint: theme.gradientStartPoint,
                                       endPoint: theme.gradientEndPoint)
                            .opacity(theme.effectiveTokens.gradientTint)
                    }
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
        .overlay { CommandPaletteHost(model: model) }
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
            AttentionManager.shared.commandNotifyEnabled = theme.tokens.notifyOnCommandFinish
            AttentionManager.shared.commandNotifyThreshold = theme.tokens.commandNotifyThreshold
        }
        .onChange(of: theme.tokens.keepAwake) { KeepAwakeManager.shared.mode = $0 }
        .onChange(of: theme.tokens.notifyOnCommandFinish) { AttentionManager.shared.commandNotifyEnabled = $0 }
        .onChange(of: theme.tokens.commandNotifyThreshold) { AttentionManager.shared.commandNotifyThreshold = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .showWelcome)) { _ in showWelcome = true }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { sidebarVisible.toggle() }
        }
        // Dropping Markdown files anywhere on the window opens them in the
        // preview — one file follows the Settings open-mode, several files each
        // get their own tab (terminal-tab style).
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            var handled = false
            let group = DispatchGroup()
            var dropped: [URL] = []
            let lock = NSLock()
            for provider in providers where provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    defer { group.leave() }
                    guard let url, ["md", "markdown"].contains(url.pathExtension.lowercased())
                    else { return }
                    lock.lock(); dropped.append(url); lock.unlock()
                }
                handled = true
            }
            group.notify(queue: .main) { model.openPreviews(urls: dropped) }
            return handled
        }
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

/// A tab's content: the terminal, the terminal beside a Markdown preview in a
/// draggable split, or — for dedicated preview tabs — the preview full-bleed.
struct SessionContentView: View {
    @ObservedObject var session: SessionModel
    let model: WindowModel

    var body: some View {
        switch session.kind {
        case .preview:
            if let panel = session.preview {
                PreviewContainerView(panel: panel,
                                     onClose: { model.close(session.id) },
                                     onShowCode: { url in
                                         // Tab: swap the rendered doc for its source view.
                                         model.openCode(url: url, split: false)
                                         if let id = panel.activeDocID { panel.close(id) }
                                         if panel.isEmpty { model.close(session.id) }
                                     })
                    .onReceive(panel.$activeTitle) { title in
                        if !title.isEmpty { session.autoTitle = title }
                    }
            }
        case .code:
            if let panel = session.code {
                CodePanelView(panel: panel,
                              onEmpty: { model.close(session.id) },
                              onShowPreview: { url in
                                  // Tab: swap this doc's source view for the rendered preview.
                                  model.openPreview(url: url, split: false)
                                  if let d = panel.docs.first(where: { $0.url == url }) { panel.close(d.id) }
                                  if panel.isEmpty { model.close(session.id) }
                              })
                    .onReceive(panel.$activeTitle) { if !$0.isEmpty { session.autoTitle = $0 } }
            }
        case .terminal:
            if let panel = session.code {
                // Tapped files open split beside the terminal as a multi-tab code panel.
                HSplitView {
                    TerminalHostView(session: session)
                        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                    CodePanelView(panel: panel,
                                  onEmpty: { session.code = nil },
                                  onShowPreview: { url in
                                      if let d = panel.docs.first(where: { $0.url == url }) { panel.close(d.id) }
                                      if panel.isEmpty { session.code = nil }
                                      model.openPreview(url: url, split: true)
                                  })
                        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let panel = session.preview {
                HSplitView {
                    TerminalHostView(session: session)
                        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                    PreviewContainerView(panel: panel,
                                         onClose: { session.preview = nil },
                                         onShowCode: { url in
                                             // Split: source view takes the pane; the
                                             // preview panel stays behind it and returns
                                             // when the code pane is closed.
                                             model.openCode(url: url, split: true)
                                         })
                        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                TerminalHostView(session: session)
            }
        }
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
