import SwiftUI
import AppKit

/// One preview panel: a slim glass header (document tab chips, find, export,
/// close) over the rendering web views. Multiple documents live here as tabs —
/// the "terminal | split | doc1 | doc2 …" layout. All docs stay mounted (like
/// terminal tabs) so switching preserves scroll and render state.
struct PreviewContainerView: View {
    @ObservedObject var panel: PreviewPanelModel
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var systemScheme
    var onClose: (() -> Void)?
    /// Cursor-style preview↔source toggle: shows a "Code" button for
    /// file-backed documents that swaps this preview for the source view.
    var onShowCode: ((URL) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            ZStack {
                // Only LRU-3 docs keep a live web view; hibernated docs rebuild
                // on activation (perf: each web view holds a multi-MB renderer).
                ForEach(panel.docs) { doc in
                    if panel.isMounted(doc.id) {
                        PreviewWebView(model: doc)
                            .opacity(doc.id == panel.activeDocID ? 1 : 0)
                            .allowsHitTesting(doc.id == panel.activeDocID)
                    }
                }
            }
        }
        .onAppear { pushTheme() }
        .onChange(of: theme.mode) { _ in pushTheme() }
        .onChange(of: systemScheme) { _ in pushTheme() }
        .onChange(of: panel.docs.count) { _ in pushTheme() }   // theme new docs
        .onReceive(NotificationCenter.default.publisher(for: .previewSettingsChanged)) { _ in
            panel.docs.forEach { $0.applySettings() }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            // Document tab chips — scrollable when many are open.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(panel.docs) { doc in
                        DocChip(doc: doc,
                                isActive: doc.id == panel.activeDocID,
                                onSelect: { panel.activeDocID = doc.id },
                                onClose: { closeDoc(doc.id) })
                            .draggable(doc.id.uuidString)
                            .dropDestination(for: String.self) { items, _ in
                                guard let dragged = items.first else { return false }
                                panel.moveDoc(dragged, before: doc.id)
                                return true
                            }
                    }
                }
            }
            Spacer(minLength: 4)
            if let onShowCode,
               let url = (panel.activeDoc?.source as? FilePreviewSource)?.url {
                Button { onShowCode(url) } label: {
                    Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.18), in: Capsule())
                .foregroundStyle(Color.accentColor)
                .help("Show Markdown source")
            }
            Button { panel.find() } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Find in document (⌘F)")
            Menu {
                Button("Export as HTML…") { withActiveDoc { PreviewExport.exportHTML(model: $0, from: window) } }
                Button("Export as PDF…") { withActiveDoc { PreviewExport.exportPDF(model: $0, from: window) } }
                Button("Export Markdown…") { withActiveDoc { PreviewExport.exportMarkdown(model: $0, from: window) } }
                Divider()
                Button("Print…") { withActiveDoc { PreviewExport.printDocument(model: $0) } }
            } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(panel.activeDoc == nil)
            .help("Export or print")
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Close preview")
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func closeDoc(_ id: UUID) {
        panel.close(id)
        if panel.isEmpty { onClose?() }
    }

    private func withActiveDoc(_ action: (PreviewPaneModel) -> Void) {
        if let doc = panel.activeDoc { action(doc) }
    }

    private var window: NSWindow? { panel.activeDoc?.webView?.window }

    /// Auto resolves here: the SwiftUI environment already reflects the app's
    /// effective appearance (including System mode), so JS only ever sees
    /// light/dark and can never disagree with the chrome.
    private func pushTheme() {
        let dark: Bool
        switch theme.effectiveMode {
        case .light: dark = false
        case .dark, .glass: dark = true
        case .system: dark = systemScheme == .dark
        }
        panel.docs.forEach { $0.setTheme(dark ? "dark" : "light") }
    }
}

/// One document tab chip in the panel header.
private struct DocChip: View {
    @ObservedObject var doc: PreviewPaneModel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(doc.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
            }
            .buttonStyle(.plain)
            .opacity(hovering || isActive ? 1 : 0)
            .help("Close document")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}

extension Notification.Name {
    /// Posted by Settings when a preview-affecting option changes.
    static let previewSettingsChanged = Notification.Name("previewSettingsChanged")
}
