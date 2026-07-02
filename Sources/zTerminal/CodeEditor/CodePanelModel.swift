import Foundation

/// One code-viewer surface holding MULTIPLE files as tabs — the
/// "terminal | code | tab1 | tab2 …" layout, mirroring `PreviewPanelModel`. The
/// window keeps at most one split code panel; opening another file adds a tab here
/// instead of replacing the pane. Re-selecting an already-open file focuses it.
final class CodePanelModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var docs: [CodeDocument] = []
    @Published var activeDocID: UUID? { didSet { activeTitle = activeDoc?.title ?? "" } }
    /// Title of the active document — drives the window-tab name for `.code` tabs.
    @Published private(set) var activeTitle: String = ""

    init(doc: CodeDocument? = nil) { if let doc { add(doc) } }

    var activeDoc: CodeDocument? { docs.first { $0.id == activeDocID } }
    var isEmpty: Bool { docs.isEmpty }

    /// Open a file as a tab; re-selects an already-open file instead of duplicating.
    func open(url: URL) {
        let target = url.standardizedFileURL
        if let existing = docs.first(where: { $0.url.standardizedFileURL == target }) {
            activeDocID = existing.id
            return
        }
        add(CodeDocument(url: target))
    }

    func add(_ doc: CodeDocument) {
        docs.append(doc)
        activeDocID = doc.id
    }

    func close(_ docID: UUID) {
        guard let idx = docs.firstIndex(where: { $0.id == docID }) else { return }
        docs.remove(at: idx)
        if activeDocID == docID {
            activeDocID = docs.indices.contains(idx) ? docs[idx].id : docs.last?.id
        }
    }

    /// Reorder: drop the dragged tab (id string) in front of `targetID`.
    func moveDoc(_ draggedIDString: String, before targetID: UUID) {
        guard let dragged = UUID(uuidString: draggedIDString), dragged != targetID,
              let from = docs.firstIndex(where: { $0.id.uuidString == draggedIDString }) else { return }
        let doc = docs.remove(at: from)
        let target = docs.firstIndex(where: { $0.id == targetID }) ?? docs.count
        docs.insert(doc, at: target)
    }
}
