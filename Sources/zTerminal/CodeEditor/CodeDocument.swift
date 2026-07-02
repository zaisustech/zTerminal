import Foundation
import SwiftUI

/// Loads a file's text for the code viewer: off-main read, UTF-8 (then Latin-1)
/// decode, language detection, and a large-file cap. Holds the raw string +
/// status; coloring is applied in the view from the theme. Created on the main
/// thread; all `@Published` mutations happen on main (init or the load completion).
final class CodeDocument: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL

    enum Status: Equatable {
        case loading
        case ready                 // highlightable
        case plainLarge            // loaded, too big to highlight
        case failed(String)        // decode / read error
    }

    @Published private(set) var text: String = ""
    @Published private(set) var status: Status = .loading
    @Published private(set) var language: CodeLanguage = .plainText
    @Published var wrap = false

    var title: String { url.lastPathComponent }

    /// Markdown documents get the Cursor-style source↔preview toggle.
    var isMarkdown: Bool { ["md", "markdown"].contains(url.pathExtension.lowercased()) }

    init(url: URL) {
        self.url = url
        load()
    }

    func reload() { load() }

    private func load() {
        status = .loading
        let url = self.url
        DispatchQueue.global(qos: .userInitiated).async {
            let result: (text: String, status: Status, language: CodeLanguage)
            do {
                let data = try Data(contentsOf: url)
                guard let decoded = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .isoLatin1) else {
                    result = ("", .failed("Can't display this file — it isn't text."), .plainText)
                    DispatchQueue.main.async { self.apply(result) }
                    return
                }
                let firstLine = decoded.prefix(while: { $0 != "\n" })
                let lang = CodeLanguage.detect(url: url, firstLine: String(firstLine))
                let tooBig = data.count > SyntaxHighlighter.highlightByteLimit
                result = (decoded, tooBig ? .plainLarge : .ready, tooBig ? .plainText : lang)
            } catch {
                result = ("", .failed("Couldn't read the file: \(error.localizedDescription)"), .plainText)
            }
            DispatchQueue.main.async { self.apply(result) }
        }
    }

    private func apply(_ r: (text: String, status: Status, language: CodeLanguage)) {
        text = r.text
        status = r.status
        language = r.language
    }
}
