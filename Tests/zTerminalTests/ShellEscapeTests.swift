import XCTest
@testable import zTerminal

/// Drop-path escaping must match Terminal.app's backslash style so TUI apps
/// (Claude Code) recognize dropped files/images as attachments.
final class ShellEscapeTests: XCTestCase {

    func testPlainPathPassesThrough() {
        XCTAssertEqual(ZTerminalView.shellEscape("/Users/alex/Desktop/file.swift"),
                       "/Users/alex/Desktop/file.swift")
    }

    func testSpacesAreBackslashEscaped() {
        XCTAssertEqual(ZTerminalView.shellEscape("/tmp/Screen Shot 1.png"),
                       "/tmp/Screen\\ Shot\\ 1.png")
    }

    func testShellMetacharactersAreEscaped() {
        XCTAssertEqual(ZTerminalView.shellEscape("/tmp/a'b$(x)&;.png"),
                       "/tmp/a\\'b\\$\\(x\\)\\&\\;.png")
    }

    func testUnicodeLettersPassThrough() {
        XCTAssertEqual(ZTerminalView.shellEscape("/tmp/스크린샷 파일.png"),
                       "/tmp/스크린샷\\ 파일.png")
    }
}
