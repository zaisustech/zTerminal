import XCTest
@testable import zTerminal

/// Containment and URL-scheme validation for the preview.
final class PreviewSecurityTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview-sec-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base.appendingPathComponent("sub"),
                                                withIntermediateDirectories: true)
        try Data("img".utf8).write(to: base.appendingPathComponent("pic.png"))
        try Data("img".utf8).write(to: base.appendingPathComponent("sub/nested.png"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private func handler() -> PreviewSchemeHandler {
        let h = PreviewSchemeHandler()
        h.baseDirectory = { [base] in base }
        return h
    }

    func testResolvesFileInsideBase() {
        let url = URL(string: "zt-asset://doc/pic.png")!
        XCTAssertEqual(handler().resolve(url)?.lastPathComponent, "pic.png")
        let nested = URL(string: "zt-asset://doc/sub/nested.png")!
        XCTAssertEqual(handler().resolve(nested)?.lastPathComponent, "nested.png")
    }

    func testRejectsPathTraversal() {
        // /etc/hosts exists on every macOS box — must never resolve.
        let url = URL(string: "zt-asset://doc/../../../../../../etc/hosts")!
        XCTAssertNil(handler().resolve(url))
        let encoded = URL(string: "zt-asset://doc/%2e%2e/%2e%2e/etc/hosts")!
        XCTAssertNil(handler().resolve(encoded))
    }

    func testRejectsMissingFileAndWrongScheme() {
        XCTAssertNil(handler().resolve(URL(string: "zt-asset://doc/absent.png")!))
        XCTAssertNil(handler().resolve(URL(string: "https://doc/pic.png")!))
        XCTAssertNil(handler().resolve(nil))
    }

    func testRejectsWithoutBaseDirectory() {
        let h = PreviewSchemeHandler()   // baseDirectory defaults to nil
        XCTAssertNil(h.resolve(URL(string: "zt-asset://doc/pic.png")!))
    }

    // MARK: PreviewLogic (zterminal://preview URL scheme)

    func testPreviewPathParsesValidURL() throws {
        let md = base.appendingPathComponent("readme.md")
        try "# hi".write(to: md, atomically: true, encoding: .utf8)
        let escaped = md.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "zterminal://preview?path=\(escaped)")!
        XCTAssertEqual(PreviewLogic.previewPath(fromURL: url), md.resolvingSymlinksInPath().path)
    }

    // MARK: OSC 7773 (`markdown` / `md` shell commands)

    func testPreviewRequestParsesSplitAndTab() throws {
        let md = base.appendingPathComponent("doc.md")
        try "# hi".write(to: md, atomically: true, encoding: .utf8)
        let resolved = md.resolvingSymlinksInPath().path

        let split = PreviewLogic.previewRequest(fromOSC: "preview;split;\(md.path)")
        XCTAssertEqual(split?.path, resolved)
        XCTAssertEqual(split?.split, true)

        let tab = PreviewLogic.previewRequest(fromOSC: "preview;tab;\(md.path)")
        XCTAssertEqual(tab?.split, false)
    }

    func testPreviewRequestHandlesSemicolonsInPath() throws {
        let odd = base.appendingPathComponent("a;b.md")
        try "# hi".write(to: odd, atomically: true, encoding: .utf8)
        let parsed = PreviewLogic.previewRequest(fromOSC: "preview;tab;\(odd.path)")
        XCTAssertEqual(parsed?.path, odd.resolvingSymlinksInPath().path)
    }

    func testPreviewRequestRejectsBadPayloads() throws {
        let md = base.appendingPathComponent("doc.md")
        try "# hi".write(to: md, atomically: true, encoding: .utf8)
        XCTAssertNil(PreviewLogic.previewRequest(fromOSC: "preview;split"))            // no path
        XCTAssertNil(PreviewLogic.previewRequest(fromOSC: "other;split;\(md.path)"))   // wrong verb
        XCTAssertNil(PreviewLogic.previewRequest(fromOSC: "preview;split;/etc/hosts")) // not markdown
        XCTAssertNil(PreviewLogic.previewRequest(fromOSC: ""))
    }

    func testShellIntegrationDefinesMarkdownCommands() {
        for block in [ShellColor.markdownPreviewBlock] {
            XCTAssertTrue(block.contains("markdown()"))
            XCTAssertTrue(block.contains("md()"))
            XCTAssertTrue(block.contains("7773;preview"))
        }
    }

    func testPreviewPathRejectsNonMarkdownAndMissing() throws {
        let txt = base.appendingPathComponent("notes.txt")
        try "x".write(to: txt, atomically: true, encoding: .utf8)
        XCTAssertNil(PreviewLogic.validateMarkdownPath(txt.path))
        XCTAssertNil(PreviewLogic.validateMarkdownPath(base.appendingPathComponent("gone.md").path))
        XCTAssertNil(PreviewLogic.validateMarkdownPath(base.path))   // a directory
        XCTAssertNil(PreviewLogic.previewPath(fromURL: URL(string: "zterminal://open?path=/tmp")!))
    }
}
