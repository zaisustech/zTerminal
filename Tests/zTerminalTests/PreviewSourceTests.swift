import XCTest
@testable import zTerminal

final class PreviewSourceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: FilePreviewSource

    func testFileSourceLoadsInitialContent() throws {
        let file = tempDir.appendingPathComponent("doc.md")
        try "# Hello".write(to: file, atomically: true, encoding: .utf8)

        let source = FilePreviewSource(url: file)
        var received: String?
        source.onEvent = { if case .replace(let text) = $0 { received = text } }
        source.start()
        defer { source.stop() }

        XCTAssertEqual(received, "# Hello")
        XCTAssertEqual(source.currentText, "# Hello")
        XCTAssertEqual(source.title, "doc.md")
        XCTAssertEqual(source.baseDirectory?.path, tempDir.standardizedFileURL.path)
    }

    func testFileSourceReloadsOnChange() throws {
        let file = tempDir.appendingPathComponent("doc.md")
        try "one".write(to: file, atomically: false, encoding: .utf8)

        let source = FilePreviewSource(url: file)
        let updated = expectation(description: "reload after write")
        source.onEvent = { event in
            if case .replace(let text) = event, text == "two" { updated.fulfill() }
        }
        source.start()
        defer { source.stop() }

        try "two".write(to: file, atomically: false, encoding: .utf8)
        wait(for: [updated], timeout: 2.0)
        XCTAssertEqual(source.currentText, "two")
    }

    func testFileSourceSurvivesAtomicReplace() throws {
        let file = tempDir.appendingPathComponent("doc.md")
        try "one".write(to: file, atomically: false, encoding: .utf8)

        let source = FilePreviewSource(url: file)
        let updated = expectation(description: "reload after atomic save")
        updated.assertForOverFulfill = false
        source.onEvent = { event in
            if case .replace(let text) = event, text == "atomic" { updated.fulfill() }
        }
        source.start()
        defer { source.stop() }

        // atomically:true = write temp + rename, replacing the inode.
        try "atomic".write(to: file, atomically: true, encoding: .utf8)
        wait(for: [updated], timeout: 2.0)
    }

    // MARK: StreamPreviewSource

    func testStreamSourceAppendsAndAccumulates() {
        let source = StreamPreviewSource(title: "Live")
        var events: [PreviewSourceEvent] = []
        source.onEvent = { events.append($0) }
        source.start()

        source.append("# Str")
        source.append("eaming")

        XCTAssertEqual(source.currentText, "# Streaming")
        guard events.count == 3,
              case .replace(let initial) = events[0],
              case .append(let first) = events[1],
              case .append(let second) = events[2] else {
            return XCTFail("unexpected event sequence: \(events)")
        }
        XCTAssertEqual(initial, "")
        XCTAssertEqual(first, "# Str")
        XCTAssertEqual(second, "eaming")
    }

    func testStreamSourceReplaceResets() {
        let source = StreamPreviewSource()
        source.append("draft")
        source.replace("final")
        XCTAssertEqual(source.currentText, "final")
    }
}
