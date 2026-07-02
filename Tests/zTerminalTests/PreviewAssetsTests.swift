import XCTest
@testable import zTerminal

final class PreviewAssetsTests: XCTestCase {

    /// SwiftPM has no app bundle, so this exercises the dev fallback path —
    /// the same resolution `swift run` uses.
    func testLocatesRendererBundle() throws {
        let dir = try XCTUnwrap(PreviewAssets.directory, "renderer bundle missing — run scripts/build-preview-assets.sh")
        let fm = FileManager.default
        for file in ["preview.html", "preview.js", "preview.css"] {
            XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent(file).path),
                          "\(file) missing from preview bundle")
        }
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("fonts").path),
                      "KaTeX fonts directory missing from preview bundle")
    }

    func testPageURLPointsAtHTML() {
        XCTAssertEqual(PreviewAssets.pageURL?.lastPathComponent, "preview.html")
    }
}
