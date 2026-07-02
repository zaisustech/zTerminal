import XCTest
import SwiftTerm
@testable import zTerminal

/// End-to-end reproduction of the find-bar pipeline against a real (headless)
/// SwiftTerm emulator: feed output, extract rows exactly the way
/// `SearchController` does, and search them with the pure engine.
final class SearchExtractionTests: XCTestCase {

    private func makeTerminal() -> Terminal {
        let headless = HeadlessTerminal(queue: DispatchQueue(label: "test")) { _ in }
        return headless.terminal
    }

    /// Mirrors SearchController.extractLines(from:).
    private func extract(_ t: Terminal) -> [String] {
        (0 ..< t.bufferLineCount).map {
            t.bufferLine(atIndex: $0)?.translateToString(trimRight: true) ?? ""
        }
    }

    func testExtractionSeesFedText() {
        let t = makeTerminal()
        t.feed(text: "anaconda_projects  Desktop\r\nDownloads  Documents\r\n")
        let lines = extract(t)
        XCTAssertTrue(lines.contains { $0.contains("Desktop") },
                      "buffer extraction lost fed text; lines=\(lines.prefix(5))")
    }

    func testSearchFindsCaseInsensitivePrefixInBuffer() {
        let t = makeTerminal()
        t.feed(text: "ls\r\nDesktop  Downloads\r\nDocuments  Music\r\n")
        let lines = extract(t)

        var engine = TerminalSearch()
        engine.recompute(query: "de", options: .init(), lines: lines)
        XCTAssertGreaterThan(engine.total, 0,
                             "\"de\" must match Desktop (case-insensitive default)")
    }
}
