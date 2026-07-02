import SwiftUI

/// A code-viewer surface with a tab strip for multiple open files. Switch tabs by
/// clicking a chip; close with its ✕. When the last tab closes, `onEmpty` fires so
/// the host can dismiss the split/tab.
struct CodePanelView: View {
    @ObservedObject var panel: CodePanelModel
    var onEmpty: () -> Void
    /// Swap a Markdown file's source view for its rendered preview (host wires it).
    var onShowPreview: ((URL) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if panel.docs.count > 1 {
                tabStrip
                Divider().opacity(0.3)
            }
            ZStack {
                ForEach(panel.docs) { doc in
                    CodeViewerView(document: doc,
                                   onClose: panel.docs.count > 1 ? nil : onEmpty,
                                   onShowPreview: (doc.isMarkdown && onShowPreview != nil)
                                       ? { onShowPreview?(doc.url) } : nil)
                        .opacity(doc.id == panel.activeDocID ? 1 : 0)
                        .allowsHitTesting(doc.id == panel.activeDocID)
                }
            }
        }
        .onChange(of: panel.docs.isEmpty) { if $0 { onEmpty() } }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(panel.docs) { doc in
                    let active = doc.id == panel.activeDocID
                    HStack(spacing: 5) {
                        Image(systemName: doc.language == .plainText ? "doc" : "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 9))
                        Text(doc.title).font(.system(size: 11)).lineLimit(1)
                        Button { panel.close(doc.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 8))
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(active ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture { panel.activeDocID = doc.id }
                    .draggable(doc.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        guard let d = items.first else { return false }
                        panel.moveDoc(d, before: doc.id); return true
                    }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
        }
        .background(.ultraThinMaterial)
    }
}
