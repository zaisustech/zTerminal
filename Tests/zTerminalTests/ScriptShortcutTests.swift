import XCTest
@testable import zTerminal

final class ScriptShortcutTests: XCTestCase {

    // MARK: - Name validation

    func testValidNames() {
        for n in ["zaisus", "z", "_x", "a-b", "a_b", "A1", "run-dev", "build2"] {
            XCTAssertTrue(ScriptShortcut.isValidName(n), "\(n) should be valid")
        }
    }

    func testInvalidNames() {
        for n in ["", "   ", "1x", "9", "a b", "a!", "a.b", "foo bar", "-x", "a/b"] {
            XCTAssertFalse(ScriptShortcut.isValidName(n), "\(n) should be invalid")
        }
    }

    func testShellKeywordsRejected() {
        for kw in ["if", "for", "while", "do", "done", "function", "case"] {
            XCTAssertFalse(ScriptShortcut.isValidName(kw), "\(kw) is a keyword")
        }
    }

    func testNamesAreTrimmed() {
        XCTAssertTrue(ScriptShortcut.isValidName("  zaisus  "))
    }

    func testDuplicateNames() {
        let list = [
            ScriptShortcut(name: "a", command: "x"),
            ScriptShortcut(name: "a", command: "y"),
            ScriptShortcut(name: "b", command: "z"),
            ScriptShortcut(name: " ", command: "w"),
        ]
        XCTAssertEqual(ScriptShortcut.duplicateNames(in: list), ["a"])
    }

    // MARK: - Command quoting (injection safety)

    func testShellQuotePlain() {
        XCTAssertEqual(ScriptShortcut.shellQuote("bun run start"), "'bun run start'")
    }

    func testShellQuoteEscapesSingleQuotes() {
        XCTAssertEqual(ScriptShortcut.shellQuote("a'b"), "'a'\\''b'")
    }

    func testShellQuoteContainsSpecialCharsVerbatim() {
        // $, backticks, and newlines are literal inside single quotes — no breakout.
        let cmd = "echo \"$USER\" `date`\nrm nothing"
        let q = ScriptShortcut.shellQuote(cmd)
        XCTAssertTrue(q.hasPrefix("'") && q.hasSuffix("'"))
        // The only way to leave the quote is a properly-escaped sequence.
        XCTAssertFalse(q.contains("'\n"), "raw single-quote should not precede a newline unescaped")
    }

    func testMaliciousCommandStaysQuoted() {
        // An attempt to break out of the function body must remain inert text.
        let evil = "}; rm -rf ~; {"
        let def = ScriptShortcut(name: "safe", command: evil).functionDefinition()
        XCTAssertEqual(def, "safe() { eval '}; rm -rf ~; {' \"$@\"; }")
    }

    // MARK: - Function definition

    func testFunctionDefinition() {
        let def = ScriptShortcut(name: "zaisus", command: "bun run start").functionDefinition()
        XCTAssertEqual(def, "zaisus() { eval 'bun run start' \"$@\"; }")
    }

    func testFunctionDefinitionNilForInvalidName() {
        XCTAssertNil(ScriptShortcut(name: "1bad", command: "echo hi").functionDefinition())
        XCTAssertNil(ScriptShortcut(name: "", command: "echo hi").functionDefinition())
    }

    func testFunctionDefinitionNilForEmptyCommand() {
        XCTAssertNil(ScriptShortcut(name: "ok", command: "   ").functionDefinition())
    }

    // MARK: - Shell block (skip bad entries, dedupe)

    func testShellBlockSkipsInvalidAndDedupes() {
        let list = [
            ScriptShortcut(name: "zaisus", command: "bun run start"),
            ScriptShortcut(name: "1bad", command: "echo nope"),   // invalid name → skipped
            ScriptShortcut(name: "empty", command: ""),           // empty cmd → skipped
            ScriptShortcut(name: "zaisus", command: "other"),     // duplicate → first wins
            ScriptShortcut(name: "test2", command: "swift test"),
        ]
        let block = ScriptShortcut.shellBlock(for: list)
        XCTAssertTrue(block.contains("zaisus() { eval 'bun run start' \"$@\"; }"))
        XCTAssertTrue(block.contains("test2() { eval 'swift test' \"$@\"; }"))
        XCTAssertFalse(block.contains("1bad"))
        XCTAssertFalse(block.contains("empty()"))
        XCTAssertFalse(block.contains("'other'"), "first duplicate should win")
    }

    func testShellBlockEmptyForNoValidShortcuts() {
        XCTAssertEqual(ScriptShortcut.shellBlock(for: []), "")
        XCTAssertEqual(ScriptShortcut.shellBlock(for: [ScriptShortcut(name: "1x", command: "y")]), "")
    }

    // MARK: - Persistence tolerance

    func testDecodeTolerantOfMissingScriptShortcuts() throws {
        // Older settings blobs have no scriptShortcuts key → decode to [].
        let json = ##"{"accentHex":"#123456"}"##.data(using: .utf8)!
        let tokens = try JSONDecoder().decode(DesignTokens.self, from: json)
        XCTAssertEqual(tokens.scriptShortcuts, [])
        XCTAssertEqual(tokens.accentHex, "#123456")
    }

    func testScriptShortcutRoundTrips() throws {
        let original = DesignTokens(scriptShortcuts: [ScriptShortcut(name: "zaisus", command: "bun run start")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DesignTokens.self, from: data)
        XCTAssertEqual(decoded.scriptShortcuts.map(\.name), ["zaisus"])
        XCTAssertEqual(decoded.scriptShortcuts.map(\.command), ["bun run start"])
    }
}
