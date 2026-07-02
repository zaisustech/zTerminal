import Foundation
import Combine

/// One preview surface holding MULTIPLE Markdown documents as tabs — the
/// "terminal | split view | tab1 | tab2 …" layout. The window keeps at most
/// one split panel; opening another file adds a document tab here instead of
/// sprouting a second preview.
final class PreviewPanelModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var docs: [PreviewPaneModel] = []
    @Published var activeDocID: UUID? { didSet { syncTitle(); touchMounted() } }

    /// Docs with a live web view: the active one plus the two most recently
    /// used (LRU-3). Older docs hibernate — their WKWebView (and its multi-MB
    /// renderer heap) is released and rebuilt on re-activation.
    @Published private(set) var mountedIDs: [UUID] = []

    /// Title of the active document — drives the window-tab name for dedicated
    /// preview tabs.
    @Published private(set) var activeTitle: String = ""

    private var titleSub: AnyCancellable?

    init(doc: PreviewPaneModel? = nil) {
        if let doc { add(doc) }
    }

    var activeDoc: PreviewPaneModel? {
        docs.first { $0.id == activeDocID }
    }

    var isEmpty: Bool { docs.isEmpty }

    /// True when any of the panel's web views has key focus (⌘F/⌘P routing).
    var isFocused: Bool { docs.contains { $0.isFocused } }

    /// Open a file as a document tab; re-selects an already-open file instead
    /// of duplicating it.
    func open(url: URL) {
        let target = url.standardizedFileURL
        if let existing = docs.first(where: {
            ($0.source as? FilePreviewSource)?.url == target
        }) {
            activeDocID = existing.id
            return
        }
        add(PreviewPaneModel(source: FilePreviewSource(url: target)))
    }

    func add(_ doc: PreviewPaneModel) {
        docs.append(doc)
        activeDocID = doc.id
    }

    func close(_ docID: UUID) {
        guard let idx = docs.firstIndex(where: { $0.id == docID }) else { return }
        docs.remove(at: idx)
        mountedIDs.removeAll { $0 == docID }
        if activeDocID == docID {
            activeDocID = docs.indices.contains(idx) ? docs[idx].id : docs.last?.id
        }
    }

    func isMounted(_ docID: UUID) -> Bool { mountedIDs.contains(docID) }

    private func touchMounted() {
        guard let id = activeDocID else { return }
        var ids = mountedIDs.filter { mounted in docs.contains { $0.id == mounted } }
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        mountedIDs = Array(ids.prefix(3))
    }

    func find() { activeDoc?.find() }

    /// Reorder: drop the dragged document chip (by id string) in front of
    /// `targetID` — same gesture as the window tab bar.
    func moveDoc(_ draggedIDString: String, before targetID: UUID) {
        guard let dragged = UUID(uuidString: draggedIDString), dragged != targetID,
              let from = docs.firstIndex(where: { $0.id == dragged }) else { return }
        let doc = docs.remove(at: from)
        let target = docs.firstIndex(where: { $0.id == targetID }) ?? docs.count
        docs.insert(doc, at: target)
    }

    private func syncTitle() {
        titleSub = activeDoc?.$title.sink { [weak self] in self?.activeTitle = $0 }
        if activeDoc == nil { activeTitle = "" }
    }
}
