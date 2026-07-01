import XCTest
@testable import zTerminal

final class ZTerminalConfigTests: XCTestCase {
    private var dir: String!
    override func setUpWithError() throws {
        dir = NSTemporaryDirectory() + "zt-cfg-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: dir) }
    private func write(_ contents: String) {
        try? contents.write(toFile: ZTerminalConfig.path(in: dir), atomically: true, encoding: .utf8)
    }

    // MARK: loading

    func testMissingFileIsNil() {
        XCTAssertNil(ZTerminalConfig.load(in: dir))
        XCTAssertFalse(ZTerminalConfig.exists(in: dir))
    }

    func testMalformedFileIsNilNotCrash() {
        write("{ not json ")
        XCTAssertNil(ZTerminalConfig.load(in: dir))
    }

    func testLoadBookmarksAndTheme() throws {
        write(#"""
        {
          "bookmarks": [
            { "name": "Prebuild", "command": "expo prebuild --clean", "icon": "hammer.fill" },
            { "name": "Start", "command": "npx expo start" }
          ],
          "theme": { "mode": "glass", "accentHex": "#EC4899" }
        }
        """#)
        let cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks.count, 2)
        XCTAssertEqual(cfg.bookmarks[0].command, "expo prebuild --clean")
        // Missing icon defaults to a star.
        XCTAssertEqual(cfg.bookmarks[1].icon, Bookmark.defaultIcon)
        XCTAssertEqual(cfg.theme?.mode, "glass")
        XCTAssertEqual(cfg.theme?.accentHex, "#EC4899")
    }

    func testEmptyIconStringDefaults() throws {
        write(#"{ "bookmarks": [ { "name": "x", "command": "y", "icon": "  " } ] }"#)
        let cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks[0].icon, Bookmark.defaultIcon)
        XCTAssertNil(cfg.bookmarks[0].color)   // absent color = use accent
    }

    func testPerBookmarkColorLoadsAndFlowsToTask() throws {
        write(##"{ "bookmarks": [ { "name": "Build", "command": "swift build", "icon": "hammer.fill", "color": "#4F8CFF" } ] }"##)
        let cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks[0].color, "#4F8CFF")
        // The color flows through the task source to the RunTask.
        let task = try XCTUnwrap(TaskRunner.detect(in: dir).first?.tasks.first)
        XCTAssertEqual(task.iconColorHex, "#4F8CFF")
    }

    // MARK: save / add round-trip

    func testAddBookmarkCreatesFileAndRoundTrips() throws {
        XCTAssertFalse(ZTerminalConfig.exists(in: dir))
        try ZTerminalConfig.addBookmark(Bookmark(name: "Clean", command: "rm -rf node_modules", icon: "trash.fill"), in: dir)
        XCTAssertTrue(ZTerminalConfig.exists(in: dir))
        let cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks.map(\.name), ["Clean"])

        try ZTerminalConfig.addBookmark(Bookmark(name: "Build", command: "swift build"), in: dir)
        let cfg2 = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg2.bookmarks.map(\.name), ["Clean", "Build"])
    }

    func testUpdateAndRemoveBookmark() throws {
        try ZTerminalConfig.addBookmark(Bookmark(name: "A", command: "a"), in: dir)
        try ZTerminalConfig.addBookmark(Bookmark(name: "B", command: "b"), in: dir)

        // Edit the first bookmark in place.
        try ZTerminalConfig.updateBookmark(at: 0, to: Bookmark(name: "A2", command: "a2", icon: "bolt.fill", color: "#10B981"), in: dir)
        var cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks.map(\.name), ["A2", "B"])
        XCTAssertEqual(cfg.bookmarks[0].command, "a2")
        XCTAssertEqual(cfg.bookmarks[0].color, "#10B981")

        // Remove the first; the second shifts up.
        try ZTerminalConfig.removeBookmark(at: 0, in: dir)
        cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks.map(\.name), ["B"])

        // Out-of-range operations are safe no-ops.
        try ZTerminalConfig.updateBookmark(at: 9, to: Bookmark(name: "X", command: "x"), in: dir)
        try ZTerminalConfig.removeBookmark(at: 9, in: dir)
        cfg = try XCTUnwrap(ZTerminalConfig.load(in: dir))
        XCTAssertEqual(cfg.bookmarks.map(\.name), ["B"])
    }

    // MARK: task source

    func testTaskSourceRecognizesAndListsBookmarks() throws {
        write(#"{ "bookmarks": [ { "name": "Prebuild", "command": "expo prebuild", "icon": "hammer.fill" } ] }"#)
        XCTAssertTrue(TaskRunner.isRecognized(dir))
        let groups = TaskRunner.detect(in: dir)
        // Bookmarks group is present and listed first.
        XCTAssertEqual(groups.first?.title, "Bookmarks")
        XCTAssertTrue(groups.first?.bookmarks ?? false)
        let t = try XCTUnwrap(groups.first?.tasks.first)
        XCTAssertEqual(t.runCommand, "expo prebuild")
        XCTAssertEqual(t.icon, "hammer.fill")
    }

    // MARK: argument placeholders

    func testPlaceholderParsing() {
        XCTAssertEqual(CommandTemplate.placeholders(in: "swift test --filter <pattern>"), ["pattern"])
        // Ordered + de-duplicated across multiple/repeated placeholders.
        XCTAssertEqual(CommandTemplate.placeholders(in: "cp <src> <dst> <src>"), ["src", "dst"])
        // No placeholders.
        XCTAssertEqual(CommandTemplate.placeholders(in: "npm run dev"), [])
    }

    func testPlaceholderSubstitution() {
        let cmd = "expo prebuild --platform <platform>"
        XCTAssertEqual(CommandTemplate.substitute(cmd, values: ["platform": "ios"]),
                       "expo prebuild --platform ios")
        // A repeated placeholder is filled everywhere from one value.
        XCTAssertEqual(CommandTemplate.substitute("cp <src> <src>.bak", values: ["src": "a.txt"]),
                       "cp a.txt a.txt.bak")
        // Missing value leaves the placeholder untouched (never crashes).
        XCTAssertEqual(CommandTemplate.substitute(cmd, values: [:]), cmd)
    }

    func testEmptyConfigStillRecognizedWithBookmarksGroup() {
        write("{}")
        XCTAssertTrue(TaskRunner.isRecognized(dir))
        let g = TaskRunner.detect(in: dir).first
        XCTAssertEqual(g?.title, "Bookmarks")
        XCTAssertTrue(g?.tasks.isEmpty ?? false)
    }
}
