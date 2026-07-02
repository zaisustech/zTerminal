import XCTest
@testable import zTerminal

final class FileTreeTests: XCTestCase {

    private let entries = [
        DirEntry(name: "README.md", isDirectory: false),
        DirEntry(name: "Sources", isDirectory: true),
        DirEntry(name: ".git", isDirectory: true),
        DirEntry(name: ".env", isDirectory: false),
        DirEntry(name: "node_modules", isDirectory: true),
        DirEntry(name: "app.swift", isDirectory: false),
        DirEntry(name: "Assets", isDirectory: true),
        DirEntry(name: ".DS_Store", isDirectory: false),
    ]

    func testFoldersFirstThenAlpha() {
        let out = FileTree.arrange(entries, showHidden: false).map(\.name)
        // Visible folders (Assets, Sources) alpha, then visible files (app.swift, README.md).
        XCTAssertEqual(out, ["Assets", "Sources", "app.swift", "README.md"])
    }

    func testHiddenFilteredByDefault() {
        let out = FileTree.arrange(entries, showHidden: false).map(\.name)
        XCTAssertFalse(out.contains(".git"))
        XCTAssertFalse(out.contains(".env"))
        XCTAssertFalse(out.contains("node_modules"))
        XCTAssertFalse(out.contains(".DS_Store"))
    }

    func testShowHiddenIncludesEverything() {
        let out = FileTree.arrange(entries, showHidden: true).map(\.name)
        XCTAssertEqual(out.count, entries.count)
        // Still folders-first: .git, Assets, node_modules, Sources (alpha), then files.
        XCTAssertEqual(out, [".git", "Assets", "node_modules", "Sources",
                             ".DS_Store", ".env", "app.swift", "README.md"])
    }

    func testCaseInsensitiveSort() {
        let mixed = [
            DirEntry(name: "banana", isDirectory: false),
            DirEntry(name: "Apple", isDirectory: false),
            DirEntry(name: "cherry", isDirectory: false),
        ]
        XCTAssertEqual(FileTree.arrange(mixed, showHidden: false).map(\.name),
                       ["Apple", "banana", "cherry"])
    }

    func testEmpty() {
        XCTAssertTrue(FileTree.arrange([], showHidden: false).isEmpty)
    }
}
