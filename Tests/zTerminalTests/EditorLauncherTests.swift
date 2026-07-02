import XCTest
@testable import zTerminal

final class EditorLauncherTests: XCTestCase {

    // MARK: Suffix parsing

    func testNoSuffix() {
        let r = EditorLauncher.parseSuffix("src/app/foo.ts")
        XCTAssertEqual(r.path, "src/app/foo.ts")
        XCTAssertNil(r.line); XCTAssertNil(r.col)
    }

    func testLineOnly() {
        let r = EditorLauncher.parseSuffix("Foo.swift:42")
        XCTAssertEqual(r.path, "Foo.swift"); XCTAssertEqual(r.line, 42); XCTAssertNil(r.col)
    }

    func testLineAndCol() {
        let r = EditorLauncher.parseSuffix("Sources/App/Foo.swift:42:10")
        XCTAssertEqual(r.path, "Sources/App/Foo.swift")
        XCTAssertEqual(r.line, 42); XCTAssertEqual(r.col, 10)
    }

    func testNonNumericSuffixStays() {
        // A ":" followed by non-digits is part of the path (not a line).
        let r = EditorLauncher.parseSuffix("path:notaline")
        XCTAssertEqual(r.path, "path:notaline"); XCTAssertNil(r.line)
    }

    // MARK: Resolution against a CWD (real temp files)

    func testResolveRelativeExistingFile() throws {
        let dir = NSTemporaryDirectory() + "el-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let file = dir + "/foo.txt"
        FileManager.default.createFile(atPath: file, contents: Data("hi".utf8))
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let target = EditorLauncher.resolve(token: "foo.txt:12", cwd: dir)
        XCTAssertEqual(target?.path, (file as NSString).standardizingPath)
        XCTAssertEqual(target?.line, 12)
    }

    func testResolveMissingFileIsNil() {
        let target = EditorLauncher.resolve(token: "does/not/exist.txt", cwd: NSTemporaryDirectory())
        XCTAssertNil(target)
    }

    // MARK: CLI invocation + template

    func testVSCodeInvocationWithLine() {
        let t = EditorLauncher.FileTarget(path: "/a/b.swift", line: 5, col: 9)
        let inv = EditorLauncher.cliInvocation(editor: .vscode, target: t)
        XCTAssertEqual(inv?.tool, "code")
        XCTAssertEqual(inv?.args, ["-g", "/a/b.swift:5:9"])
    }

    func testXcodeInvocation() {
        let t = EditorLauncher.FileTarget(path: "/a/b.swift", line: 5, col: nil)
        let inv = EditorLauncher.cliInvocation(editor: .xcode, target: t)
        XCTAssertEqual(inv?.tool, "xed")
        XCTAssertEqual(inv?.args, ["--line", "5", "/a/b.swift"])
    }

    func testSystemHasNoCLI() {
        let t = EditorLauncher.FileTarget(path: "/a/b", line: nil, col: nil)
        XCTAssertNil(EditorLauncher.cliInvocation(editor: .system, target: t))
    }

    func testCustomTemplateSubstitution() {
        let t = EditorLauncher.FileTarget(path: "/a b/c.swift", line: 7, col: 3)
        let out = EditorLauncher.substitute(template: "myeditor +{line} {file}", target: t)
        XCTAssertEqual(out, "myeditor +7 '/a b/c.swift'")   // file shell-quoted
    }
}
